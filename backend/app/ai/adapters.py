"""Modular AI/voice adapters for TradeSquare Discover.

These adapters define integration boundaries. They do not pretend cloud or GPU
services are available when credentials or model weights are missing.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Protocol

from app.ai.alta_console_tts import AltaConsoleTtsAdapter
from app.ai.altatts_adapter import AltaTtsCallAdapter
from app.ai.llm import LocalHeuristicLlmAdapter, OptionalRemoteLlmAdapter


@dataclass(frozen=True)
class AdapterStatus:
    available: bool
    name: str
    detail: str


class SpeechToTextAdapter(Protocol):
    def status(self) -> AdapterStatus: ...


class TextToSpeechAdapter(Protocol):
    def status(self) -> AdapterStatus: ...


class LiveKitAdapter(Protocol):
    def status(self) -> AdapterStatus: ...


class NvidiaKinyarwandaSttAdapter:
    """Boundary for nvidia/stt_rw_conformer_ctc_large.

    Verified from Hugging Face model card:
    - NeMo EncDecCTCModelBPE, ~120M params
    - File transcription API: asr_model.transcribe(['sample.wav'])
    - MCV-9 test WER ~18.22% (self-reported)
    - Trained on ~2000h Kinyarwanda
    - Native low-latency streaming is via NVIDIA Riva, not the raw HF script
    - Not realistic inside Flutter or on CPU-only hackathon laptops
    """

    MODEL_ID = "nvidia/stt_rw_conformer_ctc_large"

    def status(self) -> AdapterStatus:
        worker = os.getenv("DISCOVER_STT_WORKER_URL", "").strip()
        if worker:
            return AdapterStatus(
                available=False,
                name="NVIDIA Kinyarwanda STT",
                detail=(
                    f"Worker URL set ({worker}), but NeMo/Riva worker process is not "
                    f"attached in this API process. Model {self.MODEL_ID} still requires "
                    "GPU + NeMo or Riva. Published HF usage is file/chunk transcription."
                ),
            )
        return AdapterStatus(
            available=False,
            name="NVIDIA Kinyarwanda STT",
            detail=(
                f"Model {self.MODEL_ID} is not loaded. Requires GPU worker, "
                "NeMo/HF runtime (or Riva for streaming), license review, and "
                "DISCOVER_STT_WORKER_URL. Flutter keeps on-device speech_to_text fallback."
            ),
        )


class KinyaFlexTtsAdapter:
    """Boundary for C4IR-RW/kinya-flex-tts (preferred candidate)."""

    MODEL_ID = "C4IR-RW/kinya-flex-tts"
    ALTERNATE_MODEL_ID = "mbazaNLP/kinyarwanda-tts-model"

    def status(self) -> AdapterStatus:
        worker = os.getenv("DISCOVER_TTS_WORKER_URL", "").strip()
        detail = (
            f"Preferred candidate {self.MODEL_ID}; also benchmark "
            f"{self.ALTERNATE_MODEL_ID} for pronunciation, tone, latency, hardware "
            "and licensing before commercial use. Native-speaker QA is still required."
        )
        if worker:
            return AdapterStatus(
                available=False,
                name="Kinya Flex TTS",
                detail=(
                    f"Worker URL set ({worker}), but synthesis worker is not attached "
                    f"in this API process. {detail}"
                ),
            )
        return AdapterStatus(
            available=False,
            name="Kinya Flex TTS",
            detail=(
                f"Model weights are not loaded. Set DISCOVER_TTS_WORKER_URL after "
                f"choosing a licensed deployment path. {detail} "
                "Flutter keeps flutter_tts fallback."
            ),
        )


class LiveKitAgentsAdapter:
    """Boundary for LiveKit Agents real-time voice sessions."""

    def __init__(self) -> None:
        self.url = os.getenv("LIVEKIT_URL", "").strip()
        self.api_key = os.getenv("LIVEKIT_API_KEY", "").strip()
        self.api_secret = os.getenv("LIVEKIT_API_SECRET", "").strip()

    @property
    def configured(self) -> bool:
        return bool(self.url and self.api_key and self.api_secret)

    def status(self) -> AdapterStatus:
        if not self.configured:
            return AdapterStatus(
                available=False,
                name="LiveKit Agents",
                detail=(
                    "Missing LIVEKIT_URL / LIVEKIT_API_KEY / LIVEKIT_API_SECRET. "
                    "Token route stays disabled; on-device voice remains active."
                ),
            )
        return AdapterStatus(
            available=True,
            name="LiveKit Agents",
            detail=(
                "LiveKit credentials detected. Token minting can be enabled. "
                "Flutter still needs livekit_client room wiring for full barge-in audio."
            ),
        )


def discover_ai_status() -> dict:
    stt = NvidiaKinyarwandaSttAdapter().status()
    tts = KinyaFlexTtsAdapter().status()
    altatts = AltaTtsCallAdapter().status()
    alta_console = AltaConsoleTtsAdapter().status()
    livekit = LiveKitAgentsAdapter().status()
    local_llm = LocalHeuristicLlmAdapter().status()
    remote_llm = OptionalRemoteLlmAdapter().status()
    return {
        "assistant": {
            "mode": local_llm["name"],
            "available": True,
            "detail": local_llm["detail"],
        },
        "evaluation": {
            "nvidia_stt_rw": {
                "streaming_native_in_hf_card": False,
                "approx_params_million": 120,
                "reported_test_wer_pct": 18.22,
                "notes": (
                    "Use NeMo file/chunk transcription or Riva for streaming. "
                    "Not suitable to embed in the Flutter app."
                ),
            },
            "kinyarwanda_tts": {
                "preferred": KinyaFlexTtsAdapter.MODEL_ID,
                "alternate": KinyaFlexTtsAdapter.ALTERNATE_MODEL_ID,
                "native_speaker_certified": False,
            },
            "altatts_call_tts": {
                "package": AltaTtsCallAdapter.PACKAGE,
                "version_target": AltaTtsCallAdapter.PACKAGE_VERSION,
                "license": AltaTtsCallAdapter.LICENSE,
                "weights_on_pypi": False,
                "production_wired": False,
                "recommendation": "investigate_further",
                "report": "docs/ALTATTS_EVALUATION_REPORT.md",
            },
            "alta_console_tts": {
                "configured": AltaConsoleTtsAdapter().configured,
                "production_wired": False,
                "base_url_env": "ALTA_BASE_URL",
                "enable_env": "ENABLE_ALTA_CONSOLE_TTS",
            },
        },
        "adapters": [
            {
                "name": item.name,
                "available": item.available,
                "detail": item.detail,
            }
            for item in (stt, tts, altatts, alta_console, livekit)
        ],
        "llm": [local_llm, remote_llm],
    }
