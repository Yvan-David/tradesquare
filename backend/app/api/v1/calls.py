"""Messaging call session, LiveKit token, and translation control plane."""

from __future__ import annotations

import time
import uuid
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.ai.adapters import LiveKitAgentsAdapter
from app.ai.alta_console_tts import AltaConsoleTtsAdapter
from app.ai.altatts_adapter import AltaTtsCallAdapter
from app.ai.call_translation import (
    CallTranslationAdapter,
    normalize_lang,
    translation_required,
)

router = APIRouter(prefix="/api/v1/calls", tags=["calls"])


class CallTokenRequest(BaseModel):
    identity: str = Field(min_length=1, max_length=128)
    conversation_id: str = Field(min_length=1, max_length=128)
    media: str = Field(default="video", pattern="^(audio|video)$")
    local_language: str = Field(default="en", max_length=16)
    remote_language: str = Field(default="en", max_length=16)
    display_name: str | None = Field(default=None, max_length=128)
    room: str | None = Field(default=None, max_length=128)


class TranslateTextRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    source_lang: str = Field(min_length=2, max_length=16)
    target_lang: str = Field(min_length=2, max_length=16)
    direction: str | None = Field(default=None, max_length=8)


class CallSessionPrefsRequest(BaseModel):
    conversation_id: str = Field(min_length=1, max_length=128)
    local_language: str = Field(min_length=2, max_length=16)
    remote_language: str = Field(min_length=2, max_length=16)
    translation_enabled: bool = True


@router.get("/health")
def calls_health() -> dict[str, Any]:
    livekit = LiveKitAgentsAdapter()
    translation = CallTranslationAdapter()
    return {
        "ok": True,
        "livekit_configured": livekit.configured,
        "livekit": livekit.status().detail,
        "translation": translation.status(),
    }


@router.get("/capabilities")
def calls_capabilities() -> dict[str, Any]:
    livekit = LiveKitAgentsAdapter()
    translation = CallTranslationAdapter()
    altatts = AltaTtsCallAdapter()
    return {
        "video": True,
        "audio": True,
        "camera_switch": True,
        "livekit": {
            "configured": livekit.configured,
            "detail": livekit.status().detail,
        },
        "translation": translation.status(),
        "stt": translation.transcribe_chunk_status(),
        "altatts_tts": altatts.capabilities_probe(),
        "alta_console_tts": AltaConsoleTtsAdapter().capabilities_probe(),
    }


@router.post("/livekit/token")
def mint_call_livekit_token(payload: CallTokenRequest) -> dict[str, Any]:
    """Mint a messaging-call LiveKit token. Secrets never leave the server."""
    adapter = LiveKitAgentsAdapter()
    if not adapter.configured:
        raise HTTPException(status_code=503, detail=adapter.status().detail)

    try:
        from livekit import api  # type: ignore
    except Exception as exc:  # pragma: no cover - optional dependency
        raise HTTPException(
            status_code=503,
            detail=(
                "livekit Python package is not installed. "
                "Run: pip install livekit"
            ),
        ) from exc

    room = payload.room or f"tradesquare-call-{payload.conversation_id}"
    identity = payload.identity.strip()
    name = (payload.display_name or identity).strip()
    local_lang = normalize_lang(payload.local_language)
    remote_lang = normalize_lang(payload.remote_language)
    needs_translation = translation_required(local_lang, remote_lang)

    token = (
        api.AccessToken(adapter.api_key, adapter.api_secret)
        .with_identity(identity)
        .with_name(name)
        .with_metadata(
            f'{{"conversation_id":"{payload.conversation_id}",'
            f'"media":"{payload.media}",'
            f'"local_language":"{local_lang}",'
            f'"remote_language":"{remote_lang}"}}'
        )
        .with_grants(
            api.VideoGrants(
                room_join=True,
                room=room,
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True,
            )
        )
        .to_jwt()
    )
    return {
        "ok": True,
        "url": adapter.url,
        "room": room,
        "token": token,
        "identity": identity,
        "media": payload.media,
        "local_language": local_lang,
        "remote_language": remote_lang,
        "translation_required": needs_translation,
        "issued_at": int(time.time()),
        "note": (
            "Join with livekit_client. Same-language calls use direct A/V only. "
            "Translation workers are separate from the media plane."
        ),
    }


@router.post("/translate/text")
def translate_call_text(payload: TranslateTextRequest) -> dict[str, Any]:
    adapter = CallTranslationAdapter()
    result = adapter.translate_text(
        payload.text,
        source_lang=payload.source_lang,
        target_lang=payload.target_lang,
    )
    status = 200 if result.mode != "unavailable" else 503
    body = {
        "ok": result.mode != "unavailable",
        "source_text": result.source_text,
        "translated_text": result.translated_text,
        "source_lang": result.source_lang,
        "target_lang": result.target_lang,
        "mode": result.mode,
        "note": result.note,
        "direction": payload.direction,
        "audio_base64": result.audio_base64,
    }
    if status == 503:
        raise HTTPException(status_code=503, detail=body)
    return body


@router.post("/session/prefs")
def upsert_call_session_prefs(payload: CallSessionPrefsRequest) -> dict[str, Any]:
    """Acknowledge language preference updates for an active call.

    Persisted session store can replace this in-memory acknowledgement later.
    """
    local_lang = normalize_lang(payload.local_language)
    remote_lang = normalize_lang(payload.remote_language)
    required = translation_required(local_lang, remote_lang)
    enabled = bool(payload.translation_enabled) and required
    return {
        "ok": True,
        "conversation_id": payload.conversation_id,
        "local_language": local_lang,
        "remote_language": remote_lang,
        "translation_required": required,
        "translation_enabled": enabled,
        "mode": "active" if enabled else ("bypassed" if not required else "disabled"),
        "session_hint": f"call-prefs-{payload.conversation_id}-{uuid.uuid4().hex[:6]}",
    }


@router.post("/translate/chunk")
def translate_audio_chunk_unavailable() -> dict[str, Any]:
    """Honest boundary for audio-chunk STT→MT→TTS.

    Returns 503 until CALL_STT_WORKER_URL points at a real chunk worker.
    """
    adapter = CallTranslationAdapter()
    stt = adapter.transcribe_chunk_status()
    raise HTTPException(
        status_code=503,
        detail={
            "ok": False,
            "stt": stt,
            "note": (
                "Audio chunk translation is not active in this API process. "
                "Deploy a per-participant LiveKit Agent or STT worker, then wire "
                "CALL_STT_WORKER_URL / CALL_TTS_WORKER_URL. Video calls continue "
                "without translation when this fails."
            ),
        },
    )
