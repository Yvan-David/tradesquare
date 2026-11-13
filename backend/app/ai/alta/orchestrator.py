"""Call translation orchestrator — control plane only.

LiveKit remains the media plane. This module decides whether to bypass AI,
run A→B / B→A text pipelines, and records honest capability/latency notes.
It does **not** claim a complete dual-participant LiveKit audio loop until
wired and tested with real devices.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any

from .config import load_alta_settings
from .translation import TranslationProviderRegistry, TranslationResult
from .tts import AltaTtsAdapter



@dataclass
class CallLanguagePrefs:
    local_language: str
    remote_language: str
    translation_enabled: bool = True
    local_clone_id: str | None = None
    remote_clone_id: str | None = None
    prefer_translated_audio: bool = True
    captions_enabled: bool = True


@dataclass
class PipelineTurnResult:
    direction: str
    bypassed: bool
    source_text: str | None = None
    translated_text: str | None = None
    translation: TranslationResult | None = None
    tts_bytes: bytes | None = None
    tts_voice: str | None = None
    latency_ms: dict[str, float] = field(default_factory=dict)
    detail: str | None = None


class CallTranslationOrchestrator:
    def __init__(
        self,
        registry: TranslationProviderRegistry | None = None,
        tts: AltaTtsAdapter | None = None,
    ):
        self.registry = registry or TranslationProviderRegistry()
        self.tts = tts or AltaTtsAdapter()
        self.settings = load_alta_settings()

    def should_bypass(self, prefs: CallLanguagePrefs) -> bool:
        if not prefs.translation_enabled:
            return True
        if not self.settings.feature_on("call_translation"):
            return True
        return prefs.local_language.lower() == prefs.remote_language.lower()

    async def process_final_utterance(
        self,
        *,
        direction: str,
        source_text: str,
        source_lang: str,
        target_lang: str,
        prefs: CallLanguagePrefs,
        clone_id: str | None = None,
        builtin_voice: str = "keza",
    ) -> PipelineTurnResult:
        """Translate a *final* transcript only — never unstable partials."""
        t0 = time.perf_counter()
        if self.should_bypass(prefs) or not source_text.strip():
            return PipelineTurnResult(
                direction=direction,
                bypassed=True,
                source_text=source_text,
                detail="Same-language or translation disabled — LiveKit original audio.",
            )

        t_tr = time.perf_counter()
        translation = await self.registry.translate(
            source_text,
            target=target_lang,
            source=source_lang or "auto",
            quality=False,
            sentence_level=True,
        )
        translate_ms = (time.perf_counter() - t_tr) * 1000
        if not translation.ok:
            return PipelineTurnResult(
                direction=direction,
                bypassed=False,
                source_text=source_text,
                translation=translation,
                latency_ms={"translate_ms": round(translate_ms, 2)},
                detail=translation.detail or "Translation failed — keep original audio.",
            )

        audio: bytes | None = None
        voice_used = builtin_voice
        tts_ms = 0.0
        if self.settings.feature_on("tts") and prefs.prefer_translated_audio:
            t_tts = time.perf_counter()
            try:
                if clone_id and self.settings.feature_on("voice_cloning"):
                    from .cloning import AltaVoiceCloningAdapter

                    audio = await AltaVoiceCloningAdapter().speak(
                        clone_id,
                        text=translation.text,
                        language=target_lang,
                    )
                    voice_used = clone_id
                else:
                    result = self.tts.synthesize_sync(
                        translation.text,
                        voice=builtin_voice,
                        language=target_lang,
                    )
                    audio = result.audio
                    voice_used = result.voice or builtin_voice
            except Exception as exc:  # noqa: BLE001
                return PipelineTurnResult(
                    direction=direction,
                    bypassed=False,
                    source_text=source_text,
                    translated_text=translation.text,
                    translation=translation,
                    latency_ms={
                        "translate_ms": round(translate_ms, 2),
                        "tts_ms": round((time.perf_counter() - t_tts) * 1000, 2),
                    },
                    detail=f"TTS failed ({exc}); captions may still show translation.",
                )
            tts_ms = (time.perf_counter() - t_tts) * 1000

        return PipelineTurnResult(
            direction=direction,
            bypassed=False,
            source_text=source_text,
            translated_text=translation.text,
            translation=translation,
            tts_bytes=audio,
            tts_voice=voice_used,
            latency_ms={
                "translate_ms": round(translate_ms, 2),
                "tts_ms": round(tts_ms, 2),
                "total_ms": round((time.perf_counter() - t0) * 1000, 2),
            },
        )

    def status(self) -> dict[str, Any]:
        return {
            "call_translation_enabled": self.settings.feature_on("call_translation"),
            "same_language_bypass": True,
            "swahili_translation": (
                "unavailable_via_alta — needs separate provider"
            ),
            "livekit_media_plane": "unchanged",
            "production_complete": False,
            "detail": (
                "Orchestrator ready for final-utterance text→translate→TTS. "
                "Full duplex LiveKit audio capture/injection is not claimed complete."
            ),
        }
