"""ALTATTS 2.x adapter boundary for TradeSquare call TTS evaluation.

This adapter is intentionally separate from KinyaFlex / flutter_tts /
Discover remote TTS. It does NOT replace existing TTS paths and must not be
wired into production LiveKit calls until the evaluation harness passes with
real model weights and consenting reference audio.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class AdapterStatus:
    available: bool
    name: str
    detail: str


class AltaTtsCallAdapter:
    """Optional ALTATTS synthesizer for offline / worker evaluation only."""

    PACKAGE = "altatts"
    PACKAGE_VERSION = "2.1.0"
    LICENSE = "Apache-2.0"

    def __init__(self) -> None:
        self.model_path = os.getenv("ALTATTS_MODEL_PATH", "").strip()
        self.enabled = os.getenv("ENABLE_ALTATTS_CALLS", "").strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }
        self.device = os.getenv("ALTATTS_DEVICE", "auto").strip() or "auto"

    def package_importable(self) -> bool:
        try:
            import altatts  # noqa: F401

            return True
        except Exception:
            return False

    def model_folder_ready(self) -> bool:
        if not self.model_path or not os.path.isdir(self.model_path):
            return False
        required = ("config.json", "tokenizer.json", "speakers.json")
        if not all(os.path.isfile(os.path.join(self.model_path, name)) for name in required):
            return False
        return any(
            os.path.isfile(os.path.join(self.model_path, name))
            for name in ("model.pt", "best.pt", "checkpoint.pt")
        )

    def status(self) -> AdapterStatus:
        if not self.package_importable():
            return AdapterStatus(
                available=False,
                name="ALTATTS 2.1 call TTS",
                detail=(
                    f"Package {self.PACKAGE}=={self.PACKAGE_VERSION} "
                    f"({self.LICENSE}) is not installed in this environment. "
                    "Install into an evaluation venv only; do not enable on "
                    "production call paths yet."
                ),
            )
        if not self.model_folder_ready():
            return AdapterStatus(
                available=False,
                name="ALTATTS 2.1 call TTS",
                detail=(
                    "Package is importable, but ALTATTS_MODEL_PATH does not point "
                    "to a trained checkpoint folder "
                    "(config.json + tokenizer.json + speakers.json + model.pt). "
                    "PyPI ships code only — no public kin_v2 weights were found. "
                    "GitHub homepage returned 404 at evaluation time."
                ),
            )
        if not self.enabled:
            return AdapterStatus(
                available=False,
                name="ALTATTS 2.1 call TTS",
                detail=(
                    f"Checkpoint found at {self.model_path}, but "
                    "ENABLE_ALTATTS_CALLS is not set. Evaluation may load the "
                    "model; production LiveKit calls stay on existing TTS paths."
                ),
            )
        return AdapterStatus(
            available=True,
            name="ALTATTS 2.1 call TTS",
            detail=(
                f"Checkpoint ready at {self.model_path} with "
                "ENABLE_ALTATTS_CALLS=1. Still keep LiveKit media plane separate; "
                "run docs/ALTATTS_EVALUATION_REPORT.md harness before claiming "
                "voice preservation."
            ),
        )

    def capabilities_probe(self) -> dict[str, Any]:
        status = self.status()
        payload: dict[str, Any] = {
            "available": status.available,
            "name": status.name,
            "detail": status.detail,
            "package": self.PACKAGE,
            "package_version_target": self.PACKAGE_VERSION,
            "license": self.LICENSE,
            "model_path": self.model_path or None,
            "enabled_for_calls": self.enabled,
            "production_wired": False,
            "voice_cloning_api": {
                "reference_audio": True,
                "speaker_embedding": True,
                "requires_generation": "ALTATTS 2 (config model.version == 2)",
            },
            "streaming_api": {
                "class": "StreamingSynthesizer",
                "phrase_level": True,
                "native_frame_streaming": False,
                "note": (
                    "StreamingSynthesizer emits phrase/sentence chunks after each "
                    "non-autoregressive forward pass; not sample-by-sample streaming."
                ),
            },
            "languages_claimed_by_docs": ["rw", "sw", "en", "fr"],
            "weights_bundled_in_pypi": False,
        }
        if not self.model_folder_ready() or not self.package_importable():
            return payload
        try:
            from altatts import Synthesizer

            tts = Synthesizer.from_pretrained(self.model_path, device=self.device)
            caps = tts.capabilities()
            payload["loaded_capabilities"] = caps
            payload["generation"] = caps.get("generation")
            payload["voice_cloning"] = caps.get("voice_cloning")
            payload["languages"] = caps.get("languages")
        except Exception as exc:  # pragma: no cover - depends on local weights
            payload["load_error"] = str(exc)
        return payload
