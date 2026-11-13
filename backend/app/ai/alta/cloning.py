"""ALTA voice cloning — consent-gated, user-scoped metadata only on our side."""

from __future__ import annotations

from typing import Any

from .client import AltaApiError, AltaClient
from .config import load_alta_settings


class AltaVoiceCloningAdapter:
    def __init__(self, client: AltaClient | None = None):
        self.client = client or AltaClient()
        self.settings = load_alta_settings()

    def _require_enabled(self) -> None:
        if not self.settings.feature_on("voice_cloning"):
            raise AltaApiError(
                503,
                {
                    "detail": (
                        "Voice cloning disabled. Set ALTA_ENABLED=1 and "
                        "ALTA_VOICE_CLONING_ENABLED=1 after consent UX is live."
                    )
                },
            )

    async def list_voices(self) -> Any:
        self._require_enabled()
        return await self.client.get_json("/cloning/voices")

    async def get_voice(self, clone_id: str) -> Any:
        self._require_enabled()
        return await self.client.get_json(f"/cloning/voices/{clone_id}")

    async def create_voice(
        self,
        *,
        files: list[tuple[str, bytes, str]],
        name: str,
        language: str | None,
        consent_voice_ownership: bool,
        consent_external_processing: bool,
    ) -> Any:
        self._require_enabled()
        if not consent_voice_ownership or not consent_external_processing:
            raise AltaApiError(
                400,
                {
                    "detail": (
                        "Voice cloning requires explicit ownership permission and "
                        "external-processing consent."
                    )
                },
            )
        if not files:
            raise AltaApiError(400, {"detail": "At least one reference audio file is required."})
        if len(files) > 6:
            raise AltaApiError(400, {"detail": "ALTA accepts at most 6 reference files."})
        total = sum(len(content) for _, content, _ in files)
        if total > 25 * 1024 * 1024:
            raise AltaApiError(413, {"detail": "Reference audio exceeds 25 MB total."})

        form: dict[str, Any] = {"name": name}
        if language:
            form["language"] = language
        upload = [
            ("audio", (filename, content, content_type))
            for filename, content, content_type in files
        ]
        # Some gateways expect repeated 'audio' fields; httpx files list supports that.
        return await self.client.request(
            "POST",
            "/cloning/voices",
            data=form,
            files=upload,
            expect_json=True,
        )

    async def patch_voice(self, clone_id: str, *, name: str | None = None) -> Any:
        self._require_enabled()
        payload: dict[str, Any] = {}
        if name is not None:
            payload["name"] = name
        return await self.client.request(
            "PATCH",
            f"/cloning/voices/{clone_id}",
            json=payload,
            expect_json=True,
        )

    async def delete_voice(self, clone_id: str) -> Any:
        self._require_enabled()
        return await self.client.request(
            "DELETE",
            f"/cloning/voices/{clone_id}",
            expect_json=True,
        )

    async def speak(
        self,
        clone_id: str,
        *,
        text: str,
        language: str | None = None,
        sample_rate: int = 22050,
        format: str = "wav",
        emotion: str | None = None,
        speed: float | None = None,
    ) -> bytes:
        self._require_enabled()
        payload: dict[str, Any] = {
            "text": text,
            "sample_rate": sample_rate,
            "format": format,
        }
        if language:
            payload["language"] = language
        if emotion:
            payload["emotion"] = emotion
        if speed is not None:
            payload["speed"] = speed
        result = await self.client.request(
            "POST",
            f"/cloning/voices/{clone_id}/speak",
            json=payload,
            expect_json=False,
        )
        if not isinstance(result, (bytes, bytearray)):
            raise AltaApiError(502, {"detail": "Expected audio bytes from clone speak"})
        return bytes(result)
