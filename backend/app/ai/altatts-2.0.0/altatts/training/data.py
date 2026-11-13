"""
Dataset layer: metadata -> records -> padded TTS batches.

**The same metadata files that trained ALTASR train ALTATTS.** ``read_metadata``
accepts the identical shapes (nested dict keyed by id, list of dicts,
JSON-lines, CSV/TSV) with the identical field aliases, plus the optional
TTS fields below. Every field is optional; a plain ASR corpus (audio +
transcript) trains a complete model.

    speaker    speaker | speaker_id | client_id | voice_creator_id | spk
    gender     gender | sex                ("male"/"female", "m"/"f", "gabo"/"gore")
    age        age | age_group             (number, "twenties", "16-25", ...)
    language   language | lang | locale    ("rw", "en", "fr", "sw", "mixed")
    emotion    emotion | emotion_label | style | sentiment
    intensity  intensity | emotion_intensity | arousal | strength   (0..1)
    pauses     pauses | silences | breaks  ([{"offset": 12, "duration": 0.4}, ...]
                                             or [[offset, duration], ...])
    text       may contain inline tags: [pause] [pause:0.5] [laugh] [happy:0.8]
               <en>...</en>  -- see altatts.tags

Missing emotion -> the "unlabeled" slot (id 0) so unlabeled corpora never
disturb the labelled categories. Missing language -> ``data.default_language``
or the model's primary language. Missing pauses -> the model still learns
natural pausing from punctuation; ``altatts-prepare-data --auto-pauses`` can
add explicit [pause] tokens from the audio.

Each dataset item carries ``(token ids, language ids, linear spec, waveform,
speaker id, emotion id, intensity, reference spec)``. The reference spec is a
random 1-3 s crop of another clip of the same speaker (or of the same clip),
from which the reference encoder learns to extract speaker identity.
``BucketBatchSampler`` is ALTASR's: sort by duration, batch neighbours,
shuffle batch order each epoch, shard by rank under DDP.
"""
from __future__ import annotations

import csv
import json
import os
import random
import sys
from collections import defaultdict
from typing import Dict, Iterator, List, Optional, Sequence

import numpy as np
import torch
from torch.utils.data import Dataset, Sampler

from ..audio import (AudioDecodeError, load_audio, peak_normalize,
                     spectrogram_torch, trim_silence)
from ..config import Config
from ..languages import canonical_code, is_mixed_code
from ..tags import canonical_emotion, insert_pauses, parse_tags, EmotionTag
from ..text import CharTokenizer, normalize_text

_MAX_BAD_FILE_RETRIES = 10
_MAX_BAD_FILE_WARNINGS = 20

_AUDIO_KEYS = ("audio_path", "path", "file", "filename", "audio")
_TEXT_KEYS = ("transcription", "sentence", "text", "transcript", "label")
_DUR_KEYS = ("duration", "duration_s", "length")
_SPEAKER_KEYS = ("speaker", "voice_creator_id", "speaker_id", "client_id", "spk")
_GENDER_KEYS = ("gender", "sex")
_AGE_KEYS = ("age", "age_group", "age_bucket")
_LANG_KEYS = ("language", "lang", "locale")
_EMOTION_KEYS = ("emotion", "emotion_label", "emo", "style", "sentiment")
_INTENSITY_KEYS = ("intensity", "emotion_intensity", "arousal", "strength",
                   "emotion_strength")
_PAUSE_KEYS = ("pauses", "silences", "breaks")
_DATASET_KEYS = ("dataset", "category", "corpus", "source")

_GENDER_MAP = {"m": "male", "male": "male", "gabo": "male", "man": "male",
               "male_masculine": "male", "masculine": "male", "homme": "male",
               "mwanaume": "male",
               "f": "female", "female": "female", "gore": "female",
               "woman": "female", "w": "female", "femme": "female",
               "female_feminine": "female", "feminine": "female",
               "mwanamke": "female"}

AGE_GROUPS = ("16-25", "25-45", "45+")


def normalize_gender(value) -> str:
    """Map a raw gender label to 'male' / 'female' / 'other'."""
    if value is None:
        return "other"
    v = str(value).strip().lower()
    if not v:
        return "other"
    if v in _GENDER_MAP:
        return _GENDER_MAP[v]
    if "female" in v or "feminine" in v:      # check female first
        return "female"
    if "male" in v or "masculine" in v:
        return "male"
    return "other"


def normalize_age(value) -> Optional[str]:
    """Raw age ('23', 23, 'twenties', 'teens', '25-45', 'fourties') ->
    one of AGE_GROUPS, or None when unknown."""
    if value is None:
        return None
    v = str(value).strip().lower()
    if not v:
        return None
    if v in AGE_GROUPS:
        return v
    words = {"teens": 17, "teen": 17, "twenties": 24, "thirties": 34,
             "fourties": 44, "forties": 44, "fifties": 54, "sixties": 64,
             "seventies": 74, "eighties": 84, "nineties": 94,
             "young": 20, "adult": 35, "senior": 60, "old": 60, "elderly": 70}
    if v in words:
        age = words[v]
    else:
        import re
        m = re.search(r"\d+", v)
        if not m:
            return None
        age = int(m.group(0))
    if age < 25:
        return "16-25"
    if age < 45:
        return "25-45"
    return "45+"


# --------------------------------------------------------------------------- #
#  Metadata
# --------------------------------------------------------------------------- #
def _pick(d: Dict, keys: Sequence[str]):
    for k in keys:
        if k in d and d[k] not in (None, ""):
            return d[k]
    return None


def _to_record(uid: str, raw: Dict) -> Optional[Dict]:
    audio, text = _pick(raw, _AUDIO_KEYS), _pick(raw, _TEXT_KEYS)
    if not audio or not text:
        return None
    rec = {"id": str(uid), "audio_path": str(audio), "text": str(text)}
    dur = _pick(raw, _DUR_KEYS)
    if dur is not None:
        try:
            rec["duration"] = float(dur)
        except (TypeError, ValueError):
            pass
    spk = _pick(raw, _SPEAKER_KEYS)
    if spk is not None:
        rec["speaker"] = str(spk)
    gen = _pick(raw, _GENDER_KEYS)
    if gen is not None:
        rec["gender"] = normalize_gender(gen)
    age = normalize_age(_pick(raw, _AGE_KEYS))
    if age:
        rec["age_group"] = age
    lang = _pick(raw, _LANG_KEYS)
    if lang is not None:
        rec["language"] = str(lang).strip().lower()
    emo = _pick(raw, _EMOTION_KEYS)
    if emo is not None:
        rec["emotion"] = str(emo).strip().lower()
    inten = _pick(raw, _INTENSITY_KEYS)
    if inten is not None:
        try:
            v = float(inten)
            rec["intensity"] = max(0.0, min(1.0, v / 100.0 if v > 1.0 else v))
        except (TypeError, ValueError):
            pass
    ds = _pick(raw, _DATASET_KEYS)
    if ds is not None:
        rec["dataset"] = str(ds)
    pauses = _pick(raw, _PAUSE_KEYS)
    if pauses:
        if isinstance(pauses, str):
            try:
                pauses = json.loads(pauses)
            except json.JSONDecodeError:
                pauses = None
        if pauses:
            rec["pauses"] = pauses
    return rec


def read_metadata(path) -> List[Dict]:
    """Read metadata into records (auto-detected format). Accepts a single
    path or a list/tuple of paths (concatenated in order)."""
    if isinstance(path, (list, tuple)):
        out: List[Dict] = []
        for p in path:
            out.extend(read_metadata(p))
        return out
    path = os.fspath(path)
    if not os.path.isfile(path):
        raise FileNotFoundError(f"metadata file not found: {path!r}")
    records: List[Dict] = []
    if path.endswith(".csv") or path.endswith(".tsv"):
        delim = "\t" if path.endswith(".tsv") else ","
        with open(path, newline="", encoding="utf-8") as fh:
            for i, row in enumerate(csv.DictReader(fh, delimiter=delim)):
                rec = _to_record(row.get("id", f"row{i}"), row)
                if rec:
                    records.append(rec)
        return records
    with open(path, "r", encoding="utf-8") as fh:
        first = fh.read(1)
        fh.seek(0)
        if first == "":
            return records
        try:
            data = json.load(fh)
        except json.JSONDecodeError:                          # JSON-lines
            fh.seek(0)
            data = [json.loads(line) for line in fh if line.strip()]
    if isinstance(data, dict):
        for uid, raw in data.items():
            if isinstance(raw, dict):
                rec = _to_record(uid, raw)
                if rec:
                    records.append(rec)
    elif isinstance(data, list):
        for i, raw in enumerate(data):
            if isinstance(raw, dict):
                rec = _to_record(raw.get("id", f"row{i}"), raw)
                if rec:
                    records.append(rec)
    return records


def resolve_audio_path(audio_root: str, audio_path: str) -> str:
    """Same fallback chain as ALTASR (audio/ subfolder, add extensions)."""
    cand = os.path.join(audio_root, audio_path) if audio_root else audio_path
    if os.path.isfile(cand):
        return cand
    for alt in (os.path.join(audio_root, "audio", audio_path),
                cand + ".wav", cand + ".flac", cand + ".mp3"):
        if os.path.isfile(alt):
            return alt
    return cand                       # let the decoder raise a clear error


def record_text_with_pauses(rec: Dict) -> str:
    text = rec["text"]
    if rec.get("pauses"):
        try:
            text = insert_pauses(text, rec["pauses"])
        except Exception:                                    # noqa: BLE001
            pass
    return text


def emotion_id_of(label: Optional[str], emotions: Sequence[str]) -> int:
    """Label -> index in the emotion table (0 = unlabeled)."""
    c = canonical_emotion(label or "", emotions)
    return (list(emotions).index(c) + 1) if c else 0


def load_records(paths: Sequence[str], cfg: Config) -> List[Dict]:
    """Read + normalize + filter records for TTS (duration / text bounds).

    Adds ``norm_text`` (canonical, tags inline), ``language`` (code),
    ``emotion_id`` (0 = unlabeled), ``intensity``."""
    d, tc, sc = cfg.data, cfg.text, cfg.style
    languages = list(tc.languages) or ["rw"]
    default_lang = canonical_code(d.default_language or languages[0], languages[0])
    records: List[Dict] = []
    for p in paths:
        records.extend(read_metadata(p))
    kept = []
    for r in records:
        mixed = is_mixed_code(r.get("language"))
        lang = canonical_code(r.get("language"), default_lang)
        if lang not in languages:
            lang = default_lang
        text = record_text_with_pauses(r)
        t = normalize_text(
            text, tc.keep_punctuation, tc.punctuation, tc.expand_numbers,
            transliterate_foreign=tc.transliterate_foreign,
            language=lang, languages=languages,
            detect_languages=tc.language_detection, keep_tags=True)
        if not t or len(t) > d.max_text_len:
            continue
        dur = r.get("duration")
        if dur is not None and not (d.min_duration_s <= dur <= d.max_duration_s):
            continue
        r = dict(r)
        r["norm_text"] = t
        r["language"] = lang
        if mixed:
            r["cross_lingual"] = True
        emo = r.get("emotion")
        if emo is None:                     # inline tag in the transcript?
            for seg in parse_tags(t, languages).segments:
                if isinstance(seg, EmotionTag):
                    emo = seg.emotion
                    if seg.intensity is not None and "intensity" not in r:
                        r["intensity"] = seg.intensity
                    break
        r["emotion_id"] = emotion_id_of(emo, sc.emotions)
        r["intensity"] = float(r.get("intensity", sc.intensity_default))
        kept.append(r)
    return kept


# --------------------------------------------------------------------------- #
#  Speaker registry
# --------------------------------------------------------------------------- #
class SpeakerRegistry:
    """name -> {"id": int, "gender": ..., "n_clips": int, "age_group": ...};
    saved as speakers.json. Resolves the voice aliases "male" / "female" to
    the speaker of that gender with the most training data."""

    def __init__(self, table: Optional[Dict[str, Dict]] = None):
        self.table: Dict[str, Dict] = table or {}

    @classmethod
    def from_records(cls, records: List[Dict]) -> "SpeakerRegistry":
        counts: Dict[str, int] = {}
        genders: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
        ages: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
        langs: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))
        mixed: Dict[str, int] = defaultdict(int)
        for r in records:
            name = r.get("speaker") or r.get("gender") or "speaker0"
            counts[name] = counts.get(name, 0) + 1
            g = r.get("gender")
            if g:
                genders[name][g] += 1
            a = r.get("age_group")
            if a:
                ages[name][a] += 1
            if r.get("language"):
                langs[name][r["language"]] += 1
            if r.get("cross_lingual"):
                mixed[name] += 1
        table = {}
        for i, name in enumerate(sorted(counts, key=counts.get, reverse=True)):
            entry = {"id": i,
                     "gender": (max(genders[name], key=genders[name].get)
                                if genders[name] else "unknown"),
                     "n_clips": counts[name]}
            if ages[name]:
                entry["age_group"] = max(ages[name], key=ages[name].get)
            if langs[name]:
                entry["languages"] = dict(sorted(langs[name].items(),
                                                 key=lambda kv: -kv[1]))
                total = sum(langs[name].values())
                n_major = sum(1 for v in langs[name].values() if v >= 0.1 * total)
                entry["cross_lingual"] = bool(mixed[name] or n_major >= 2)
            table[name] = entry
        return cls(table)

    def languages_of(self, name: str) -> Dict[str, int]:
        return dict(self.table.get(name, {}).get("languages", {}))

    # -- lookups --------------------------------------------------------------- #
    def id_of(self, record: Dict) -> int:
        name = record.get("speaker") or record.get("gender") or "speaker0"
        entry = self.table.get(name)
        return entry["id"] if entry else 0

    def name_of(self, sid: int) -> Optional[str]:
        for n, e in self.table.items():
            if e["id"] == sid:
                return n
        return None

    def resolve_voice(self, voice: str) -> int:
        """'male' / 'female' / a speaker name -> speaker id."""
        v = (voice or "").strip()
        if v in self.table:
            return self.table[v]["id"]
        g = normalize_gender(v)
        if g in ("male", "female"):
            best = [(e.get("n_clips", 0), e["id"]) for e in self.table.values()
                    if e.get("gender") == g]
            if best:
                return max(best)[1]
        raise KeyError(
            f"unknown voice {voice!r}; available: "
            f"{sorted(self.table)} plus 'male'/'female' aliases "
            f"(genders present: {sorted({e.get('gender') for e in self.table.values()})})")

    def voices(self) -> Dict[str, Dict]:
        return dict(self.table)

    def __len__(self) -> int:
        return max(1, len(self.table))

    # -- persistence -------------------------------------------------------------- #
    def save(self, path: str) -> None:
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(self.table, fh, indent=2, ensure_ascii=False)

    @classmethod
    def load(cls, path: str) -> "SpeakerRegistry":
        with open(path, "r", encoding="utf-8") as fh:
            return cls(json.load(fh))


# --------------------------------------------------------------------------- #
#  Dataset
# --------------------------------------------------------------------------- #
class TTSDataset(Dataset):
    """Compact view of the corpus (tuples, not dicts -- spawn workers receive
    a pickled copy, which matters at 1M+ records)."""

    def __init__(self, records: List[Dict], cfg: Config,
                 tokenizer: CharTokenizer, speakers: SpeakerRegistry,
                 with_reference: Optional[bool] = None):
        root = cfg.data.audio_root
        self.items: List[tuple] = [
            (resolve_audio_path(root, r["audio_path"]),
             r["norm_text"],
             speakers.id_of(r),
             int(r.get("emotion_id", 0)),
             float(r.get("intensity", cfg.style.intensity_default)),
             r.get("language"),
             r.get("dataset") or "all")
            for r in records
        ]
        self.categories: List[str] = sorted({it[6] for it in self.items})
        self.durations: List[float] = [
            float(r.get("duration") or len(r["norm_text"]) / 12.0)
            for r in records
        ]
        self.cfg = cfg
        self.tok = tokenizer
        self._bad_warnings = 0
        if with_reference is None:
            with_reference = (not cfg.is_legacy
                              and cfg.style.speaker_encoder == "builtin")
        self.with_reference = with_reference
        self.by_speaker: Dict[int, List[int]] = {}
        if with_reference:
            idx: Dict[int, List[int]] = defaultdict(list)
            for i, it in enumerate(self.items):
                idx[it[2]].append(i)
            self.by_speaker = dict(idx)

    def __len__(self) -> int:
        return len(self.items)

    # -- audio ------------------------------------------------------------------ #
    def _audio(self, path: str) -> torch.Tensor:
        a = self.cfg.audio
        wav = load_audio(path, a.sample_rate)
        if self.cfg.data.trim_silence:
            wav = trim_silence(wav, a.sample_rate, self.cfg.data.trim_db)
        wav = peak_normalize(wav, a.peak_norm)
        min_len = a.win_length + a.hop_length
        if len(wav) < min_len:
            wav = np.pad(wav, (0, min_len - len(wav)))
        return torch.from_numpy(wav).unsqueeze(0)                # (1, samples)

    def _spec(self, y: torch.Tensor) -> torch.Tensor:
        a = self.cfg.audio
        return spectrogram_torch(y, a.n_fft, a.hop_length, a.win_length).squeeze(0)

    def _reference(self, idx: int, sid: int, own_spec: torch.Tensor) -> torch.Tensor:
        s = self.cfg.style
        spec = own_spec
        others = [i for i in self.by_speaker.get(sid, []) if i != idx]
        if others and random.random() < s.ref_other_clip_prob:
            j = random.choice(others)
            try:
                spec = self._spec(self._audio(self.items[j][0]))
            except (AudioDecodeError, OSError):
                spec = own_spec
        t = spec.size(1)
        n = min(t, s.ref_frames)
        if t > s.ref_min_frames:
            n = random.randint(min(s.ref_min_frames, t), n)
        start = random.randint(0, max(0, t - n))
        return spec[:, start:start + n]

    def _load_one(self, idx: int, item: tuple):
        path, norm_text, sid, emo, inten, lang, category = item
        a = self.cfg.audio
        y = self._audio(path)
        spec = self._spec(y)                                   # (F, T)
        y = y[:, : spec.size(1) * a.hop_length]
        ids, lids = self.tok.encode_full(
            norm_text, self.cfg.text.intersperse_blank,
            default_language=lang,
            detect_languages=self.cfg.text.language_detection)
        ref = self._reference(idx, sid, spec) if self.with_reference else None
        return {"ids": torch.LongTensor(ids), "lang": torch.LongTensor(lids),
                "spec": spec, "wav": y.squeeze(0), "sid": sid,
                "emotion": emo, "intensity": inten, "ref_spec": ref,
                "category": category, "language": lang or ""}

    def __getitem__(self, idx: int):
        for attempt in range(_MAX_BAD_FILE_RETRIES):
            j = (idx + attempt) % len(self.items)
            item = self.items[j]
            try:
                return self._load_one(j, item)
            except (AudioDecodeError, OSError) as e:
                if self._bad_warnings < _MAX_BAD_FILE_WARNINGS:
                    self._bad_warnings += 1
                    print(f"[altatts] skipping unreadable clip "
                          f"{item[0]}: {e}", file=sys.stderr)
        raise RuntimeError(
            f"{_MAX_BAD_FILE_RETRIES} consecutive unreadable audio files "
            f"around index {idx} -- check data.audio_root and your metadata.")


def collate(batch) -> Dict[str, torch.Tensor]:
    n = len(batch)
    x_lengths = torch.LongTensor([len(b["ids"]) for b in batch])
    spec_lengths = torch.LongTensor([b["spec"].size(1) for b in batch])
    wav_lengths = torch.LongTensor([b["wav"].size(0) for b in batch])
    x = torch.zeros(n, int(x_lengths.max()), dtype=torch.long)
    lang = torch.zeros_like(x)
    spec = torch.zeros(n, batch[0]["spec"].size(0), int(spec_lengths.max()))
    wav = torch.zeros(n, 1, int(wav_lengths.max()))
    for i, b in enumerate(batch):
        x[i, : len(b["ids"])] = b["ids"]
        lang[i, : len(b["lang"])] = b["lang"]
        spec[i, :, : b["spec"].size(1)] = b["spec"]
        wav[i, 0, : b["wav"].size(0)] = b["wav"]
    out = {"x": x, "x_lengths": x_lengths, "lang": lang, "spec": spec,
           "spec_lengths": spec_lengths, "wav": wav,
           "wav_lengths": wav_lengths,
           "sid": torch.LongTensor([b["sid"] for b in batch]),
           "emotion": torch.LongTensor([b["emotion"] for b in batch]),
           "intensity": torch.tensor([b["intensity"] for b in batch],
                                     dtype=torch.float32),
           "category": [b.get("category", "all") for b in batch],
           "language": [b.get("language", "") for b in batch]}
    refs = [b.get("ref_spec") for b in batch]
    if all(r is not None for r in refs):
        rl = torch.LongTensor([r.size(1) for r in refs])
        ref = torch.zeros(n, refs[0].size(0), int(rl.max()))
        for i, r in enumerate(refs):
            ref[i, :, : r.size(1)] = r
        out["ref_spec"], out["ref_lengths"] = ref, rl
    return out


class BucketBatchSampler(Sampler[List[int]]):
    """Sort by duration, slice consecutive batches, shuffle batch order each
    epoch (ALTASR's sampler). Optional DDP sharding by rank."""

    def __init__(self, durations: List[float], batch_size: int, seed: int = 0,
                 rank: int = 0, world_size: int = 1,
                 max_batch_seconds: float = 0.0):
        def dur(i):
            return durations[i]
        order = sorted(range(len(durations)), key=dur)
        batches: List[List[int]] = []
        cur: List[int] = []
        cur_s = 0.0
        for i in order:
            d_i = dur(i)
            full = (len(cur) >= batch_size
                    or (max_batch_seconds > 0 and cur
                        and cur_s + d_i > max_batch_seconds))
            if full:
                batches.append(cur)
                cur, cur_s = [], 0.0
            cur.append(i)
            cur_s += d_i
        if cur:
            batches.append(cur)
        # every rank must see the same number of batches (DDP all-reduce)
        if world_size > 1 and len(batches) >= world_size:
            usable = (len(batches) // world_size) * world_size
            batches = batches[:usable]
        self.batches = batches[rank::world_size]
        self.seed = seed
        self.epoch = 0

    def set_epoch(self, epoch: int) -> None:
        self.epoch = epoch

    def __iter__(self) -> Iterator[List[int]]:
        rng = random.Random(self.seed + self.epoch)
        order = list(self.batches)
        rng.shuffle(order)
        return iter(order)

    def __len__(self) -> int:
        return len(self.batches)
