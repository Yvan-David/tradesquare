"""Honest ALTA capability discovery — probe live endpoints, never invent success."""

from __future__ import annotations

from typing import Any

from .client import AltaApiError, AltaClient
from .config import load_alta_settings


async def discover_alta_capabilities(client: AltaClient | None = None) -> dict[str, Any]:
    settings = load_alta_settings()
    client = client or AltaClient(settings)
    matrix = {
        "live_transcription": {"available": False, "detail": "not probed"},
        "file_transcription": {"available": False, "detail": "not probed"},
        "translation_rw_en_fr": {"available": False, "detail": "not probed"},
        "translation_swahili": {
            "available": False,
            "detail": (
                "ALTA translation docs: Swahili is unsupported "
                "(on_unsupported=error). Requires a separate provider."
            ),
        },
        "tts_builtin": {"available": False, "detail": "not probed"},
        "voice_cloning": {"available": False, "detail": "not probed"},
        "cross_language_cloned_speech": {
            "available": False,
            "detail": "Requires cloning + TTS tests with consenting audio; not assumed.",
        },
        "live_call_translation": {
            "available": False,
            "detail": (
                "Orchestrator exists but end-to-end LiveKit pipeline is not "
                "claimed complete until real dual-participant tests pass."
            ),
        },
    }
    meta: dict[str, Any] = {
        "configured": settings.configured,
        "enabled": settings.enabled,
        "flags": {
            "ALTA_ENABLED": settings.enabled,
            "ALTA_TRANSCRIPTION_ENABLED": settings.transcription_enabled,
            "ALTA_TRANSLATION_ENABLED": settings.translation_enabled,
            "ALTA_TTS_ENABLED": settings.tts_enabled,
            "ALTA_VOICE_CLONING_ENABLED": settings.voice_cloning_enabled,
            "ALTA_LIVE_TRANSCRIPTION_ENABLED": settings.live_transcription_enabled,
            "ALTA_CALL_TRANSLATION_ENABLED": settings.call_translation_enabled,
        },
        "base_url": settings.http_base,
        "probes": {},
        "matrix": matrix,
    }
    if not settings.configured:
        meta["detail"] = "ALTA_API_KEY unset"
        return meta

    async def probe(name: str, path: str) -> None:
        try:
            data = await client.get_json(path)
            meta["probes"][name] = {"ok": True, "sample": _shrink(data)}
            return
        except AltaApiError as exc:
            meta["probes"][name] = {
                "ok": False,
                "status_code": exc.status_code,
                "body": _shrink(exc.body),
            }
        except Exception as exc:  # noqa: BLE001
            meta["probes"][name] = {"ok": False, "error": str(exc)}

    await probe("health", "/health")
    await probe("models", "/models")
    await probe("transcription_models", "/transcription/models")
    await probe("translation_languages", "/translation/languages")
    await probe("synthesis_voices", "/synthesis/voices")
    await probe("cloning_voices", "/cloning/voices")

    if meta["probes"].get("transcription_models", {}).get("ok"):
        matrix["live_transcription"] = {
            "available": settings.live_transcription_enabled and settings.enabled,
            "detail": "Models endpoint reachable; enable ALTA_LIVE_TRANSCRIPTION_ENABLED.",
            "documented_languages_v2": ["rw", "en", "fr"],
            "documented_languages_v1": ["rw"],
        }
        matrix["file_transcription"] = {
            "available": settings.transcription_enabled and settings.enabled,
            "detail": "Models endpoint reachable; enable ALTA_TRANSCRIPTION_ENABLED.",
        }
    if meta["probes"].get("translation_languages", {}).get("ok"):
        langs = meta["probes"]["translation_languages"].get("sample") or {}
        matrix["translation_rw_en_fr"] = {
            "available": settings.translation_enabled and settings.enabled,
            "detail": "Languages endpoint reachable; pairs are rw/en/fr only per docs.",
            "payload": langs,
        }
    if meta["probes"].get("synthesis_voices", {}).get("ok"):
        matrix["tts_builtin"] = {
            "available": settings.tts_enabled and settings.enabled,
            "detail": "Synthesis voices reachable; TTS supports rw/sw/en/fr per docs.",
            "languages_claimed": ["rw", "sw", "en", "fr"],
        }
    if meta["probes"].get("cloning_voices", {}).get("ok"):
        matrix["voice_cloning"] = {
            "available": settings.voice_cloning_enabled and settings.enabled,
            "detail": "Cloning list reachable; enrollment still requires consent + audio.",
        }

    return meta


def _shrink(value: Any, limit: int = 800) -> Any:
    text = str(value)
    if len(text) <= limit:
        return value
    return text[:limit] + "…"
