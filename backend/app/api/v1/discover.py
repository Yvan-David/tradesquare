"""Discover assistant and catalog endpoints.

These endpoints expose honest capability status and a lightweight chat turn
contract. Heavy GPU models are not loaded here.
"""

from __future__ import annotations

import os
import time
import uuid
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.ai.adapters import LiveKitAgentsAdapter, discover_ai_status
from app.ai.llm import get_llm_adapter

router = APIRouter(prefix="/api/v1/discover", tags=["discover"])


class DiscoverChatMessage(BaseModel):
    role: str
    content: str


class DiscoverChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    locale: str | None = None
    business_name: str | None = None
    history: list[DiscoverChatMessage] = Field(default_factory=list)


class DiscoverChatResponse(BaseModel):
    reply: str
    language: str
    mode: str
    note: str
    intent: str
    tools_available: list[str]


class LiveKitTokenRequest(BaseModel):
    identity: str = Field(min_length=1, max_length=128)
    room: str | None = None


@router.get("/health")
def discover_health() -> dict:
    return {"ok": True, **discover_ai_status()}


@router.get("/capabilities")
def discover_capabilities() -> dict:
    return discover_ai_status()


@router.post("/chat", response_model=DiscoverChatResponse)
def discover_chat(payload: DiscoverChatRequest) -> DiscoverChatResponse:
    """Conversational turn helper.

    Business catalogue matching remains authoritative in the Flutter client /
    catalog services. This endpoint provides language-aware intent routing and
    concise replies without inventing companies or scores.
    """
    llm = get_llm_adapter()
    history = [{"role": item.role, "content": item.content} for item in payload.history]
    turn = llm.complete(
        payload.message,
        locale=payload.locale,
        history=history,
    )

    return DiscoverChatResponse(
        reply=turn.reply,
        language=turn.language,
        mode=turn.mode,
        note=turn.note,
        intent=turn.intent,
        tools_available=[
            "search_businesses",
            "open_messages",
            "open_business_profile",
            "open_opportunities",
            "open_home",
            "draft_buying_request",
            "improve_business_description",
        ],
    )


@router.post("/livekit/token")
def mint_livekit_token(payload: LiveKitTokenRequest) -> dict[str, Any]:
    """Mint a LiveKit room token when credentials exist.

    Returns 503 with an explicit setup message when LiveKit is not configured.
    Never embeds API secrets in the response.
    """
    adapter = LiveKitAgentsAdapter()
    if not adapter.configured:
        raise HTTPException(
            status_code=503,
            detail=adapter.status().detail,
        )

    try:
        from livekit import api  # type: ignore
    except Exception as exc:  # pragma: no cover - optional dependency
        raise HTTPException(
            status_code=503,
            detail=(
                "livekit Python package is not installed. "
                "Add `livekit` to requirements and install it before enabling Agents."
            ),
        ) from exc

    room = payload.room or f"tradesquare-discover-{uuid.uuid4().hex[:8]}"
    token = (
        api.AccessToken(adapter.api_key, adapter.api_secret)
        .with_identity(payload.identity)
        .with_name(payload.identity)
        .with_grants(
            api.VideoGrants(
                room_join=True,
                room=room,
                can_publish=True,
                can_subscribe=True,
            )
        )
        .to_jwt()
    )
    return {
        "ok": True,
        "url": adapter.url,
        "room": room,
        "token": token,
        "issued_at": int(time.time()),
        "note": (
            "Token minted. Flutter still needs a LiveKit room client for realtime "
            "audio, VAD and barge-in. On-device voice remains the default path."
        ),
    }


@router.get("/voice/providers")
def voice_providers() -> dict:
    return {
        "stt_worker_url": os.getenv("DISCOVER_STT_WORKER_URL", ""),
        "tts_worker_url": os.getenv("DISCOVER_TTS_WORKER_URL", ""),
        "llm_url": os.getenv("DISCOVER_LLM_URL", ""),
        "status": discover_ai_status(),
    }
