"""ALTA file + live transcription adapters."""

from __future__ import annotations

import asyncio
import contextlib
import json
from typing import Any, AsyncIterator

from .client import AltaApiError, AltaClient
from .config import load_alta_settings

# Official ALTA docs: female | male | other | prefer_not_to_say
VALID_GENDERS = frozenset({"female", "male", "other", "prefer_not_to_say"})


def validate_consent_profile(*, consent: bool, gender: str | None) -> list[str]:
    errors: list[str] = []
    if not consent:
        errors.append("Explicit consent=true is required before sending audio to ALTA.")
    if not gender or gender not in VALID_GENDERS:
        errors.append(
            "gender must be one of: female, male, other, prefer_not_to_say "
            "(ALTA Transcription docs)."
        )
    return errors


class AltaTranscriptionAdapter:
    def __init__(self, client: AltaClient | None = None):
        self.client = client or AltaClient()
        self.settings = load_alta_settings()

    async def list_models(self) -> Any:
        return await self.client.get_json("/transcription/models")

    async def create_job(
        self,
        *,
        filename: str,
        content: bytes,
        content_type: str,
        consent: bool,
        gender: str,
        model: str | None = None,
        quality: str = "fast",
        age_band: str | None = None,
        region: str | None = None,
        speaker_name: str | None = None,
    ) -> dict[str, Any]:
        errors = validate_consent_profile(consent=consent, gender=gender)
        if errors:
            raise AltaApiError(400, {"detail": errors})
        if not self.settings.feature_on("transcription"):
            raise AltaApiError(503, {"detail": "ALTA transcription disabled"})
        if quality not in {"fast", "accurate"}:
            raise AltaApiError(400, {"detail": "quality must be fast or accurate"})
        data = {
            "consent": "true",
            "gender": gender,
            "model": model or self.settings.transcription_model,
            "quality": quality,
        }
        if age_band:
            data["age_band"] = age_band
        if region:
            data["region"] = region
        if speaker_name:
            data["speaker_name"] = speaker_name
        files = {"file": (filename, content, content_type or "application/octet-stream")}
        result = await self.client.request(
            "POST",
            "/transcription/jobs",
            data=data,
            files=files,
            expect_json=True,
        )
        if not isinstance(result, dict):
            raise AltaApiError(502, {"detail": "Unexpected job response"})
        return result

    async def get_job(self, job_id: str) -> dict[str, Any]:
        result = await self.client.get_json(f"/transcription/jobs/{job_id}")
        if not isinstance(result, dict):
            raise AltaApiError(502, {"detail": "Unexpected job response"})
        return result

    async def poll_job(
        self,
        job_id: str,
        *,
        interval_s: float = 1.0,
        max_wait_s: float = 120.0,
    ) -> dict[str, Any]:
        elapsed = 0.0
        while elapsed <= max_wait_s:
            job = await self.get_job(job_id)
            status = str(job.get("status") or "").lower()
            if status in {"done", "completed", "failed", "error", "expired"}:
                return job
            await asyncio.sleep(interval_s)
            elapsed += interval_s
        raise AltaApiError(504, {"detail": "transcription poll timeout", "job_id": job_id})


async def iter_live_upstream_events(
    *,
    start_payload: dict[str, Any],
    audio_frames: AsyncIterator[bytes],
    model: str = "v2",
) -> AsyncIterator[dict[str, Any] | bytes]:
    """Connect to ALTA live WS. Yields JSON events; binary frames are not expected back.

    Requires the optional ``websockets`` package.
    """
    settings = load_alta_settings()
    if not settings.feature_on("live_transcription"):
        yield {
            "type": "error",
            "message": "ALTA live transcription disabled or unconfigured",
        }
        return

    try:
        import websockets
    except ImportError:
        yield {
            "type": "error",
            "message": "Install websockets package for live transcription proxy",
        }
        return

    url = f"{settings.ws_base}/transcription/live?model={model}"
    subprotocols = ["altascribe.v2", f"bearer.{settings.api_key}"]
    try:
        async with websockets.connect(
            url,
            subprotocols=subprotocols,
            open_timeout=settings.request_timeout,
            max_size=8 * 1024 * 1024,
        ) as ws:
            await ws.send(json.dumps(start_payload))

            async def pump_audio() -> None:
                async for frame in audio_frames:
                    await ws.send(frame)

            audio_task = asyncio.create_task(pump_audio())
            try:
                async for message in ws:
                    if isinstance(message, bytes):
                        continue
                    try:
                        event = json.loads(message)
                    except json.JSONDecodeError:
                        yield {"type": "error", "message": "invalid upstream json"}
                        continue
                    yield event
                    if event.get("type") in {"result", "error"}:
                        break
            finally:
                audio_task.cancel()
                with contextlib.suppress(asyncio.CancelledError):
                    await audio_task
    except Exception as exc:  # noqa: BLE001
        yield {"type": "error", "message": str(exc)}
