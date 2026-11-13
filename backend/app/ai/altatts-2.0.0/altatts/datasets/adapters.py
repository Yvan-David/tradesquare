"""
Readers for every source format. Each adapter is a generator
``adapter(spec, root) -> Iterator[Record]`` yielding canonical records with at
least ``id, audio_path (absolute), text, speaker`` and whatever the source
knows (gender, age, emotion, intensity, duration, domain, language,
source_split). Missing audio is reported later by the pipeline, so adapters
do not need to check it; durations are probed later when absent.

Adding a new corpus
-------------------
1. If your metadata is JSON / JSON-lines / CSV / TSV with ALTASR/ALTATTS
   field names (``audio_path``, ``text``/``transcription``, ``speaker``,
   ``gender``, ``emotion``, ...), use ``adapter="metadata"`` with
   ``options={"files": ["train.jsonl"], "audio_root": "audio"}`` -- no code.
2. Otherwise add a small function here that yields the same dict shape and
   name it in the registry.
"""
from __future__ import annotations

import csv
import glob
import io
import json
import os
import re
from typing import Dict, Iterator, List, Optional

from .spec import DatasetSpec, Record

_LANG_NAMES = {"rw": "rw", "kin": "rw", "en": "en", "eng": "en", "fr": "fr",
               "fra": "fr", "sw": "sw", "swa": "sw"}


def _clean_text(t) -> str:
    t = "" if t is None else str(t)
    t = t.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    return re.sub(r"\s+", " ", t).strip()


def _float(v) -> Optional[float]:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


# --------------------------------------------------------------------------- #
#  Generic: ALTASR / ALTATTS metadata files (json, jsonl, csv, tsv)
# --------------------------------------------------------------------------- #
def metadata(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """options: files=[...], audio_root="" (relative to the dataset path),
    speaker="<fixed name>" when the files have no speaker field."""
    from ..training.data import read_metadata, resolve_audio_path
    base = spec.resolved_path(root)
    audio_root = os.path.join(base, spec.options.get("audio_root", ""))
    for f in spec.options.get("files", []):
        for r in read_metadata(os.path.join(base, f)):
            yield {"id": r["id"], "audio_path": resolve_audio_path(audio_root, r["audio_path"]),
                   "text": _clean_text(r["text"]),
                   "speaker": r.get("speaker") or spec.options.get("speaker", "spk0"),
                   "gender": r.get("gender"), "age": r.get("age_group"),
                   "emotion": r.get("emotion"), "intensity": r.get("intensity"),
                   "duration": r.get("duration"), "language": r.get("language"),
                   "source_split": os.path.splitext(os.path.basename(f))[0]}


# --------------------------------------------------------------------------- #
#  Code-switching recordings (foundry sessions: transcription.json + webm)
# --------------------------------------------------------------------------- #
def foundry_sessions(spec: DatasetSpec, root: str) -> Iterator[Record]:
    base = spec.resolved_path(root)
    sessions = sorted(glob.glob(os.path.join(base, spec.options.get("glob", "foundry_*"))))
    # a creator id can carry noisy gender/age values on a few records: use the
    # majority per creator so one speaker has one gender/age
    votes: Dict[str, Dict[str, Dict]] = {}
    all_recs: List[tuple] = []
    for s in sessions:
        with open(os.path.join(s, "transcription.json"), encoding="utf-8") as fh:
            for r in json.load(fh):
                spk = str(r.get("voice_creator_id", "unknown"))
                v = votes.setdefault(spk, {"gender": {}, "age": {}})
                if r.get("gender"):
                    v["gender"][r["gender"]] = v["gender"].get(r["gender"], 0) + 1
                if isinstance(r.get("age"), (int, float)) and r["age"] > 5:
                    v["age"][int(r["age"])] = v["age"].get(int(r["age"]), 0) + 1
                all_recs.append((s, r))
    for s, r in all_recs:
        spk = str(r.get("voice_creator_id", "unknown"))
        v = votes[spk]
        gender = max(v["gender"], key=v["gender"].get) if v["gender"] else None
        age = max(v["age"], key=v["age"].get) if v["age"] else None
        lang = _LANG_NAMES.get(str(r.get("language", "")).lower(), None)
        yield {"id": f"{os.path.basename(s)}_{os.path.splitext(os.path.basename(r['audio_path']))[0]}",
               "audio_path": os.path.join(s, r["audio_path"]),
               "text": _clean_text(r.get("transcription")),
               "speaker": f"creator{spk}", "gender": gender, "age": age,
               "emotion": r.get("emotion"), "intensity": r.get("emotion_intensity"),
               "duration": _float(r.get("duration")), "language": lang,
               "domain": r.get("domain"), "project": r.get("project_name"),
               "source_split": os.path.basename(s)}


# --------------------------------------------------------------------------- #
#  English
# --------------------------------------------------------------------------- #
def ljspeech(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """metadata.csv: id|raw|normalized ; audio/<id>.wav"""
    base = spec.resolved_path(root)
    audio_dir = os.path.join(base, spec.options.get("audio_dir", "audio"))
    with open(os.path.join(base, "metadata.csv"), encoding="utf-8") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("|")
            if len(parts) < 2:
                continue
            text = parts[2] if len(parts) > 2 and parts[2].strip() else parts[1]
            yield {"id": parts[0], "audio_path": os.path.join(audio_dir, parts[0] + ".wav"),
                   "text": _clean_text(text), "speaker": spec.options.get("speaker", "lj"),
                   "gender": spec.options.get("gender")}


def emns(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """EMNS metadata.csv (| separated, header): emotion + level (0-10)."""
    base = spec.resolved_path(root)
    with open(os.path.join(base, "metadata.csv"), newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh, delimiter="|"):
            if spec.options.get("complete_only", True) and row.get("status", "Complete") != "Complete":
                continue
            lvl = _float(row.get("level"))
            yield {"id": f"emns_{row['id']}", "audio_path": os.path.join(base, row["audio_recording"]),
                   "text": _clean_text(row["utterance"]), "speaker": f"user{row.get('user_id', '0')}",
                   "gender": (row.get("gender") or "").lower() or None,
                   "age": row.get("age"), "emotion": (row.get("emotion") or "").lower() or None,
                   "intensity": (None if lvl is None else max(0.0, min(1.0, lvl / 10.0)))}


def hifi_tts(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """Hi-Fi TTS manifests <reader>_manifest_<clean|other>_<split>.json (JSONL)."""
    base = spec.resolved_path(root)
    subsets = spec.options.get("subsets", ["clean", "other"])
    for f in sorted(glob.glob(os.path.join(base, "*_manifest_*.json"))):
        m = re.match(r"(\d+)_manifest_(\w+)_(train|dev|test)\.json$", os.path.basename(f))
        if not m or m.group(2) not in subsets:
            continue
        reader, subset, split = m.groups()
        with open(f, encoding="utf-8") as fh:
            for line in fh:
                if not line.strip():
                    continue
                r = json.loads(line)
                text = r.get("text_normalized") or r.get("text_no_preprocessing") or r.get("text")
                yield {"id": os.path.splitext(os.path.basename(r["audio_filepath"]))[0] + f"_{reader}",
                       "audio_path": os.path.join(base, r["audio_filepath"]),
                       "text": _clean_text(text), "speaker": f"reader{reader}",
                       "duration": _float(r.get("duration")), "domain": subset,
                       "source_split": split}


# --------------------------------------------------------------------------- #
#  French: CML-TTS (train/dev/test csv with | separator and a quality score)
# --------------------------------------------------------------------------- #
def cml_tts(spec: DatasetSpec, root: str) -> Iterator[Record]:
    base = spec.resolved_path(root)
    min_lev = float(spec.options.get("min_levenshtein", 0.9))
    for split in spec.options.get("splits", ["train", "dev", "test"]):
        p = os.path.join(base, f"{split}.csv")
        if not os.path.isfile(p):
            continue
        with open(p, newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh, delimiter="|"):
                lev = _float(row.get("levenshtein"))
                if lev is not None and lev < min_lev:
                    continue
                yield {"id": os.path.splitext(os.path.basename(row["wav_filename"]))[0],
                       "audio_path": os.path.join(base, row["wav_filename"]),
                       "text": _clean_text(row["transcript"]), "speaker": f"spk{row['client_id']}",
                       "duration": _float(row.get("duration")), "source_split": split,
                       "quality": lev}


# --------------------------------------------------------------------------- #
#  Kinyarwanda
# --------------------------------------------------------------------------- #
def tsv_id_text_voices(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """C4IR: <voice>.tsv (id \\t text, no header) + <voice>/<id>.wav per voice.
    options: voices={"rw_ag_tts_male": {"speaker": "male1", "gender": "male"}, ...}"""
    base = spec.resolved_path(root)
    for folder, info in spec.options["voices"].items():
        tsv = os.path.join(base, folder + ".tsv")
        if not os.path.isfile(tsv):
            continue
        with open(tsv, encoding="utf-8") as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t", 1)
                if len(parts) < 2 or not parts[0].strip():
                    continue
                yield {"id": f"{folder}_{parts[0].strip()}",
                       "audio_path": os.path.join(base, folder, parts[0].strip() + ".wav"),
                       "text": _clean_text(parts[1]), "speaker": info["speaker"],
                       "gender": info.get("gender"), "domain": spec.options.get("domain")}


def afrispeak_manifest(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """Digital Umuganda afrispeak: <voice>/{train,val,test}_manifest.tsv with
    text / audio_name / 'Voice actor/actress'; audio/<audio_name>.wav"""
    base = spec.resolved_path(root)
    for folder, info in spec.options["voices"].items():
        for split in ("train", "val", "test"):
            p = os.path.join(base, folder, f"{split}_manifest.tsv")
            if not os.path.isfile(p):
                continue
            with open(p, newline="", encoding="utf-8") as fh:
                for row in csv.DictReader(fh, delimiter="\t"):
                    name = str(row.get("audio_name", "")).strip()
                    if not name:
                        continue
                    yield {"id": f"{info['speaker']}_{name}",
                           "audio_path": os.path.join(base, folder, "audio", name + ".wav"),
                           "text": _clean_text(row.get("text")), "speaker": info["speaker"],
                           "gender": info.get("gender"), "source_split": split}


def mbanlp_csv(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """tts-dataset.csv lines: TTS_1_2 "text" ; audio/TTS 1_2.wav"""
    base = spec.resolved_path(root)
    with open(os.path.join(base, "tts-dataset.csv"), encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r'^(\S+)\s+"(.*)"\s*$', line.strip())
            if not m:
                continue
            fid = m.group(1).replace("_", " ", 1) + ".wav"
            yield {"id": m.group(1), "audio_path": os.path.join(base, "audio", fid),
                   "text": _clean_text(m.group(2)), "speaker": spec.options.get("speaker", "actress"),
                   "gender": spec.options.get("gender")}


def hf_parquet_audio(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """Hugging Face parquet shards with an Audio column (bytes + path) and a
    text column. Audio bytes are materialised once into <cache>/<dataset>/."""
    try:
        import pyarrow.parquet as pq
    except ImportError as exc:
        raise ImportError("reading parquet needs pyarrow: pip install pyarrow "
                          "(or pip install 'altatts[data]')") from exc
    base = spec.resolved_path(root)
    cache = spec.options.get("cache_dir") or os.path.join(base, "_extracted_audio")
    os.makedirs(cache, exist_ok=True)
    audio_col, text_col = spec.options.get("audio_column", "audio_path"), spec.options.get("text_column", "text")
    for f in sorted(glob.glob(os.path.join(base, "*.parquet"))):
        split = re.sub(r"-\d+-of-\d+$", "", os.path.splitext(os.path.basename(f))[0])
        table = pq.read_table(f, columns=[audio_col, text_col])
        for i, r in enumerate(table.to_pylist()):
            a = r[audio_col] or {}
            name = os.path.basename(a.get("path") or f"{split}_{i}.wav")
            dst = os.path.join(cache, name)
            if not os.path.isfile(dst) and a.get("bytes"):
                with open(dst, "wb") as fh:
                    fh.write(a["bytes"])
            yield {"id": os.path.splitext(name)[0], "audio_path": dst,
                   "text": _clean_text(r[text_col]), "speaker": spec.options.get("speaker", "spk0"),
                   "gender": spec.options.get("gender"), "source_split": split}


# --------------------------------------------------------------------------- #
#  Spreadsheets (xlsx) -- Kiswahili and the E-Fiche benchmark
# --------------------------------------------------------------------------- #
def _xlsx_rows(path: str) -> List[tuple]:
    try:
        import openpyxl
    except ImportError as exc:
        raise ImportError("reading .xlsx needs openpyxl: pip install openpyxl "
                          "(or pip install 'altatts[data]')") from exc
    wb = openpyxl.load_workbook(path, read_only=True)
    ws = wb.worksheets[0]
    return [r for r in ws.iter_rows(values_only=True) if r and any(c is not None for c in r)]


def kiswahili_xlsx(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """metadata.xlsx: one cell per row 'Kiswa-00001|raw text|normalized text';
    audio/Kiswa-00001.wav (plus re-recorded takes Kiswa-00001-xxxxxx.wav)."""
    base = spec.resolved_path(root)
    audio_dir = os.path.join(base, spec.options.get("audio_dir", "audio"))
    files: Dict[str, List[str]] = {}
    for f in os.listdir(audio_dir):
        b = re.sub(r"(-[A-Za-z0-9]{6})?\.wav$", "", f)
        files.setdefault(b, []).append(f)
    prefer = spec.options.get("prefer_take", "newest")      # newest | plain
    for r in _xlsx_rows(os.path.join(base, spec.options.get("file", "Text/metadata.xlsx"))):
        parts = str(r[0]).split("|")
        if len(parts) < 2:
            continue
        cid = parts[0].strip()
        text = parts[2] if len(parts) > 2 and parts[2].strip() else parts[1]
        cands = files.get(cid)
        if not cands:
            yield {"id": cid, "audio_path": os.path.join(audio_dir, cid + ".wav"),
                   "text": _clean_text(text), "speaker": spec.options.get("speaker", "spk0")}
            continue
        if prefer == "newest" and len(cands) > 1:
            cands = sorted(cands, key=lambda f: os.path.getmtime(os.path.join(audio_dir, f)), reverse=True)
        else:
            cands = sorted(cands, key=len)
        yield {"id": cid, "audio_path": os.path.join(audio_dir, cands[0]),
               "text": _clean_text(text), "speaker": spec.options.get("speaker", "spk0"),
               "gender": spec.options.get("gender"),
               "takes": len(files.get(cid, []))}


def efiche_xlsx(spec: DatasetSpec, root: str) -> Iterator[Record]:
    """E-Fiche benchmark: Test_dataset_transcripts_updated.xlsx + audios/CLIP_xxx.wav.
    Multi-speaker dialogues (voice_set FF/MF/MM), 30-120 s, mixed languages."""
    base = spec.resolved_path(root)
    audio_dir = os.path.join(base, spec.options.get("audio_dir", "audios"))
    files = {f.lower(): f for f in os.listdir(audio_dir)}
    rows = _xlsx_rows(os.path.join(base, spec.options.get("file", "Test_dataset_transcripts_updated.xlsx")))
    header = [str(c).strip().lower() if c else "" for c in rows[0]]
    for r in rows[1:]:
        d = dict(zip(header, r))
        cid = str(d.get("clip_id") or "").strip()
        if not cid:
            continue
        fname = files.get(f"{cid}.wav".lower())
        mix = str(d.get("language_mix") or "").lower()
        lang = "rw" if mix == "pure_kinyarwanda" else "mixed"
        yield {"id": cid, "audio_path": os.path.join(audio_dir, fname or f"{cid}.wav"),
               "text": _clean_text(d.get("transcripts")), "speaker": f"dialogue_{d.get('voice_set', 'xx')}",
               "language": lang, "domain": d.get("medical_domain"),
               "dialogue": True, "voice_set": d.get("voice_set"),
               "noise_condition": d.get("noise_condition")}


ADAPTERS = {f.__name__: f for f in (metadata, foundry_sessions, ljspeech, emns, hifi_tts,
                                     cml_tts, tsv_id_text_voices, afrispeak_manifest,
                                     mbanlp_csv, hf_parquet_audio, kiswahili_xlsx, efiche_xlsx)}


def get_adapter(name: str):
    if name not in ADAPTERS:
        raise KeyError(f"unknown adapter {name!r}; available: {sorted(ADAPTERS)}")
    return ADAPTERS[name]
