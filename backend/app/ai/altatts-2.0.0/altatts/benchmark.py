"""``altatts-benchmark`` -- compare ALTATTS checkpoints (and optionally the
Meta MMS-TTS Kinyarwanda baseline) on the same test set.

    altatts-benchmark \
        --models runs/kinyarwanda-small runs/kinyarwanda-base \
        --metadata data/tts_test.json --audio-root data/ \
        --asr-model path/to/altasr --out benchmark.md

Adds Meta's MMS-TTS (facebook/mms-tts-kin) as a baseline row with
``--include-mms`` (requires ``pip install altatts[mms]``).
"""

from __future__ import annotations

import argparse
import json
import os
import time
from typing import Dict, List, Optional

import numpy as np

from .utils import quiet_warnings, clear_terminal

_METRIC_COLS = ("mcd_db", "f0_rmse_hz", "vuv_error", "pmos", "rtf",
                "gender_match", "spk_sim", "asr_wer", "asr_cer")


def _mms_eval(metadata: List[str], audio_root: str, asr_model: Optional[str],
              max_utterances: Optional[int], device: str) -> Optional[Dict]:
    """Evaluate facebook/mms-tts-kin on the same protocol (baseline row)."""
    try:
        import torch
        from transformers import VitsModel, AutoTokenizer
    except ImportError:
        print("[benchmark] transformers not installed -- skipping MMS "
              "baseline. Install with: pip install altatts[mms]")
        return None

    from .config import preset
    from .audio import load_audio, AudioDecodeError, resample
    from .metrics import (mcd, f0_metrics, predicted_mos, corpus_tts_metrics)
    from .text import normalize_text, strip_punctuation
    from .training.data import load_records, resolve_audio_path

    cfg = preset("base")
    records = load_records(metadata, cfg)
    if max_utterances:
        records = records[:max_utterances]

    dev = torch.device("cuda" if (device in ("auto", "cuda")
                                  and torch.cuda.is_available()) else "cpu")
    model = VitsModel.from_pretrained("facebook/mms-tts-kin").to(dev).eval()
    tok = AutoTokenizer.from_pretrained("facebook/mms-tts-kin")
    mms_sr = int(model.config.sampling_rate)

    transcriber = None
    if asr_model:
        try:
            from altasr import Transcriber
            transcriber = Transcriber.from_pretrained(asr_model, device=device)
        except ImportError:
            pass

    pairs = []
    for rec in records:
        path = resolve_audio_path(audio_root, rec["audio_path"])
        try:
            ref = load_audio(path, target_sr=mms_sr)
        except (AudioDecodeError, Exception):
            continue
        t0 = time.perf_counter()
        with torch.inference_mode():
            from .text import plain_text
            inp = tok(plain_text(rec["norm_text"]), return_tensors="pt").to(dev)
            syn = model(**inp).waveform.squeeze().float().cpu().numpy()
        dt = time.perf_counter() - t0
        m = {"mcd_db": mcd(ref, syn, mms_sr), "rtf": dt / (len(syn) / mms_sr),
             "pmos": predicted_mos(syn, mms_sr)}
        m.update(f0_metrics(ref, syn, mms_sr))
        if transcriber is not None:
            try:
                hyp = transcriber.transcribe(resample(syn, mms_sr, 16000),
                                             sample_rate=16000)
                if isinstance(hyp, dict):
                    hyp = hyp.get("text", "")
                tc = cfg.text
                m["ref_text"] = strip_punctuation(normalize_text(
                    rec["text"], tc.keep_punctuation, tc.punctuation,
                    tc.expand_numbers))
                m["hyp_text"] = strip_punctuation(str(hyp).lower())
            except Exception:                                 # noqa: BLE001
                pass
        pairs.append(m)
    return corpus_tts_metrics(pairs) if pairs else None


def _markdown(rows: Dict[str, Dict]) -> str:
    cols = [c for c in _METRIC_COLS
            if any(c in s for s in rows.values())]
    lines = ["| model | " + " | ".join(cols) + " |",
             "|---" * (len(cols) + 1) + "|"]
    for name, s in rows.items():
        cells = [f"{s[c]:.3f}" if c in s else "--" for c in cols]
        lines.append(f"| {name} | " + " | ".join(cells) + " |")
    lines.append("")
    lines.append("Lower is better for mcd_db, f0_rmse_hz, vuv_error, rtf, "
                 "asr_wer, asr_cer. Higher is better for pmos (1-5), "
                 "gender_match (0-1) and spk_sim (cosine, 0-1).")
    return "\n".join(lines)


def main(argv: Optional[List[str]] = None) -> None:
    quiet_warnings()
    clear_terminal()
    p = argparse.ArgumentParser(description="Benchmark ALTATTS checkpoints")
    p.add_argument("--models", required=True, nargs="+",
                   help="Checkpoint folders to compare")
    p.add_argument("--metadata", required=True, nargs="+")
    p.add_argument("--audio-root", default="")
    p.add_argument("--asr-model", default=None,
                   help="ALTASR checkpoint for WER/CER")
    p.add_argument("--include-mms", action="store_true",
                   help="Add facebook/mms-tts-kin as a baseline row")
    p.add_argument("--max-utterances", type=int, default=200)
    p.add_argument("--clone", action="store_true",
                   help="v2 models: clone each utterance's speaker from its "
                        "reference clip")
    p.add_argument("--out", default=None, help=".md or .json report path")
    p.add_argument("--device", default="auto")
    args = p.parse_args(argv)

    from .inference.evaluate import evaluate

    rows: Dict[str, Dict] = {}
    for model_dir in args.models:
        name = os.path.basename(os.path.normpath(model_dir))
        print(f"\n== {name} ==")
        report = evaluate(model_dir, args.metadata, args.audio_root,
                          out_path=None, asr_model=args.asr_model,
                          max_utterances=args.max_utterances,
                          device=args.device, verbose=True, clone=args.clone)
        rows[name] = report["summary"]

    if args.include_mms:
        print("\n== mms-tts-kin (baseline) ==")
        s = _mms_eval(args.metadata, args.audio_root, args.asr_model,
                      args.max_utterances, args.device)
        if s:
            rows["mms-tts-kin"] = s

    md = _markdown(rows)
    print("\n" + md)
    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            if args.out.endswith(".json"):
                json.dump(rows, f, ensure_ascii=False, indent=2)
            else:
                f.write(md + "\n")
        print(f"\nReport -> {args.out}")


if __name__ == "__main__":
    main()
