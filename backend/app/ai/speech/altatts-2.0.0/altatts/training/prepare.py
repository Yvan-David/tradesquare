"""Data preparation for ALTATTS (``altatts-prepare-data``).

Takes any ASR-style corpus -- the SAME metadata files used to train ALTASR,
or richer TTS corpora -- and writes ONE canonical TTS metadata file plus a
dataset report, whatever the input provides:

  * plain audio + transcript                      -> works as is
  * with speaker / gender / age                   -> used for voices & privacy
  * with emotion (and optionally intensity)       -> emotion control
  * with pause markers (inline tags or a list)    -> learned pauses
  * without pause markers                         -> ``--auto-pauses punct``
                                                     adds [pause:x] tokens
                                                     where silences meet
                                                     punctuation
  * monolingual or code-switched, with/without a language field

Steps: filter clips by duration / text length, drop missing audio, assign a
speaker per clip, auto-tag speaker gender from median F0 when labels are
missing, canonicalize tags, optionally verify transcripts with an ALTASR
model (``--asr-filter-wer``), optionally transcode to FLAC for fast training
reads, and print/save a coverage report with recommendations.

Usage
-----
    altatts-prepare-data --metadata data/train.json --audio-root data/ \
        --out data/tts_train.jsonl [--auto-pauses punct] [--convert-audio flac]

Output records (JSON list or JSON-lines by extension):
    audio_path, text, speaker, gender, duration [, language, emotion,
    intensity, age_group]
"""

from __future__ import annotations

import argparse
import json
import os
import re
from collections import defaultdict
from typing import Dict, List, Optional

import numpy as np
from tqdm import tqdm

from ..config import Config, preset, load_config, PRESET_NAMES
from ..languages import canonical_code
from ..tags import (canonical_emotion, canonicalize, parse_tags, EmotionTag,
                    NonverbalTag, PauseTag)
from ..text import normalize_text, plain_text
from ..metrics import median_f0, GENDER_F0_THRESHOLD
from ..utils import quiet_warnings, clear_terminal
from ..audio import load_audio, AudioDecodeError
from .data import read_metadata, resolve_audio_path, record_text_with_pauses


def _duration_of(rec: dict, path: str) -> Optional[float]:
    if rec.get("duration") is not None:
        return float(rec["duration"])
    try:
        import soundfile as sf

        info = sf.info(path)
        return float(info.frames) / float(info.samplerate)
    except Exception:
        return None


# --------------------------------------------------------------------------- #
#  Audio conversion (fast training reads)
# --------------------------------------------------------------------------- #
def _convert_one(args) -> tuple:
    src, dst, target_sr, fmt = args
    import numpy as np
    from ..audio import load_audio, save_wav
    try:
        if os.path.isfile(dst) and os.path.getsize(dst) > 44:
            import soundfile as sf
            info = sf.info(dst)
            return (src, os.path.basename(dst),
                    float(info.frames) / info.samplerate, None)
    except Exception:                                        # noqa: BLE001
        pass
    try:
        wav = load_audio(src, target_sr)
        if fmt == "flac":
            import soundfile as sf
            sf.write(dst, wav.astype(np.float32), target_sr,
                     format="FLAC", subtype="PCM_16")
        else:
            save_wav(dst, wav, target_sr)
        return (src, os.path.basename(dst), len(wav) / target_sr, None)
    except Exception as e:                                   # noqa: BLE001
        return (src, None, 0.0, str(e)[:200])


def convert_audio(records: List[dict], audio_root: str, out_dir: str,
                  target_sr: int, fmt: str = "flac",
                  workers: int = 8, verbose: bool = True) -> List[dict]:
    """One-time transcode of the corpus into fast-to-decode FLAC/WAV.
    Resumable; records whose audio fails to decode are dropped."""
    from concurrent.futures import ProcessPoolExecutor
    os.makedirs(out_dir, exist_ok=True)
    jobs, seen = [], {}
    for r in records:
        src = resolve_audio_path(audio_root, r["audio_path"])
        base = re.sub(r"[^A-Za-z0-9._-]", "_",
                      os.path.splitext(os.path.basename(src))[0])
        n = seen.get(base, 0)
        seen[base] = n + 1
        if n:
            base = f"{base}_dup{n}"
        jobs.append((src, os.path.join(out_dir, base + "." + fmt),
                     target_sr, fmt))
    kept, failed = [], 0
    with ProcessPoolExecutor(max_workers=workers) as ex:
        results = ex.map(_convert_one, jobs, chunksize=64)
        it = tqdm(results, total=len(jobs), unit="clip",
                  desc=f"[prepare] converting audio -> {fmt}",
                  dynamic_ncols=True, disable=not verbose)
        for r, (src, newname, dur, err) in zip(records, it):
            if err is not None:
                failed += 1
                if verbose and failed <= 20:
                    tqdm.write(f"[prepare] convert failed {src}: {err}")
                continue
            r["audio_path"] = newname
            r["duration"] = round(dur, 3)
            kept.append(r)
    if verbose:
        print(f"[prepare] converted {len(kept)} clips -> {out_dir} "
              f"({failed} failed)")
    return kept


# --------------------------------------------------------------------------- #
#  Automatic pause marking (silence meets punctuation)
# --------------------------------------------------------------------------- #
_PUNCT_RE = re.compile(r"[.,;:?!]")


def _auto_pause_one(args) -> tuple:
    """Returns (index, new_text | None, n_inserted)."""
    idx, path, text, min_s, tol_frac = args
    try:
        from .segment import _silence_gaps
        sr = 16000
        wav = load_audio(path, sr)
        dur = len(wav) / sr
        if dur < 1.0:
            return idx, None, 0
        gaps = _silence_gaps(wav, sr, min_s, -35.0)
        if not gaps:
            return idx, None, 0
        plain = plain_text(text)
        marks = [m.end() for m in _PUNCT_RE.finditer(plain)
                 if m.end() < len(plain) - 1]          # interior punctuation
        if not marks:
            return idx, None, 0
        tol = max(0.35, tol_frac * dur)
        used, inserts = set(), {}
        for center, gdur, _depth in gaps:
            t_gap = center / sr
            # proportional text position of this silence
            best, best_d = None, None
            for m in marks:
                t_m = dur * m / len(plain)
                d = abs(t_m - t_gap)
                if (best_d is None or d < best_d) and m not in used:
                    best, best_d = m, d
            if best is not None and best_d <= tol:
                used.add(best)
                inserts[best] = round(min(gdur, 2.0), 2)
        if not inserts:
            return idx, None, 0
        # rebuild text: insert [pause:x] after the punctuation marks
        out, last = [], 0
        for pos in sorted(inserts):
            out.append(plain[last:pos])
            out.append(f" [pause:{inserts[pos]:g}] ")
            last = pos
        out.append(plain[last:])
        return idx, re.sub(r"\s+", " ", "".join(out)).strip(), len(inserts)
    except Exception:                                        # noqa: BLE001
        return idx, None, 0


def auto_pauses(records: List[dict], audio_root: str, min_s: float = 0.18,
                workers: int = 8, verbose: bool = True) -> int:
    """Insert [pause:x] tags where an interior silence coincides with a
    punctuation mark. Only clips WITHOUT existing pause tags are touched."""
    from concurrent.futures import ProcessPoolExecutor
    jobs = []
    for i, r in enumerate(records):
        if "[pause" in r["text"]:
            continue
        jobs.append((i, resolve_audio_path(audio_root, r["audio_path"]),
                     r["text"], min_s, 0.08))
    n_total = 0
    n_clips = 0
    with ProcessPoolExecutor(max_workers=workers) as ex:
        it = tqdm(ex.map(_auto_pause_one, jobs, chunksize=32), total=len(jobs),
                  unit="clip", desc="[prepare] auto pauses", dynamic_ncols=True,
                  disable=not verbose)
        for idx, new_text, n in it:
            if new_text:
                records[idx]["text"] = new_text
                n_total += n
                n_clips += 1
    if verbose:
        print(f"[prepare] auto pauses: {n_total} [pause] tags inserted in "
              f"{n_clips} clips")
    return n_total


# --------------------------------------------------------------------------- #
#  ASR transcript verification
# --------------------------------------------------------------------------- #
def asr_filter(records: List[dict], audio_root: str, asr_model: str,
               max_wer: float, cfg: Config, max_clips: int = 0,
               verbose: bool = True) -> List[dict]:
    """Drop clips whose ALTASR transcript disagrees with the label (WER >
    max_wer). Transcript errors hurt TTS alignment far more than ASR."""
    try:
        from altasr import Transcriber
    except ImportError:
        print("[prepare] altasr not installed -- skipping --asr-filter "
              "(pip install altatts[asr])")
        return records
    from ..metrics import wer as _wer
    from ..text import strip_punctuation
    tr = Transcriber.from_pretrained(asr_model)
    kept, dropped = [], 0
    todo = records if not max_clips else records[:max_clips]
    rest = [] if not max_clips else records[max_clips:]
    for r in tqdm(todo, desc="[prepare] ASR transcript check", unit="clip",
                  dynamic_ncols=True, disable=not verbose):
        try:
            wav = load_audio(resolve_audio_path(audio_root, r["audio_path"]), 16000)
            hyp = tr.transcribe(wav, sample_rate=16000)
            hyp = hyp.get("text", "") if isinstance(hyp, dict) else str(hyp)
            ref = strip_punctuation(normalize_text(
                plain_text(r["text"]), True, cfg.text.punctuation, True,
                languages=cfg.text.languages, keep_tags=False))
            w = _wer(ref, strip_punctuation(hyp.lower()))
            r["asr_wer"] = round(w, 3)
            if w > max_wer:
                dropped += 1
                continue
        except Exception:                                    # noqa: BLE001
            pass
        kept.append(r)
    if verbose:
        print(f"[prepare] ASR filter: dropped {dropped} clips with WER > "
              f"{max_wer}")
    return kept + rest


# --------------------------------------------------------------------------- #
#  Main preparation
# --------------------------------------------------------------------------- #
def prepare_metadata(
    metadata_paths: List[str],
    audio_root: str,
    out_path: str,
    cfg: Optional[Config] = None,
    f0_clips_per_speaker: int = 20,
    verbose: bool = True,
    drop_unknown_gender: bool = True,
    default_language: Optional[str] = None,
    auto_pause_mode: str = "off",
    auto_pause_min_s: float = 0.18,
    workers: int = 8,
    report_path: Optional[str] = None,
) -> List[dict]:
    """Filter/enrich metadata into canonical TTS metadata. Returns kept
    records and writes them to ``out_path`` (+ a dataset report)."""
    cfg = cfg or preset("base")
    d, tc = cfg.data, cfg.text
    languages = list(tc.languages) or ["rw"]
    default_language = canonical_code(default_language or d.default_language
                                      or languages[0], languages[0])

    raw: List[dict] = []
    for p in metadata_paths:
        raw.extend(read_metadata(p))

    kept: List[dict] = []
    dropped = defaultdict(int)
    stats = defaultdict(int)
    for rec in tqdm(raw, desc="[prepare] filtering clips", unit="clip",
                    dynamic_ncols=True, disable=not verbose):
        text = canonicalize(record_text_with_pauses(rec), languages)
        norm = normalize_text(text, tc.keep_punctuation, tc.punctuation,
                              tc.expand_numbers, languages=languages,
                              language=rec.get("language") or default_language)
        if not plain_text(norm):
            dropped["empty_text"] += 1
            continue
        if len(norm) > d.max_text_len:
            dropped["text_too_long"] += 1
            continue
        if rec.get("gender") not in (None, "male", "female"):
            dropped["gender_not_male_female"] += 1
            continue
        path = resolve_audio_path(audio_root, rec["audio_path"])
        if not os.path.isfile(path):
            dropped["missing_audio"] += 1
            continue
        dur = _duration_of(rec, path)
        if dur is not None and not (d.min_duration_s <= dur <= d.max_duration_s):
            dropped["bad_duration"] += 1
            continue
        out = {"audio_path": rec["audio_path"], "text": text,
               "speaker": rec.get("speaker", "spk0")}
        if dur is not None:
            out["duration"] = round(dur, 3)
        if rec.get("gender"):
            out["gender"] = rec["gender"]
        if rec.get("age_group"):
            out["age_group"] = rec["age_group"]
            stats["with_age"] += 1
        lang = canonical_code(rec.get("language"), default_language)
        out["language"] = lang
        if rec.get("language"):
            stats["with_language_field"] += 1
        parsed = parse_tags(text, languages)
        emo = rec.get("emotion")
        inline_emo = next((s for s in parsed.segments if isinstance(s, EmotionTag)), None)
        if emo is None and inline_emo is not None:
            emo = inline_emo.emotion
            if inline_emo.intensity is not None and rec.get("intensity") is None:
                rec["intensity"] = inline_emo.intensity
        if emo is not None:
            c = canonical_emotion(emo, cfg.style.emotions)
            if c is None:
                stats["unmapped_emotion_labels"] += 1
                dropped_label = emo
                out["emotion_raw"] = dropped_label
            else:
                out["emotion"] = c
                stats["with_emotion"] += 1
        if rec.get("intensity") is not None:
            out["intensity"] = round(float(rec["intensity"]), 3)
            stats["with_intensity"] += 1
        if any(isinstance(s, PauseTag) for s in parsed.segments):
            stats["with_pause_tags"] += 1
        if any(isinstance(s, NonverbalTag) for s in parsed.segments):
            stats["with_nonverbal_tags"] += 1
        kept.append(out)

    # -- gender auto-tagging from median F0 -------------------------------- #
    by_speaker: Dict[str, List[dict]] = defaultdict(list)
    for rec in kept:
        by_speaker[rec["speaker"]].append(rec)
    speaker_gender: Dict[str, str] = {}
    for spk, recs in tqdm(sorted(by_speaker.items()),
                          desc="[prepare] gender tagging (median F0)",
                          unit="speaker", dynamic_ncols=True,
                          disable=not verbose):
        labelled = [r["gender"] for r in recs if r.get("gender") in ("male", "female")]
        if labelled:
            speaker_gender[spk] = max(set(labelled), key=labelled.count)
            continue
        f0s = []
        for r in recs[:f0_clips_per_speaker]:
            path = resolve_audio_path(audio_root, r["audio_path"])
            try:
                wav = load_audio(path, target_sr=16000)
            except (AudioDecodeError, Exception):
                continue
            f0 = median_f0(np.asarray(wav, dtype=np.float32), 16000)
            if not np.isnan(f0):
                f0s.append(f0)
        if f0s:
            med = float(np.median(f0s))
            speaker_gender[spk] = "female" if med >= GENDER_F0_THRESHOLD else "male"
            if verbose:
                tqdm.write(f"[prepare] speaker '{spk}': median F0 {med:.1f} Hz "
                           f"-> {speaker_gender[spk]}")
        else:
            speaker_gender[spk] = "unknown"
    for rec in kept:
        rec["gender"] = speaker_gender.get(rec["speaker"], "unknown")
    if drop_unknown_gender:
        n_before = len(kept)
        kept = [r for r in kept if r["gender"] in ("male", "female")]
        if n_before - len(kept):
            dropped["gender_not_male_female"] += n_before - len(kept)
        speaker_gender = {k: v for k, v in speaker_gender.items()
                          if v in ("male", "female")}

    # -- automatic pause marking ------------------------------------------- #
    n_auto_pauses = 0
    if auto_pause_mode == "punct":
        n_auto_pauses = auto_pauses(kept, audio_root, auto_pause_min_s, workers, verbose)

    # -- write ------------------------------------------------------------- #
    write_records(kept, out_path)

    # -- report ------------------------------------------------------------ #
    hours = sum(float(r.get("duration") or 0) for r in kept) / 3600
    genders = defaultdict(int)
    for g in speaker_gender.values():
        genders[g] += 1
    lang_counts = defaultdict(int)
    for r in kept:
        lang_counts[r["language"]] += 1
    emo_counts = defaultdict(int)
    for r in kept:
        emo_counts[r.get("emotion", "unlabeled")] += 1
    n = max(1, len(kept))
    report = {
        "input_records": len(raw), "kept": len(kept), "dropped": dict(dropped),
        "hours": round(hours, 2), "speakers": len(speaker_gender),
        "speaker_genders": dict(genders),
        "languages": dict(lang_counts), "default_language": default_language,
        "emotion_labels": dict(emo_counts),
        "coverage": {
            "emotion": round(stats["with_emotion"] / n, 3),
            "intensity": round(stats["with_intensity"] / n, 3),
            "pause_tags": round(stats["with_pause_tags"] / n, 3),
            "nonverbal_tags": round(stats["with_nonverbal_tags"] / n, 3),
            "age": round(stats["with_age"] / n, 3),
            "language_field": round(stats["with_language_field"] / n, 3),
        },
        "auto_pauses_inserted": n_auto_pauses,
        "unmapped_emotion_labels": stats["unmapped_emotion_labels"],
        "recommendations": _recommendations(stats, n, speaker_gender, hours,
                                            lang_counts, n_auto_pauses),
        "output": os.path.abspath(out_path),
    }
    report_path = report_path or re.sub(r"(\.\w+)?$", "_report.json", out_path, count=1)
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    if verbose:
        print(f"[prepare] kept {len(kept)} / {len(raw)} clips ({hours:.1f} h) -> {out_path}")
        for k, v in sorted(dropped.items()):
            print(f"[prepare]   dropped {v:>6}  ({k})")
        print(f"[prepare] speakers: {len(speaker_gender)}  genders: {dict(genders)}"
              f"  languages: {dict(lang_counts)}")
        cov = report["coverage"]
        print(f"[prepare] coverage: emotion {cov['emotion']:.0%}, intensity "
              f"{cov['intensity']:.0%}, pause tags {cov['pause_tags']:.0%}, "
              f"non-verbal tags {cov['nonverbal_tags']:.0%}, age {cov['age']:.0%}")
        for line in report["recommendations"]:
            print(f"[prepare] -> {line}")
        print(f"[prepare] report -> {report_path}")
    return kept


def _recommendations(stats, n, speaker_gender, hours, lang_counts, n_auto) -> List[str]:
    out = []
    if stats["with_emotion"] == 0:
        out.append("no emotion labels: the model trains emotion-agnostic (fine). "
                   "To enable emotion control, add an 'emotion' field (or inline "
                   "[happy]/[sad] tags) to a labelled subset -- even 5-10% helps.")
    elif stats["with_emotion"] / n < 0.1:
        out.append(f"only {stats['with_emotion'] / n:.0%} of clips carry emotion "
                   f"labels; expect weak emotion control.")
    if stats["with_emotion"] and not stats["with_intensity"]:
        out.append("emotion labels without intensity: intensity defaults to 1.0; "
                   "add 'intensity' (0-1) for graded control.")
    if stats["with_pause_tags"] == 0 and not n_auto:
        out.append("no pause markers: pauses are still learned from punctuation. "
                   "For explicit [pause] control run with --auto-pauses punct.")
    if stats["unmapped_emotion_labels"]:
        out.append(f"{stats['unmapped_emotion_labels']} clips had emotion labels "
                   f"outside the configured set (kept as 'emotion_raw'); map them "
                   f"with --emotions or altatts.tags.EMOTION_ALIASES.")
    genders = defaultdict(int)
    for g in speaker_gender.values():
        genders[g] += 1
    for g in ("female", "male"):
        if genders.get(g, 0) == 0:
            out.append(f"no {g} speaker: the anonymized default {g} voices will be "
                       f"approximate; add {g} data if you need them.")
        elif genders.get(g, 0) < 3:
            out.append(f"only {genders[g]} {g} speaker(s): the default {g} voices "
                       f"need stronger perturbation to stay anonymous (the privacy "
                       f"report tells you); more speakers improve both privacy and "
                       f"zero-shot cloning.")
    if len(speaker_gender) < 20:
        out.append(f"{len(speaker_gender)} speakers: zero-shot cloning quality grows "
                   f"with speaker diversity (>= 50-100 speakers recommended); use "
                   f"altatts-enroll --adapt-steps for few-shot enrollment meanwhile.")
    if hours < 5:
        out.append(f"{hours:.1f} h of audio is small for a from-scratch model; "
                   f"fine-tune from a base run with --init-from.")
    if len(lang_counts) > 1:
        out.append(f"multilingual corpus ({', '.join(sorted(lang_counts))}): train "
                   f"with --languages " + " ".join(sorted(lang_counts)) + ".")
    return out


def write_records(records: List[dict], out_path: str) -> None:
    parent = os.path.dirname(os.path.abspath(out_path))
    os.makedirs(parent, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        if out_path.endswith(".jsonl"):
            for r in records:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        else:
            json.dump(records, f, ensure_ascii=False, indent=1)


def main(argv: Optional[List[str]] = None) -> None:
    quiet_warnings()
    clear_terminal()
    p = argparse.ArgumentParser(
        prog="altatts-prepare-data",
        description="Prepare canonical TTS metadata from any ASR/TTS corpus")
    p.add_argument("--metadata", required=True, nargs="+",
                   help="metadata file(s): json / jsonl / csv / tsv")
    p.add_argument("--audio-root", default="",
                   help="Root folder for relative audio paths")
    p.add_argument("--out", required=True,
                   help="Output metadata path (.json list or .jsonl)")
    p.add_argument("--config", default=None, help="Optional config JSON")
    p.add_argument("--preset", default="base", choices=list(PRESET_NAMES))
    p.add_argument("--languages", nargs="+", default=None,
                   help="Languages present (for normalization/report)")
    p.add_argument("--language", default=None,
                   help="Record language when the metadata has none")
    p.add_argument("--emotions", nargs="+", default=None,
                   help="Emotion categories to map labels onto")
    p.add_argument("--f0-clips", type=int, default=20,
                   help="Clips per speaker sampled for F0 gender tagging")
    p.add_argument("--min-duration", type=float, default=None)
    p.add_argument("--max-duration", type=float, default=None)
    p.add_argument("--max-text-len", type=int, default=None)
    p.add_argument("--auto-pauses", choices=["off", "punct"], default="off",
                   help="Insert [pause:x] tags where silences meet punctuation "
                        "(for corpora without pause markers)")
    p.add_argument("--auto-pause-min", type=float, default=0.18,
                   help="Minimum silence (s) treated as a pause")
    p.add_argument("--asr-filter-wer", type=float, default=None,
                   help="Drop clips whose ALTASR transcript has WER above this "
                        "(needs --asr-model; cleans mislabeled data)")
    p.add_argument("--asr-model", default=None, help="ALTASR checkpoint folder")
    p.add_argument("--asr-filter-max", type=int, default=0,
                   help="Only check the first N clips (0 = all)")
    p.add_argument("--convert-audio", choices=["flac", "wav"], default=None,
                   help="One-time transcode of all kept clips to FLAC/WAV at "
                        "the model sample rate (fast training reads). Resumable.")
    p.add_argument("--convert-dir", default=None,
                   help="Where converted audio is written "
                        "(default: <out dir>/audio_<fmt>)")
    p.add_argument("--workers", "--convert-workers", dest="workers", type=int,
                   default=8, help="Parallel processes (conversion, auto pauses)")
    p.add_argument("--keep-unknown-gender", action="store_true",
                   help="Keep clips whose gender is neither male nor female")
    p.add_argument("--report", default=None, help="Report JSON path")
    args = p.parse_args(argv)

    cfg = load_config(args.config) if args.config else preset(args.preset)
    if args.languages:
        cfg.text.languages = [canonical_code(c, c) for c in args.languages]
    if args.emotions:
        cfg.style.emotions = [e.lower() for e in args.emotions]
    if args.min_duration is not None:
        cfg.data.min_duration_s = args.min_duration
    if args.max_duration is not None:
        cfg.data.max_duration_s = args.max_duration
    if args.max_text_len is not None:
        cfg.data.max_text_len = args.max_text_len
    kept = prepare_metadata(args.metadata, args.audio_root, args.out, cfg,
                            args.f0_clips,
                            drop_unknown_gender=not args.keep_unknown_gender,
                            default_language=args.language,
                            auto_pause_mode=args.auto_pauses,
                            auto_pause_min_s=args.auto_pause_min,
                            workers=args.workers, report_path=args.report)
    if args.asr_filter_wer is not None:
        if not args.asr_model:
            raise SystemExit("--asr-filter-wer needs --asr-model")
        kept = asr_filter(kept, args.audio_root, args.asr_model,
                          args.asr_filter_wer, cfg, args.asr_filter_max)
        write_records(kept, args.out)
    if args.convert_audio:
        conv_dir = args.convert_dir or os.path.join(
            os.path.dirname(os.path.abspath(args.out)),
            f"audio_{args.convert_audio}")
        kept = convert_audio(kept, args.audio_root, conv_dir,
                             cfg.audio.sample_rate, args.convert_audio,
                             workers=args.workers)
        out2 = re.sub(r"(\.\w+)?$", r"_converted.jsonl", args.out, count=1)
        write_records(kept, out2)
        print(f"[prepare] converted metadata -> {out2}")
        print(f"[prepare] train with: --train-metadata {out2} "
              f"--audio-root {conv_dir}")


if __name__ == "__main__":
    main()
