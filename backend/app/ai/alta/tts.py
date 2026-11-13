"""ALTA TTS facade — wraps hosted synthesis; does not replace device TTS."""

from __future__ import annotations

from typing import Any

from app.ai.alta_console_tts import AltaConsoleTtsAdapter, AltaTtsResult

from .client import AltaClient
from .config import load_alta_settings


class AltaTtsAdapter:
    """Uses the existing Alta Console HTTP client for `/synthesis/tts`."""

    def __init__(self, client: AltaClient | None = None):
        self.client = client or AltaClient()
        self.settings = load_alta_settings()
        self._legacy = AltaConsoleTtsAdapter()

    def status(self) -> dict[str, Any]:
        enabled = self.settings.feature_on("tts")
        return {
            "available": enabled and self.settings.configured,
            "configured": self.settings.configured,
            "enabled": enabled,
            "detail": (
                "ALTA TTS ready"
                if enabled and self.settings.configured
                else "Set ALTA_ENABLED + ALTA_TTS_ENABLED (or ENABLE_ALTA_CONSOLE_TTS for eval)."
            ),
            "languages_documented": ["rw", "sw", "en", "fr"],
            "streaming_documented": True,
            "streaming_kind": "sentence SSE via /synthesis/tts/stream",
        }

    async def list_voices(self) -> Any:
        return await self.client.get_json("/synthesis/voices")

    def synthesize_sync(
        self,
        text: str,
        *,
        voice: str = "keza",
        language: str | None = None,
        sample_rate: int = 22050,
        format: str = "wav",
        readable: bool = False,
    ) -> AltaTtsResult:
        if not self.settings.feature_on("tts") and not self._legacy.enabled:
            raise RuntimeError("ALTA TTS is disabled")
        return self._legacy.synthesize(
            text,
            voice=voice,
            language=language,
            sample_rate=sample_rate,
            format=format,
            readable=readable,
        )
