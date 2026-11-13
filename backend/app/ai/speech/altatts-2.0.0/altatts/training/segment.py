"""
altatts-segment: split long studio recordings into sentence-level clips.

Why: TTS trains best on 3--12 s sentence clips (LJSpeech averages 6.5 s).
Long multi-sentence takes (20--30 s) are slower per step AND harder for
monotonic alignment, which contributes to robotic prosody.

How (deliberately conservative -- a mispaired text/audio segment is worse
than a long clip, so we only split when confident):

1. The transcript is split into sentences at final punctuation.
2. The audio's silence gaps are detected with an adaptive energy VAD.
3. The N-1 strongest pauses are chosen as cut points for N sentences.
4. Each candidate (sentence, segment) pair must pass sanity checks --
   duration bounds and rough proportionality between audio length and
   sentence length. If ANY check fails, the original clip is kept whole.

Segmented audio is written as FLAC/WAV at the model sample rate (so this
doubles as the fast-decode conversion step) and a new metadata file is
produced. Resumable: existing output files are reused.
"""
from __future__ import annotations

import argparse
import json
import os
import re
from typing import List, Optional

import numpy as np
from tqdm import tqdm

from ..config import Config, preset, load_config
from ..text import split_sentences
from ..audio import load_audio, save_wav, AudioDecodeError
from ..utils import quiet_warnings, clear_terminal
from .data import read_metadata, resolve_audio_path

_PAD_S = 0.06            # silence padding kept around each segment
_WIN_S = 0.02            # VAD frame


def _silence_gaps(wav: np.ndarray, sr: int, min_silence_s: float,
                  threshold_db: float) -> List[tuple]:
    """Interior silence runs as (center_sample, duration_s, depth_db)."""
    hop = max(1, int(sr * _WIN_S))
    n = len(wav) // hop
    if n < 8:
        return []
    frames = wav[: n * hop].reshape(n, hop)
    rms = np.sqrt((frames ** 2).mean(axis=1))
    db = 20.0 * np.log10(rms + 1e-9)
    thr = db.max() + threshold_db          # threshold_db is negative
    silent = db < thr
    gaps, i = [], 0
    while i < n:
        if silent[i]:
            j = i
            while j < n and silent[j]:
                j += 1
            dur = (j - i) * _WIN_S
            if dur >= min_silence_s and i > 0 and j < n:   # interior only
                gaps.append((((i + j) // 2) * hop, dur, float(db[i:j].min())))
            i = j
        else:
            i += 1
    return gaps


def _pause_chunks(n_samples: int, sr: int, gaps: List[tuple],
                  max_keep: float, min_clip: float) -> List[List[int]]:
    """Cut at every qualifying pause, then greedily merge neighbours so each
    chunk stays under ``max_keep`` seconds (and no tiny tail remains)."""
    cuts = sorted(g[0] for g in gaps)
    bounds = [0] + cuts + [n_samples]
    merged = [[bounds[0], bounds[1]]]
    for a, b in zip(bounds[1:-1], bounds[2:]):
        if (b - merged[-1][0]) <= max_keep * sr:
            merged[-1][1] = b
        else:
            merged.append([a, b])
    while len(merged) > 1 and (merged[-1][1] - merged[-1][0]) < min_clip * sr:
        merged[-2][1] = merged[-1][1]
        merged.pop()
    return merged


def _proportional_word_spans(words: List[str], chunks: List[List[int]],
                             n_samples: int) -> Optional[List[tuple]]:
    """Assign transcript words to audio chunks by matching each chunk's time
    share to the words' character share (cut at word boundaries only)."""
    if not words or len(words) < len(chunks):
        return None
    cum, tot = [], 0
    for w in words:
        tot += len(w) + 1
        cum.append(tot)
    spans, start = [], 0
    for k, (_a, b) in enumerate(chunks[:-1]):
        target = (b / n_samples) * tot
        j = start + 1
        while j < len(cum) and cum[j - 1] < target:
            j += 1
        remaining_chunks = len(chunks) - k - 1
        j = max(start + 1, min(j, len(words) - remaining_chunks))
        spans.append((start, j))
        start = j
    spans.append((start, len(words)))
    if any(a >= b for a, b in spans):
        return None
    return spans


def _segment_one(job) -> tuple:
    """Returns (list_of_new_records | None, reason: str, err | None).

    reason in: split_punct / split_pause / short / single_sentence /
    few_pauses / sanity."""
    (rec, base, audio_root, out_audio, target_sr, fmt, min_clip, max_clip,
     max_keep, min_silence, threshold_db, split_mode) = job
    try:
        src = resolve_audio_path(audio_root, rec["audio_path"])
        sentences = split_sentences(rec.get("text", ""))

        wav = load_audio(src, target_sr)
        if wav is None or len(wav) < int(0.1 * target_sr):
            return (None, "failed", f"{rec.get('audio_path')}: empty or "
                                    f"near-empty audio")
        dur = len(wav) / target_sr

        def write(seg: np.ndarray, name: str) -> str:
            path = os.path.join(out_audio, name + "." + fmt)
            if not (os.path.isfile(path) and os.path.getsize(path) > 44):
                if fmt == "flac":
                    import soundfile as sf
                    sf.write(path, np.clip(seg, -1, 1).astype(np.float32),
                             target_sr, format="FLAC", subtype="PCM_16")
                else:
                    save_wav(path, seg, target_sr)
            return os.path.basename(path)

        def whole(reason: str) -> tuple:
            name = write(wav, base)
            out = dict(rec)
            out["audio_path"] = name
            out["duration"] = round(dur, 3)
            return ([out], reason, None)

        def emit(pieces, reason) -> tuple:
            out_recs = []
            for k, (seg, txt) in enumerate(pieces):
                name = write(seg, f"{base}_s{k:02d}")
                out = dict(rec)
                out["text"] = txt
                out["audio_path"] = name
                out["duration"] = round(len(seg) / target_sr, 3)
                out["id"] = f"{rec.get('id', base)}_s{k:02d}"
                out_recs.append(out)
            return (out_recs, reason, None)

        if dur <= max_keep:
            return whole("short")

        pad = int(_PAD_S * target_sr)
        gaps = _silence_gaps(wav, target_sr, min_silence, threshold_db)

        # ---- mode 1: punctuation-guided (most precise) ----------------- #
        use_punct = (split_mode in ("auto", "punct")) and len(sentences) >= 2
        if use_punct and len(gaps) >= len(sentences) - 1:
            n_cuts = len(sentences) - 1
            g2 = sorted(gaps, key=lambda g: (-g[1], g[2]))
            cuts = sorted(g[0] for g in g2[:n_cuts])
            bounds = [0] + cuts + [len(wav)]
            segs = [wav[max(0, a - (pad if a else 0)):
                        min(len(wav), b + pad)]
                    for a, b in zip(bounds[:-1], bounds[1:])]
            total_chars = sum(len(x) for x in sentences) or 1
            ok = True
            for seg, sent in zip(segs, sentences):
                d = len(seg) / target_sr
                expected = dur * len(sent) / total_chars
                if not (min_clip <= d <= max_clip):
                    ok = False
                    break
                if expected > 1.5 and not (expected / 3 <= d <= expected * 3):
                    ok = False
                    break
            if ok:
                return emit(list(zip(segs, sentences)), "split_punct")
            if split_mode == "punct":
                return whole("sanity")
        elif split_mode == "punct":
            return whole("single_sentence" if len(sentences) < 2
                         else "few_pauses")

        # ---- mode 2: pause-guided (no punctuation needed) --------------- #
        if split_mode in ("auto", "pause", "asr"):
            if not gaps:
                return whole("few_pauses")
            chunks = _pause_chunks(len(wav), target_sr, gaps,
                                   max_keep, min_clip)
            if len(chunks) < 2:
                return whole("few_pauses")
            words = rec.get("text", "").split()
            spans = _proportional_word_spans(words, chunks, len(wav))
            if spans is None:
                return whole("sanity")
            pieces = []
            for (a, b), (i, j) in zip(chunks, spans):
                seg = wav[max(0, a - (pad if a else 0)):
                          min(len(wav), b + pad)]
                d = len(seg) / target_sr
                if not (min_clip <= d <= max_clip):
                    return whole("sanity")
                pieces.append((seg, " ".join(words[i:j])))
            return emit(pieces, "split_pause")

        return whole("single_sentence")
    except (AudioDecodeError, Exception) as e:               # noqa: BLE001
        return (None, "failed", f"{rec.get('audio_path')}: {str(e)[:200]}")


def segment_corpus(metadata_paths: List[str], audio_root: str, out_dir: str,
                   cfg: Optional[Config] = None, fmt: str = "flac",
                   min_clip: float = 1.0, max_clip: float = 30.0,
                   max_keep: float = 12.0, min_silence: float = 0.25,
                   threshold_db: float = -35.0, workers: int = 8,
                   split_mode: str = "auto", asr_model: str = "",
                   verbose: bool = True) -> List[dict]:
    from concurrent.futures import ProcessPoolExecutor
    cfg = cfg or preset("base")
    out_audio = os.path.join(out_dir, "audio")
    os.makedirs(out_audio, exist_ok=True)

    if fmt == "flac":
        try:
            import soundfile  # noqa: F401
        except ImportError:
            print("[segment] soundfile not installed -- writing WAV instead "
                  "of FLAC (pip install soundfile to enable FLAC)")
            fmt = "wav"

    records = read_metadata(metadata_paths)
    n_invalid = 0
    valid: List[dict] = []
    for r in records:
        if r.get("audio_path") and (r.get("text") or "").strip():
            valid.append(r)
        else:
            n_invalid += 1
    if n_invalid and verbose:
        print(f"[segment] dropped {n_invalid} record(s) missing text or "
              f"audio_path")

    # collision-safe output names: identical basenames from different source
    # folders must never share an output file
    seen: dict = {}
    jobs = []
    for r in valid:
        base = re.sub(r"[^A-Za-z0-9._-]", "_",
                      os.path.splitext(os.path.basename(r["audio_path"]))[0])
        n = seen.get(base, 0)
        seen[base] = n + 1
        if n:
            base = f"{base}_dup{n}"
        jobs.append((r, base, audio_root, out_audio, cfg.audio.sample_rate,
                     fmt, min_clip, max_clip, max_keep, min_silence,
                     threshold_db, split_mode))

    out_recs: List[dict] = []
    groups: List[tuple] = []          # (orig_text, [indices into out_recs])
    reasons: dict = {}
    n_failed = 0
    with ProcessPoolExecutor(max_workers=workers) as ex:
        results = ex.map(_segment_one, jobs, chunksize=16)
        it = tqdm(results, total=len(jobs), unit="clip", dynamic_ncols=True,
                  desc="[segment] splitting long recordings",
                  disable=not verbose)
        for job, (recs, reason, err) in zip(jobs, it):
            if err is not None:
                n_failed += 1
                if verbose and n_failed <= 20:
                    tqdm.write(f"[segment] failed {err}")
                continue
            reasons[reason] = reasons.get(reason, 0) + 1
            if reason == "split_pause" and len(recs) > 1:
                idxs = list(range(len(out_recs), len(out_recs) + len(recs)))
                groups.append((job[0].get("text", ""), idxs))
            out_recs.extend(recs)

    # ---- optional ASR refinement of pause-mode word boundaries --------- #
    if split_mode == "asr" and groups:
        _asr_refine(out_recs, groups, out_audio, asr_model, verbose)
    n_split = reasons.get("split_punct", 0) + reasons.get("split_pause", 0)
    n_whole = sum(v for k, v in reasons.items()
                  if k not in ("split_punct", "split_pause"))

    out_meta = os.path.join(out_dir, "metadata.jsonl")
    with open(out_meta, "w", encoding="utf-8") as f:
        for r in out_recs:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    if verbose:
        durs = [r["duration"] for r in out_recs]
        print(f"[segment] {n_split} clips split, {n_whole} kept whole, "
              f"{n_failed} failed")
        nice = {"split_punct": "split at punctuation",
                "split_pause": "split at pauses",
                "short": "kept: already short enough",
                "single_sentence": "kept: no interior punctuation",
                "few_pauses": "kept: not enough silence pauses",
                "sanity": "kept: split failed sanity checks"}
        for k in sorted(reasons, key=reasons.get, reverse=True):
            print(f"[segment]   {reasons[k]:>7}  {nice.get(k, k)}")
        print(f"[segment] {len(jobs)} -> {len(out_recs)} clips | "
              f"avg {sum(durs)/max(1,len(durs)):.1f}s | "
              f"total {sum(durs)/3600:.1f}h")
        print(f"[segment] metadata -> {out_meta}")
        print(f"[segment] next: altatts-prepare-data --metadata {out_meta} "
              f"--audio-root {out_audio} ...")
    return out_recs


def _asr_refine(out_recs: List[dict], groups: List[tuple], out_audio: str,
                asr_model: str, verbose: bool) -> None:
    """Refine pause-split word boundaries with ALTASR transcriptions.

    Each chunk is transcribed; a small dynamic program then chooses word
    boundaries in the reference text that best match the per-chunk
    transcripts (proportional assignment is used as the fallback)."""
    import difflib
    try:
        from altasr import Transcriber
        tr = Transcriber.from_pretrained(asr_model)
    except Exception as e:                                   # noqa: BLE001
        print(f"[segment] ASR refinement unavailable ({e}); keeping "
              f"proportional word boundaries")
        return

    def norm(t: str) -> str:
        return re.sub(r"[^a-z'\u00C0-\u024F ]", " ", t.lower()).split()

    refined = 0
    it = tqdm(groups, desc="[segment] ASR-refining boundaries",
              unit="clip", dynamic_ncols=True, disable=not verbose)
    for orig_text, idxs in it:
        try:
            hyps = []
            for i in idxs:
                wav16 = load_audio(
                    os.path.join(out_audio, out_recs[i]["audio_path"]), 16000)
                h = tr.transcribe(wav16, sample_rate=16000)
                hyps.append(norm(h.get("text", "") if isinstance(h, dict)
                                 else str(h)))
            words = orig_text.split()
            W, C = len(words), len(idxs)
            if W < C or C < 2:
                continue
            nwords = [norm(w)[0] if norm(w) else "" for w in words]
            # DP: best[c][j] = score covering chunks[:c] with words[:j]
            NEG = -1e9
            best = [[NEG] * (W + 1) for _ in range(C + 1)]
            back = [[0] * (W + 1) for _ in range(C + 1)]
            best[0][0] = 0.0
            for c in range(1, C + 1):
                hyp = " ".join(hyps[c - 1])
                lo = c            # at least one word per chunk
                hi = W - (C - c)
                for j in range(lo, hi + 1):
                    for i in range(c - 1, j):
                        if best[c - 1][i] <= NEG / 2:
                            continue
                        ref = " ".join(nwords[i:j])
                        sc = difflib.SequenceMatcher(
                            None, ref, hyp).ratio() * (j - i)
                        if best[c - 1][i] + sc > best[c][j]:
                            best[c][j] = best[c - 1][i] + sc
                            back[c][j] = i
            if best[C][W] <= NEG / 2:
                continue
            bounds, j = [W], W
            for c in range(C, 0, -1):
                j = back[c][j]
                bounds.append(j)
            bounds = bounds[::-1]
            for k, i in enumerate(idxs):
                out_recs[i]["text"] = " ".join(words[bounds[k]:bounds[k + 1]])
            refined += 1
        except Exception:                                    # noqa: BLE001
            continue
    if verbose:
        print(f"[segment] ASR refined {refined}/{len(groups)} split clips")


def main(argv: Optional[List[str]] = None) -> None:
    quiet_warnings()
    clear_terminal()
    p = argparse.ArgumentParser(
        description="Split long multi-sentence recordings into "
                    "sentence-level TTS clips (conservative, alignment-safe)")
    p.add_argument("--metadata", required=True, nargs="+")
    p.add_argument("--audio-root", default="")
    p.add_argument("--out-dir", required=True,
                   help="Writes <out-dir>/audio/*.flac + metadata.jsonl")
    p.add_argument("--config", default=None)
    p.add_argument("--preset", default="base")
    p.add_argument("--format", choices=["flac", "wav"], default="flac")
    p.add_argument("--max-keep", type=float, default=12.0,
                   help="Clips at or below this length are kept whole (s)")
    p.add_argument("--min-clip", type=float, default=1.0)
    p.add_argument("--max-clip", type=float, default=30.0)
    p.add_argument("--min-silence", type=float, default=0.25,
                   help="Minimum pause length treated as a boundary (s)")
    p.add_argument("--threshold-db", type=float, default=-35.0,
                   help="Silence threshold relative to the clip's peak (dB)")
    p.add_argument("--workers", type=int, default=8)
    p.add_argument("--split-mode", choices=["auto", "punct", "pause", "asr"],
                   default="auto",
                   help="punct: cut only at sentence punctuation (safest). "
                        "pause: cut at silences, assign words by their "
                        "character share (works without punctuation). "
                        "asr: pause cuts + word boundaries refined by an "
                        "ALTASR model (--asr-model). auto: punct when the "
                        "transcript has sentences, else pause.")
    p.add_argument("--asr-model", default="",
                   help="ALTASR checkpoint folder for --split-mode asr")
    args = p.parse_args(argv)

    cfg = load_config(args.config) if args.config else preset(args.preset)
    segment_corpus(args.metadata, args.audio_root, args.out_dir, cfg,
                   fmt=args.format, min_clip=args.min_clip,
                   max_clip=args.max_clip, max_keep=args.max_keep,
                   min_silence=args.min_silence,
                   threshold_db=args.threshold_db, workers=args.workers,
                   split_mode=args.split_mode, asr_model=args.asr_model)


if __name__ == "__main__":
    main()
