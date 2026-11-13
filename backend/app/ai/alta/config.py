"""ALTA (YaliLabs) configuration — secrets stay on the backend only."""

from __future__ import annotations

import os
from dataclasses import dataclass


DEFAULT_BASE_URL = "https://alta.yalilabs.com/v1"

_TRUE = {"1", "true", "yes", "on"}


def _flag(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in _TRUE


@dataclass(frozen=True)
class AltaSettings:
    base_url: str
    api_key: str
    enabled: bool
    transcription_enabled: bool
    translation_enabled: bool
    tts_enabled: bool
    voice_cloning_enabled: bool
    live_transcription_enabled: bool
    call_translation_enabled: bool
    transcription_model: str
    transcription_quality: str
    live_transcription_persist: bool
    request_timeout: float

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    @property
    def http_base(self) -> str:
        return self.base_url.rstrip("/")

    @property
    def ws_base(self) -> str:
        base = self.http_base
        if base.startswith("https://"):
            return "wss://" + base[len("https://") :]
        if base.startswith("http://"):
            return "ws://" + base[len("http://") :]
        return base

    def feature_on(self, feature: str) -> bool:
        if not self.enabled or not self.configured:
            return False
        return {
            "transcription": self.transcription_enabled,
            "translation": self.translation_enabled,
            "tts": self.tts_enabled,
            "voice_cloning": self.voice_cloning_enabled,
            "live_transcription": self.live_transcription_enabled,
            "call_translation": self.call_translation_enabled,
        }.get(feature, False)


def load_alta_settings() -> AltaSettings:
    # Backward-compatible with ENABLE_ALTA_CONSOLE_TTS for TTS-only eval.
    tts_legacy = _flag("ENABLE_ALTA_CONSOLE_TTS")
    return AltaSettings(
        base_url=(os.getenv("ALTA_BASE_URL", DEFAULT_BASE_URL).strip() or DEFAULT_BASE_URL),
        api_key=os.getenv("ALTA_API_KEY", "").strip(),
        enabled=_flag("ALTA_ENABLED"),
        transcription_enabled=_flag("ALTA_TRANSCRIPTION_ENABLED"),
        translation_enabled=_flag("ALTA_TRANSLATION_ENABLED"),
        tts_enabled=_flag("ALTA_TTS_ENABLED") or tts_legacy,
        voice_cloning_enabled=_flag("ALTA_VOICE_CLONING_ENABLED"),
        live_transcription_enabled=_flag("ALTA_LIVE_TRANSCRIPTION_ENABLED"),
        call_translation_enabled=_flag("ALTA_CALL_TRANSLATION_ENABLED"),
        transcription_model=os.getenv("ALTA_TRANSCRIPTION_MODEL", "v2").strip() or "v2",
        transcription_quality=os.getenv("ALTA_TRANSCRIPTION_QUALITY", "fast").strip()
        or "fast",
        live_transcription_persist=_flag("ALTA_LIVE_TRANSCRIPTION_PERSIST"),
        request_timeout=float(os.getenv("ALTA_REQUEST_TIMEOUT", "30") or "30"),
    )
