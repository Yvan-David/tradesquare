#!/usr/bin/env python3
"""ALTATTS 2.1 evaluation harness for TradeSquare live-call TTS.

Does not invent audio results. Synthesis / cloning / streaming timings run only
when ALL of the following exist:

  ALTATTS_MODEL_PATH   trained checkpoint folder
  ALTATTS_REF_RW_WAV   consenting Kinyarwanda reference recording
  ALTATTS_REF_SW_WAV   consenting Kiswahili reference recording

Outputs JSON under backend/artifacts/altatts_eval/ (or ALTATTS_EVAL_OUT).
Never wires into production call paths.
"""

from __future__ import annotations

import json
import os
import sys
import time
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.ai.altatts_adapter import AltaTtsCallAdapter  # noqa: E402


RW_TEXT = "Muraho. Amakuru yawe? Twishimiye kubonana uyu munsi."
SW_TEXT = "Habari. Hujambo? Tunafurahi kukuona leo."


def _out_dir() -> Path:
    raw = os.getenv("ALTATTS_EVAL_OUT", "").strip()
    path = Path(raw) if raw else ROOT / "artifacts" / "altatts_eval"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _cosine(a, b) -> float | None:
    import numpy as np

    x = np.asarray(a, dtype=np.float64).reshape(-1)
    y = np.asarray(b, dtype=np.float64).reshape(-1)
    if x.size == 0 or y.size == 0 or x.size != y.size:
        return None
    denom = float(np.linalg.norm(x) * np.linalg.norm(y))
    if denom <= 0:
        return None
    return float(np.dot(x, y) / denom)


def inspect_package() -> dict:
    adapter = AltaTtsCallAdapter()
    info = {
        "adapter_status": adapter.status().__dict__,
        "capabilities_probe": adapter.capabilities_probe(),
        "pypi_weights_bundled": False,
        "github_homepage": "https://github.com/yalilabs/altatts",
        "github_reachable_at_eval": False,
        "hosted_console_note": (
            "https://alta.yalilabs.com exposes a hosted synthesis API. That is "
            "separate from the open-source altatts package and was not used here "
            "(paid/hosted path needs explicit approval)."
        ),
    }
    try:
        import altatts

        info["installed_version"] = getattr(altatts, "__version__", None)
        info["package_importable"] = True
    except Exception as exc:
        info["package_importable"] = False
        info["import_error"] = str(exc)
    return info


def run_audio_suite() -> dict:
    model = os.getenv("ALTATTS_MODEL_PATH", "").strip()
    ref_rw = os.getenv("ALTATTS_REF_RW_WAV", "").strip()
    ref_sw = os.getenv("ALTATTS_REF_SW_WAV", "").strip()
    missing = [
        name
        for name, value in (
            ("ALTATTS_MODEL_PATH", model),
            ("ALTATTS_REF_RW_WAV", ref_rw),
            ("ALTATTS_REF_SW_WAV", ref_sw),
        )
        if not value or not Path(value).exists()
    ]
    if missing:
        return {
            "ran": False,
            "blocked_missing": missing,
            "note": (
                "Audio/cloning/streaming benchmarks were not executed. Provide a "
                "real ALTATTS 2 checkpoint and consenting reference WAVs, then "
                "re-run this script. Do not treat docs/marketing latency numbers "
                "as TradeSquare measurements."
            ),
            "metrics": None,
        }

    from altatts import StreamingSynthesizer, Synthesizer
    import numpy as np
    import soundfile as sf

    out = _out_dir()
    tts = Synthesizer.from_pretrained(model, device=os.getenv("ALTATTS_DEVICE", "auto"))
    caps = tts.capabilities()
    results: dict = {
        "ran": True,
        "capabilities": caps,
        "generation": caps.get("generation"),
        "voice_cloning_flag": caps.get("voice_cloning"),
        "cases": {},
    }

    if not caps.get("voice_cloning"):
        results["cases"]["cloning"] = {
            "skipped": True,
            "reason": "Checkpoint reports voice_cloning=False (likely ALTATTS 0.1).",
        }
        return results

    # Independent language synthesis with production voices (no cloning claim).
    for lang, text, voice in (
        ("rw", RW_TEXT, "bantu_female_1"),
        ("sw", SW_TEXT, "bantu_male_1"),
    ):
        t0 = time.perf_counter()
        wav, sr = tts.tts(text, voice=voice, language=lang, steps=2, sample_rate=16000)
        total_ms = (time.perf_counter() - t0) * 1000
        path = out / f"mono_{lang}_steps2.wav"
        sf.write(str(path), wav, sr)
        results["cases"][f"mono_{lang}"] = {
            "text": text,
            "voice": voice,
            "sample_rate": sr,
            "duration_s": float(len(wav) / sr) if sr else None,
            "total_generation_ms": round(total_ms, 2),
            "output": str(path),
            "pronunciation_quality": "PENDING_HUMAN_REVIEW",
            "intelligibility": "PENDING_ASR_OR_HUMAN_REVIEW",
        }

    # Cross-language cloning with consenting references.
    emb_rw = tts.embed_speaker(ref_rw)
    emb_sw = tts.embed_speaker(ref_sw)

    t0 = time.perf_counter()
    wav_sw_from_rw, sr = tts.tts(
        SW_TEXT,
        language="sw",
        reference_audio=ref_rw,
        cfg_scale=1.5,
        steps=2,
        sample_rate=16000,
    )
    gen_ms = (time.perf_counter() - t0) * 1000
    out_a = out / "clone_rw_ref_to_sw_text.wav"
    sf.write(str(out_a), wav_sw_from_rw, sr)
    emb_out_a = tts.embed_speaker((wav_sw_from_rw, sr))
    results["cases"]["clone_rw_ref_speak_sw"] = {
        "reference": ref_rw,
        "output_language": "sw",
        "total_generation_ms": round(gen_ms, 2),
        "speaker_embedding_cosine_vs_ref": _cosine(emb_rw, emb_out_a),
        "output": str(out_a),
        "voice_preservation_claim": (
            "UNCLAIMED — cosine similarity is an embedding proxy only; "
            "require human listening A/B before asserting voice preservation."
        ),
    }

    t0 = time.perf_counter()
    wav_rw_from_sw, sr = tts.tts(
        RW_TEXT,
        language="rw",
        speaker_embedding=emb_sw,
        cfg_scale=1.5,
        steps=2,
        sample_rate=16000,
    )
    gen_ms = (time.perf_counter() - t0) * 1000
    out_b = out / "clone_sw_emb_to_rw_text.wav"
    sf.write(str(out_b), wav_rw_from_sw, sr)
    emb_out_b = tts.embed_speaker((wav_rw_from_sw, sr))
    results["cases"]["clone_sw_emb_speak_rw"] = {
        "reference": ref_sw,
        "output_language": "rw",
        "total_generation_ms": round(gen_ms, 2),
        "speaker_embedding_cosine_vs_ref": _cosine(emb_sw, emb_out_b),
        "output": str(out_b),
        "voice_preservation_claim": (
            "UNCLAIMED — cosine similarity is an embedding proxy only; "
            "require human listening A/B before asserting voice preservation."
        ),
    }

    # StreamingSynthesizer steps=1 and steps=2
    for steps in (1, 2):
        stream = StreamingSynthesizer(
            tts,
            voice="female",
            sample_rate=16000,
            steps=steps,
            language="rw",
        )
        chunks = []
        t0 = time.perf_counter()
        for chunk in stream.stream(RW_TEXT):
            chunks.append(chunk)
        total_ms = (time.perf_counter() - t0) * 1000
        audio = np.concatenate(chunks) if chunks else np.zeros(0, dtype=np.float32)
        path = out / f"stream_rw_steps{steps}.wav"
        if len(audio):
            sf.write(str(path), audio, 16000)
        results["cases"][f"stream_steps_{steps}"] = {
            "first_chunk_latency_s": stream.first_chunk_latency_s,
            "first_chunk_latency_ms": (
                None
                if stream.first_chunk_latency_s is None
                else round(stream.first_chunk_latency_s * 1000, 2)
            ),
            "total_generation_ms": round(total_ms, 2),
            "chunks": len(chunks),
            "output": str(path) if len(audio) else None,
        }

    return results


def main() -> int:
    out = _out_dir()
    report = {
        "package_inspection": inspect_package(),
        "audio_evaluation": None,
        "error": None,
    }
    try:
        report["audio_evaluation"] = run_audio_suite()
    except Exception as exc:
        report["error"] = {
            "type": type(exc).__name__,
            "message": str(exc),
            "traceback": traceback.format_exc(),
        }
    path = out / "report.json"
    path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"\nWrote {path}")
    # Non-zero when audio suite could not run (expected until weights exist).
    audio = report.get("audio_evaluation") or {}
    if report.get("error"):
        return 2
    if not audio.get("ran"):
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
