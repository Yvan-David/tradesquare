"""Call translation adapters for TradeSquare video/audio calls.

Architecture:
- Same-language calls bypass this module entirely (direct LiveKit A/V).
- Different-language calls use independent A→B and B→A directions.
- STT is chunk/file oriented unless a streaming worker is configured.
- Do not mix participant audio before recognition.
"""

from __future__ import annotations

import base64
import os
import re
from dataclasses import dataclass
from typing import Any


SUPPORTED_CALL_LANGS = ("rw", "sw", "en", "fr")

# Small offline glossary for RW↔SW smoke tests only. Not a production MT model.
_RW_SW_GLOSSARY: dict[str, str] = {
    "muraho": "hujambo",
    "amakuru": "habari",
    "meza": "nzuri",
    "murakoze": "asante",
    "ego": "ndiyo",
    "oya": "hapana",
    "mfite": "nina",
    "ngiye": "ninaenda",
    "ubucuruzi": "biashara",
    "ibicuruzwa": "bidhaa",
    "igiciro": "bei",
    "twavugana": "tuzungumze",
}

_SW_RW_GLOSSARY: dict[str, str] = {v: k for k, v in _RW_SW_GLOSSARY.items()}


@dataclass(frozen=True)
class TranslationResult:
    source_text: str
    translated_text: str
    source_lang: str
    target_lang: str
    mode: str
    note: str
    audio_base64: str | None = None
    latency_ms: int | None = None


def normalize_lang(code: str | None) -> str:
    value = (code or "en").strip().lower()
    if value.startswith("rw"):
        return "rw"
    if value.startswith("sw"):
        return "sw"
    if value.startswith("fr"):
        return "fr"
    if value.startswith("en"):
        return "en"
    return value[:8]


def translation_required(local_lang: str, remote_lang: str) -> bool:
    return normalize_lang(local_lang) != normalize_lang(remote_lang)


class CallTranslationAdapter:
    """Text + optional audio translation for call workers."""

    def __init__(self) -> None:
        self.libre_url = os.getenv("CALL_LIBRETRANSLATE_URL", "").strip().rstrip("/")
        self.stt_worker = os.getenv("CALL_STT_WORKER_URL", "").strip().rstrip("/")
        self.tts_worker = os.getenv("CALL_TTS_WORKER_URL", "").strip().rstrip("/")

    def status(self) -> dict[str, Any]:
        return {
            "supported_languages": list(SUPPORTED_CALL_LANGS),
            "primary_pair": ["rw", "sw"],
            "same_language_bypass": True,
            "streaming_stt_native": False,
            "chunk_stt": bool(self.stt_worker),
            "libretranslate": bool(self.libre_url),
            "glossary_fallback_rw_sw": True,
            "tts_worker": bool(self.tts_worker),
            "detail": (
                "Chunk STT/TTS require CALL_STT_WORKER_URL / CALL_TTS_WORKER_URL. "
                "Without workers, RW↔SW uses a limited offline glossary for text only. "
                "NVIDIA NeMo RW STT is file/chunk (~18% WER), not native streaming."
            ),
        }

    def translate_text(
        self,
        text: str,
        *,
        source_lang: str,
        target_lang: str,
    ) -> TranslationResult:
        source = normalize_lang(source_lang)
        target = normalize_lang(target_lang)
        cleaned = " ".join((text or "").split()).strip()
        if not cleaned:
            return TranslationResult(
                source_text="",
                translated_text="",
                source_lang=source,
                target_lang=target,
                mode="empty",
                note="No speech text to translate.",
            )
        if source == target:
            return TranslationResult(
                source_text=cleaned,
                translated_text=cleaned,
                source_lang=source,
                target_lang=target,
                mode="bypass",
                note="Same language — translation bypassed.",
            )

        if self.libre_url:
            remote = self._libre_translate(cleaned, source=source, target=target)
            if remote is not None:
                return TranslationResult(
                    source_text=cleaned,
                    translated_text=remote,
                    source_lang=source,
                    target_lang=target,
                    mode="libretranslate",
                    note="Translated via LibreTranslate worker.",
                )

        glossary = self._glossary_translate(cleaned, source=source, target=target)
        if glossary is not None:
            return TranslationResult(
                source_text=cleaned,
                translated_text=glossary,
                source_lang=source,
                target_lang=target,
                mode="glossary",
                note=(
                    "Limited offline RW↔SW glossary used. Deploy LibreTranslate or an "
                    "approved MT worker for production quality."
                ),
            )

        return TranslationResult(
            source_text=cleaned,
            translated_text="",
            source_lang=source,
            target_lang=target,
            mode="unavailable",
            note=(
                f"No MT path for {source}→{target}. Configure CALL_LIBRETRANSLATE_URL "
                "or extend the glossary/worker adapters."
            ),
        )

    def _libre_translate(self, text: str, *, source: str, target: str) -> str | None:
        try:
            import httpx
        except Exception:
            return None
        # LibreTranslate uses ISO codes; map rw→rw if supported by the instance.
        payload = {"q": text, "source": source, "target": target, "format": "text"}
        try:
            with httpx.Client(timeout=8.0) as client:
                response = client.post(f"{self.libre_url}/translate", json=payload)
                if response.status_code >= 400:
                    return None
                data = response.json()
                translated = data.get("translatedText") or data.get("translation")
                return str(translated).strip() if translated else None
        except Exception:
            return None

    def _glossary_translate(self, text: str, *, source: str, target: str) -> str | None:
        table: dict[str, str] | None = None
        if source == "rw" and target == "sw":
            table = _RW_SW_GLOSSARY
        elif source == "sw" and target == "rw":
            table = _SW_RW_GLOSSARY
        if not table:
            return None

        tokens = re.findall(r"[A-Za-zÀ-ÿ']+|[^A-Za-zÀ-ÿ']+", text.lower())
        out: list[str] = []
        hits = 0
        for token in tokens:
            key = token.strip().lower()
            if key in table:
                out.append(table[key])
                hits += 1
            else:
                out.append(token)
        if hits == 0:
            return None
        return "".join(out).strip()

    def transcribe_chunk_status(self) -> dict[str, Any]:
        if not self.stt_worker:
            return {
                "available": False,
                "streaming": False,
                "detail": (
                    "CALL_STT_WORKER_URL is unset. Chunk transcription is unavailable. "
                    "Do not claim streaming STT for NVIDIA NeMo file models."
                ),
            }
        return {
            "available": True,
            "streaming": False,
            "worker": self.stt_worker,
            "detail": (
                "Chunk STT worker configured. Expect multi-hundred-ms to multi-second "
                "latency per chunk; not true frame streaming unless the worker says so."
            ),
        }
