#!/usr/bin/env python3
"""Evaluate hosted Alta Console TTS with a real API key.

Loads secrets from repo-root ``.env`` (gitignored). Does not print the full key.
Does not invent metrics — only records what the API returns.

Voice-preservation / cloning claims stay UNCLAIMED unless consenting reference
WAVs are provided and human A/B review is completed.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def _load_dotenv() -> None:
    path = REPO / ".env"
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_dotenv()

from app.ai.alta_console_tts import AltaConsoleTtsAdapter  # noqa: E402

RW_TEXT = "Muraho. Amakuru yawe? Twishimiye kubonana uyu munsi."
SW_TEXT = "Habari. Hujambo? Tunafurahi kukuona leo."


def main() -> int:
    out = Path(os.getenv("ALTA_EVAL_OUT", str(ROOT / "artifacts" / "alta_console_eval")))
    out.mkdir(parents=True, exist_ok=True)
    adapter = AltaConsoleTtsAdapter()
    report: dict = {
        "adapter": adapter.capabilities_probe(),
        "auth_me": None,
        "voices": None,
        "cases": {},
        "errors": [],
        "voice_preservation": {
            "claimed": False,
            "reason": (
                "No consenting reference_audio cloning run in this pass. "
                "Shipped-voice RW/SW synthesis does not prove voice preservation."
            ),
        },
    }

    if not adapter.configured:
        report["errors"].append("ALTA_API_KEY missing")
        (out / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 2

    try:
        me = adapter.auth_me()
        # Strip anything that looks like a secret.
        report["auth_me"] = {
            k: v
            for k, v in me.items()
            if "key" not in k.lower() and "secret" not in k.lower() and "token" not in k.lower()
        }
    except Exception as exc:
        report["errors"].append(f"auth/me failed: {exc}")
        (out / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 2

    try:
        voices = adapter.list_voices()
        report["voices"] = {
            "default": voices.get("default"),
            "recommended": voices.get("recommended"),
            "model": voices.get("model"),
            "languages": voices.get("languages"),
            "streaming": voices.get("streaming"),
            "voice_ids": [v.get("id") for v in voices.get("voices", [])],
            "cloned_count": voices.get("cloned"),
        }
    except Exception as exc:
        report["errors"].append(f"voices failed: {exc}")

    # Independent language synthesis (shipped voices).
    for name, text, language, voice in (
        ("rw_keza", RW_TEXT, "rw", "keza"),
        ("sw_keza", SW_TEXT, "sw", "keza"),
        ("sw_ganza", SW_TEXT, "sw", "ganza"),
    ):
        try:
            result = adapter.synthesize(
                text,
                voice=voice,
                language=language,
                sample_rate=16000,
                format="wav",
            )
            path = out / f"{name}.wav"
            path.write_bytes(result.audio)
            report["cases"][name] = {
                "text": text,
                "requested_voice": voice,
                "requested_language": language,
                "bytes": len(result.audio),
                "output": str(path),
                "latency_ms_client": result.latency_ms_client,
                "latency_ms_service": result.latency_ms_service,
                "audio_seconds": result.audio_seconds,
                "voice": result.voice,
                "language": result.language,
                "sample_rate": result.sample_rate,
                "cache": result.cache,
                "pronunciation_quality": "PENDING_HUMAN_OR_ASR_REVIEW",
                "intelligibility": "PENDING_HUMAN_OR_ASR_REVIEW",
            }
        except Exception as exc:
            report["errors"].append(f"{name}: {exc}")
            report["cases"][name] = {"error": str(exc)}

    # Streaming first-audio measurement (service + client).
    for steps_label, text, language in (
        ("stream_rw", RW_TEXT, "rw"),
        ("stream_sw", SW_TEXT, "sw"),
    ):
        try:
            stream = adapter.synthesize_stream(
                text,
                voice="keza",
                language=language,
                sample_rate=16000,
            )
            report["cases"][steps_label] = {
                "language": language,
                "client_first_byte_ms": stream["client_first_byte_ms"],
                "client_total_ms": stream["client_total_ms"],
                "service_first_audio_ms": (stream.get("service_done") or {}).get(
                    "first_audio_ms"
                ),
                "service_latency_ms": (stream.get("service_done") or {}).get("latency_ms"),
                "service_audio_seconds": (stream.get("service_done") or {}).get(
                    "audio_seconds"
                ),
                "service_rtf": (stream.get("service_done") or {}).get("rtf"),
                "chunk_count": stream["chunk_count"],
                "chunks": stream["chunks"],
                "note": (
                    "Hosted SSE is sentence-level streaming. Not comparable 1:1 to "
                    "local StreamingSynthesizer steps=1/2 without a local checkpoint."
                ),
            }
        except Exception as exc:
            report["errors"].append(f"{steps_label}: {exc}")
            report["cases"][steps_label] = {"error": str(exc)}

    # Optional cloning only when consenting refs exist.
    ref_rw = os.getenv("ALTATTS_REF_RW_WAV", "").strip()
    ref_sw = os.getenv("ALTATTS_REF_SW_WAV", "").strip()
    if ref_rw and ref_sw and Path(ref_rw).is_file() and Path(ref_sw).is_file():
        report["voice_preservation"]["note"] = (
            "Reference WAVs present — implement /cloning/voices enrollment in a "
            "follow-up run; not auto-uploaded in this script without explicit consent flag."
        )
    else:
        report["cases"]["cloning"] = {
            "ran": False,
            "blocked_missing": ["ALTATTS_REF_RW_WAV", "ALTATTS_REF_SW_WAV"],
        }

    path = out / "report.json"
    path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    # Print without any env secrets
    print(json.dumps(report, indent=2))
    print(f"\nWrote {path}")
    if report["errors"] and not report["cases"]:
        return 2
    if report["errors"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
