"""Authenticated ALTA control-plane routes. API key never leaves the server."""

from __future__ import annotations

import asyncio
import json
from typing import Any, Literal

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from pydantic import BaseModel, Field

from app.ai.alta.audio import validate_live_audio_hint
from app.ai.alta.capabilities import discover_alta_capabilities
from app.ai.alta.client import AltaApiError, AltaClient
from app.ai.alta.cloning import AltaVoiceCloningAdapter
from app.ai.alta.config import load_alta_settings
from app.ai.alta.orchestrator import CallLanguagePrefs, CallTranslationOrchestrator
from app.ai.alta.transcription import (
    AltaTranscriptionAdapter,
    validate_consent_profile,
)
from app.ai.alta.translation import TranslationProviderRegistry
from app.ai.alta.tts import AltaTtsAdapter

router = APIRouter(prefix="/api/v1/alta", tags=["alta"])

# Official ALTA Transcription docs — no non_binary
VALID_GENDERS = Literal["female", "male", "other", "prefer_not_to_say"]


class TranslateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=20000)
    target: str = Field(min_length=2, max_length=8)
    source: str = Field(default="auto", max_length=8)
    quality: bool = True
    sentence_level: bool = True
    source_hint: str | None = Field(default=None, max_length=8)
    preserve_lines: bool = True
    on_unsupported: Literal["error", "copy"] = "error"


class TranslateBatchItem(BaseModel):
    text: str = Field(min_length=1, max_length=20000)
    target: str = Field(min_length=2, max_length=8)
    source: str = Field(default="auto", max_length=8)
    source_hint: str | None = Field(default=None, max_length=8)
    preserve_lines: bool = True
    sentence_level: bool = True
    on_unsupported: Literal["error", "copy"] = "error"


class TranslateBatchRequest(BaseModel):
    items: list[TranslateBatchItem] = Field(min_length=1, max_length=256)
    mode: Literal["quality", "draft"] = "quality"


class DetectRequest(BaseModel):
    text: str = Field(min_length=1, max_length=20000)


class TtsRequest(BaseModel):
    text: str = Field(min_length=1, max_length=20000)
    voice: str = "keza"
    language: str | None = None
    sample_rate: int = 22050
    format: str = "wav"
    readable: bool = False


class CloneSpeakRequest(BaseModel):
    text: str = Field(min_length=1, max_length=20000)
    language: str | None = None
    sample_rate: int = 22050
    format: str = "wav"
    emotion: str | None = None
    speed: float | None = None


class CallTurnRequest(BaseModel):
    direction: str = Field(pattern="^(a_to_b|b_to_a)$")
    source_text: str = Field(min_length=1, max_length=4000)
    source_lang: str = "auto"
    target_lang: str
    local_language: str
    remote_language: str
    translation_enabled: bool = True
    clone_id: str | None = None
    builtin_voice: str = "keza"
    prefer_translated_audio: bool = True


class LiveStartClientMessage(BaseModel):
    """Client→server control after connecting to our WS proxy (no ALTA key)."""

    cmd: str
    consent: bool | None = None
    gender: VALID_GENDERS | None = None
    model: str | None = None
    diarization: bool = True
    persist: bool = False
    # ALTA default is float32 LE @ 16 kHz; pcm_s16le halves uplink for mobile.
    audio_encoding: str = "pcm_f32le"
    sample_rate: int | None = 16000
    channels: int | None = 1


def _http_error(exc: AltaApiError) -> HTTPException:
    return HTTPException(status_code=exc.status_code, detail=exc.body)


@router.get("/status")
async def alta_status() -> dict[str, Any]:
    settings = load_alta_settings()
    caps = await discover_alta_capabilities()
    return {
        "ok": True,
        "settings": {
            "configured": settings.configured,
            "enabled": settings.enabled,
            "base_url": settings.http_base,
            "flags": caps.get("flags"),
        },
        "capabilities": caps,
        "orchestrator": CallTranslationOrchestrator().status(),
        "privacy": {
            "api_key_on_client": False,
            "prefer_live_persist_false": True,
            "file_transcription_stores_audio": True,
            "note": (
                "File transcription docs: recordings+profiles may be stored to improve "
                "the model. Live sessions should use persist=false for private calls, "
                "with explicit dual-party consent before forwarding audio."
            ),
        },
    }


@router.get("/health")
async def alta_upstream_health() -> dict[str, Any]:
    settings = load_alta_settings()
    if not settings.configured:
        raise HTTPException(status_code=503, detail="ALTA_API_KEY unset")
    client = AltaClient(settings)
    try:
        data = await client.get_json("/health")
        return {"ok": True, "upstream": data}
    except AltaApiError as exc:
        raise _http_error(exc) from exc


@router.get("/languages")
async def alta_languages() -> dict[str, Any]:
    """Capability matrix by feature — not a single invented language list."""
    return {
        "transcription_live_v2": ["rw", "en", "fr"],
        "transcription_live_v1": ["rw"],
        "translation_alta": ["rw", "en", "fr"],
        "translation_swahili": {
            "supported_by_alta": False,
            "provider": "swahili_external",
            "available": False,
        },
        "tts": ["rw", "sw", "en", "fr"],
        "voice_cloning_speak_languages": ["rw", "sw", "en", "fr"],
    }


@router.post("/translation/translate")
async def translate(payload: TranslateRequest) -> dict[str, Any]:
    result = await TranslationProviderRegistry().translate(
        payload.text,
        target=payload.target,
        source=payload.source,
        quality=payload.quality,
        sentence_level=payload.sentence_level,
        source_hint=payload.source_hint,
        preserve_lines=payload.preserve_lines,
        on_unsupported=payload.on_unsupported,
    )
    status = 200 if result.ok else 503
    body = {
        "ok": result.ok,
        "provider": result.provider,
        "text": result.text,
        "source": result.source,
        "target": result.target,
        "warnings": result.warnings,
        "detail": result.detail,
        "raw": result.raw,
    }
    if not result.ok:
        raise HTTPException(status_code=status, detail=body)
    return body


@router.post("/translation/translate/batch")
async def translate_batch(payload: TranslateBatchRequest) -> dict[str, Any]:
    settings = load_alta_settings()
    if not settings.feature_on("translation"):
        raise HTTPException(status_code=503, detail="ALTA translation disabled")
    try:
        from app.ai.alta.translation import AltaTranslationProvider

        items = [item.model_dump(exclude_none=True) for item in payload.items]
        return await AltaTranslationProvider().translate_batch(
            items, mode=payload.mode
        )
    except AltaApiError as exc:
        raise _http_error(exc) from exc


@router.post("/translation/detect")
async def detect_language(payload: DetectRequest) -> dict[str, Any]:
    settings = load_alta_settings()
    if not settings.feature_on("translation"):
        raise HTTPException(status_code=503, detail="ALTA translation disabled")
    try:
        from app.ai.alta.translation import AltaTranslationProvider

        return await AltaTranslationProvider().detect(payload.text)
    except AltaApiError as exc:
        raise _http_error(exc) from exc


@router.get("/translation/languages")
async def translation_languages() -> Any:
    settings = load_alta_settings()
    if not settings.feature_on("translation"):
        raise HTTPException(status_code=503, detail="ALTA translation disabled")
    try:
        from app.ai.alta.translation import AltaTranslationProvider

        return await AltaTranslationProvider().languages()
    except AltaApiError as exc:
        raise _http_error(exc) from exc


@router.get("/tts/voices")
async def tts_voices() -> Any:
    settings = load_alta_settings()
    if not settings.feature_on("tts"):
        raise HTTPException(status_code=503, detail="ALTA TTS disabled")
    try:
        return await AltaTtsAdapter().list_voices()
    except AltaApiError as exc:
        raise _http_error(exc) from exc


@router.post("/tts/synthesize")
async def tts_synthesize(payload: TtsRequest) -> dict[str, Any]:
    import base64

    settings = load_alta_settings()
    if not settings.feature_on("tts"):
        raise HTTPException(status_code=503, detail="ALTA TTS disabled")
    try:
        result = AltaTtsAdapter().synthesize_sync(
            payload.text,
            voice=payload.voice,
            language=payload.language,
            sample_rate=payload.sample_rate,
            format=payload.format,
            readable=payload.readable,
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return {
        "ok": True,
        "format": payload.format,
        "sample_rate": result.sample_rate,
        "voice": result.voice,
        "language": result.language,
        "latency_ms_client": result.latency_ms_client,
        "latency_ms_service": result.latency_ms_service,
        "audio_seconds": result.audio_seconds,
        "audio_base64": base64.b64encode(result.audio).decode("ascii"),
    }


@router.post("/transcription/jobs")
async def create_transcription_job(
    file: UploadFile = File(...),
    consent: bool = Form(...),
    gender: str = Form(...),
    model: str = Form("v2"),
    quality: str = Form("fast"),
    age_band: str | None = Form(None),
    region: str | None = Form(None),
    speaker_name: str | None = Form(None),
) -> dict[str, Any]:
    errors = validate_consent_profile(consent=consent, gender=gender)
    if errors:
        raise HTTPException(status_code=400, detail=errors)
    content = await file.read()
    try:
        job = await AltaTranscriptionAdapter().create_job(
            filename=file.filename or "audio.wav",
            content=content,
            content_type=file.content_type or "application/octet-stream",
            consent=consent,
            gender=gender,
            model=model,
            quality=quality,
            age_band=age_band,
            region=region,
            speaker_name=speaker_name,
        )
    except AltaApiError as exc:
        raise _http_error(exc) from exc
    return {"ok": True, "job": job}


@router.get("/transcription/jobs/{job_id}")
async def get_transcription_job(job_id: str) -> dict[str, Any]:
    try:
        job = await AltaTranscriptionAdapter().get_job(job_id)
    except AltaApiError as exc:
        raise _http_error(exc) from exc
    return {"ok": True, "job": job}


@router.get("/cloning/voices")
async def list_clones() -> Any:
    try:
        return await AltaVoiceCloningAdapter().list_voices()
    except AltaApiError as exc:
        raise _http_error(exc) from exc


@router.post("/cloning/voices")
async def enroll_clone(
    files: list[UploadFile] = File(...),
    name: str = Form(...),
    language: str | None = Form(None),
    consent_voice_ownership: bool = Form(...),
    consent_external_processing: bool = Form(...),
) -> Any:
    payloads: list[tuple[str, bytes, str]] = []
    for upload in files:
        payloads.append(
            (
                upload.filename or "ref.wav",
                await upload.read(),
                upload.content_type or "audio/wav",
            )
        )
    try:
        return await AltaVoiceCloningAdapter().create_voice(
            files=payloads,
            name=name,
            language=language,
            consent_voice_ownership=consent_voice_ownership,
            consent_external_processing=consent_external_processing,
        )
    except AltaApiError as exc:
        raise _http_error(exc) from exc


@router.delete("/cloning/voices/{clone_id}")
async def delete_clone(clone_id: str) -> Any:
    try:
        return await AltaVoiceCloningAdapter().delete_voice(clone_id)
    except AltaApiError as exc:
        raise _http_error(exc) from exc


@router.post("/cloning/voices/{clone_id}/speak")
async def speak_clone(clone_id: str, payload: CloneSpeakRequest) -> Response:
    """Alias of synthesis TTS with voice=clone_… (ALTA Voice cloning docs)."""
    try:
        audio = await AltaVoiceCloningAdapter().speak(
            clone_id,
            text=payload.text,
            language=payload.language,
            sample_rate=payload.sample_rate,
            format=payload.format,
            emotion=payload.emotion,
            speed=payload.speed,
        )
    except AltaApiError as exc:
        raise _http_error(exc) from exc
    media = {
        "wav": "audio/wav",
        "pcm16": f"audio/L16; rate={payload.sample_rate}",
        "mulaw": f"audio/basic; rate={payload.sample_rate}",
        "alaw": f"audio/PCMA; rate={payload.sample_rate}",
    }.get(payload.format, "application/octet-stream")
    return Response(content=audio, media_type=media)


@router.post("/calls/turn")
async def process_call_turn(payload: CallTurnRequest) -> dict[str, Any]:
    prefs = CallLanguagePrefs(
        local_language=payload.local_language,
        remote_language=payload.remote_language,
        translation_enabled=payload.translation_enabled,
        prefer_translated_audio=payload.prefer_translated_audio,
    )
    result = await CallTranslationOrchestrator().process_final_utterance(
        direction=payload.direction,
        source_text=payload.source_text,
        source_lang=payload.source_lang,
        target_lang=payload.target_lang,
        prefs=prefs,
        clone_id=payload.clone_id,
        builtin_voice=payload.builtin_voice,
    )
    import base64

    return {
        "ok": True,
        "bypassed": result.bypassed,
        "direction": result.direction,
        "source_text": result.source_text,
        "translated_text": result.translated_text,
        "detail": result.detail,
        "latency_ms": result.latency_ms,
        "translation_ok": None if result.translation is None else result.translation.ok,
        "translation_provider": None
        if result.translation is None
        else result.translation.provider,
        "warnings": None if result.translation is None else result.translation.warnings,
        "tts_voice": result.tts_voice,
        "audio_base64": None
        if result.tts_bytes is None
        else base64.b64encode(result.tts_bytes).decode("ascii"),
        "production_complete": False,
    }


@router.websocket("/transcription/live")
async def live_transcription_proxy(websocket: WebSocket) -> None:
    """Flutter connects here. Backend holds the ALTA API key as WS subprotocol."""
    await websocket.accept()
    settings = load_alta_settings()
    if not settings.feature_on("live_transcription"):
        await websocket.send_json(
            {
                "type": "error",
                "message": "ALTA live transcription disabled or unconfigured",
            }
        )
        await websocket.close()
        return

    try:
        import websockets
    except ImportError:
        await websocket.send_json(
            {
                "type": "error",
                "message": "Server missing websockets package",
            }
        )
        await websocket.close()
        return

    # Wait for client start (includes consent).
    try:
        raw = await websocket.receive_text()
        start = LiveStartClientMessage.model_validate_json(raw)
    except Exception as exc:  # noqa: BLE001
        await websocket.send_json({"type": "error", "message": f"invalid start: {exc}"})
        await websocket.close()
        return

    if start.cmd != "start":
        await websocket.send_json({"type": "error", "message": "first message must be start"})
        await websocket.close()
        return

    errors = validate_consent_profile(
        consent=bool(start.consent),
        gender=start.gender,
    )
    if errors:
        await websocket.send_json({"type": "profile_required", "errors": errors})
        await websocket.close()
        return

    for warning in validate_live_audio_hint(
        sample_rate=start.sample_rate,
        channels=start.channels,
        encoding=start.audio_encoding,
    ):
        await websocket.send_json({"type": "warning", "message": warning})

    model = start.model or settings.transcription_model
    upstream_url = f"{settings.ws_base}/transcription/live?model={model}"
    start_payload = {
        "cmd": "start",
        "profile": {"consent": True, "gender": start.gender},
        "model": model,
        "diarization": start.diarization,
        "persist": False
        if not settings.live_transcription_persist
        else bool(start.persist),
        "audio": {"encoding": start.audio_encoding},
    }

    try:
        async with websockets.connect(
            upstream_url,
            subprotocols=["altascribe.v2", f"bearer.{settings.api_key}"],
            open_timeout=settings.request_timeout,
            max_size=8 * 1024 * 1024,
        ) as upstream:
            await upstream.send(json.dumps(start_payload))

            async def client_to_upstream() -> None:
                while True:
                    message = await websocket.receive()
                    if message.get("type") == "websocket.disconnect":
                        await upstream.send(json.dumps({"cmd": "stop"}))
                        return
                    if "bytes" in message and message["bytes"] is not None:
                        await upstream.send(message["bytes"])
                    elif "text" in message and message["text"] is not None:
                        await upstream.send(message["text"])

            async def upstream_to_client() -> None:
                async for message in upstream:
                    if isinstance(message, bytes):
                        continue
                    await websocket.send_text(message)

            done, pending = await asyncio.wait(
                [
                    asyncio.create_task(client_to_upstream()),
                    asyncio.create_task(upstream_to_client()),
                ],
                return_when=asyncio.FIRST_COMPLETED,
            )
            for task in pending:
                task.cancel()
            for task in done:
                exc = task.exception()
                if exc and not isinstance(exc, (WebSocketDisconnect, asyncio.CancelledError)):
                    await websocket.send_json({"type": "error", "message": str(exc)})
    except WebSocketDisconnect:
        return
    except Exception as exc:  # noqa: BLE001
        try:
            await websocket.send_json({"type": "error", "message": str(exc)})
        except Exception:
            pass
    finally:
        try:
            await websocket.close()
        except Exception:
            pass
