"""Hosted Alta Console TTS client (YaliLabs).

Separate from local ``altatts`` package weights and from KinyaFlex / device TTS.
Reads ``ALTA_API_KEY`` / ``ALTA_BASE_URL`` from the environment. Never hardcode
secrets. Keep ``ENABLE_ALTA_CONSOLE_TTS=0`` until evaluation passes and product
approves production use on LiveKit call paths.
"""

from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass
from typing import Any, Iterator


DEFAULT_BASE_URL = "https://alta.yalilabs.com/v1"


@dataclass(frozen=True)
class AdapterStatus:
    available: bool
    name: str
    detail: str


@dataclass(frozen=True)
class AltaTtsResult:
    audio: bytes
    content_type: str
    headers: dict[str, str]
    latency_ms_client: float
    latency_ms_service: float | None
    audio_seconds: float | None
    voice: str | None
    language: str | None
    sample_rate: int | None
    cache: str | None


class AltaConsoleTtsAdapter:
    """HTTP client for Alta Console ``/synthesis/*`` endpoints."""

    NAME = "Alta Console TTS"

    def __init__(self) -> None:
        self.base_url = (
            os.getenv("ALTA_BASE_URL", DEFAULT_BASE_URL).strip().rstrip("/")
            or DEFAULT_BASE_URL
        )
        self.api_key = os.getenv("ALTA_API_KEY", "").strip()
        self.enabled = os.getenv("ENABLE_ALTA_CONSOLE_TTS", "").strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    def status(self) -> AdapterStatus:
        if not self.configured:
            return AdapterStatus(
                available=False,
                name=self.NAME,
                detail=(
                    "ALTA_API_KEY is unset. Create a key at "
                    "https://alta.yalilabs.com/settings/api-keys with "
                    "speech:synthesize scope."
                ),
            )
        if not self.enabled:
            return AdapterStatus(
                available=False,
                name=self.NAME,
                detail=(
                    "ALTA_API_KEY is present, but ENABLE_ALTA_CONSOLE_TTS is off. "
                    "Evaluation scripts may call the API; production LiveKit calls "
                    "must stay on existing TTS paths until approved."
                ),
            )
        return AdapterStatus(
            available=True,
            name=self.NAME,
            detail=(
                f"Hosted Alta Console configured at {self.base_url}. "
                "Keep media (LiveKit) separate from synthesis control plane."
            ),
        )

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "Accept": "*/*",
        }

    def auth_me(self) -> dict[str, Any]:
        import httpx

        with httpx.Client(timeout=30.0) as client:
            response = client.get(f"{self.base_url}/auth/me", headers=self._headers())
            response.raise_for_status()
            return response.json()

    def list_voices(self) -> dict[str, Any]:
        import httpx

        with httpx.Client(timeout=30.0) as client:
            response = client.get(
                f"{self.base_url}/synthesis/voices",
                headers=self._headers(),
            )
            response.raise_for_status()
            return response.json()

    def synthesize(
        self,
        text: str,
        *,
        voice: str = "keza",
        language: str | None = None,
        sample_rate: int = 22050,
        format: str = "wav",
        emotion: str | None = None,
        intensity: float | None = None,
        readable: bool = False,
    ) -> AltaTtsResult:
        import httpx

        body: dict[str, Any] = {
            "text": text,
            "voice": voice,
            "sample_rate": sample_rate,
            "format": format,
        }
        if language:
            body["language"] = language
        if emotion:
            body["emotion"] = emotion
        if intensity is not None:
            body["intensity"] = intensity
        if readable:
            body["readable"] = True

        t0 = time.perf_counter()
        with httpx.Client(timeout=90.0) as client:
            response = client.post(
                f"{self.base_url}/synthesis/tts",
                headers=self._headers(),
                json=body,
            )
        client_ms = (time.perf_counter() - t0) * 1000
        if response.status_code >= 400:
            raise RuntimeError(
                f"Alta TTS HTTP {response.status_code}: {response.text[:500]}"
            )

        headers = {k.lower(): v for k, v in response.headers.items()}

        def _float(name: str) -> float | None:
            raw = headers.get(name)
            try:
                return float(raw) if raw is not None else None
            except ValueError:
                return None

        def _int(name: str) -> int | None:
            raw = headers.get(name)
            try:
                return int(float(raw)) if raw is not None else None
            except ValueError:
                return None

        return AltaTtsResult(
            audio=response.content,
            content_type=headers.get("content-type", "application/octet-stream"),
            headers=headers,
            latency_ms_client=round(client_ms, 2),
            latency_ms_service=_float("x-alta-latency-ms"),
            audio_seconds=_float("x-alta-audio-seconds"),
            voice=headers.get("x-alta-voice"),
            language=headers.get("x-alta-language"),
            sample_rate=_int("x-alta-sample-rate"),
            cache=headers.get("x-alta-cache"),
        )

    def synthesize_stream(
        self,
        text: str,
        *,
        voice: str = "keza",
        language: str | None = None,
        sample_rate: int = 16000,
    ) -> dict[str, Any]:
        """Phrase/sentence SSE stream. Returns timings + chunk metadata (no invented values)."""
        import base64
        import httpx

        body: dict[str, Any] = {
            "text": text,
            "voice": voice,
            "sample_rate": sample_rate,
            "format": "pcm16",
        }
        if language:
            body["language"] = language

        chunks: list[dict[str, Any]] = []
        done: dict[str, Any] | None = None
        t0 = time.perf_counter()
        first_byte_ms: float | None = None

        with httpx.Client(timeout=90.0) as client:
            with client.stream(
                "POST",
                f"{self.base_url}/synthesis/tts/stream",
                headers=self._headers(),
                json=body,
            ) as response:
                if response.status_code >= 400:
                    detail = response.read().decode("utf-8", errors="replace")[:500]
                    raise RuntimeError(f"Alta stream HTTP {response.status_code}: {detail}")

                event_name = "message"
                data_lines: list[str] = []
                for line in response.iter_lines():
                    if first_byte_ms is None:
                        first_byte_ms = (time.perf_counter() - t0) * 1000
                    if line is None:
                        continue
                    if line.startswith(":"):
                        continue
                    if line.startswith("event:"):
                        event_name = line[6:].strip()
                        continue
                    if line.startswith("data:"):
                        data_lines.append(line[5:].strip())
                        continue
                    if line == "" and data_lines:
                        payload = json.loads("\n".join(data_lines))
                        data_lines = []
                        if event_name == "chunk":
                            audio_b64 = payload.get("base64") or ""
                            chunks.append(
                                {
                                    "index": payload.get("index"),
                                    "text": payload.get("text"),
                                    "duration_s": payload.get("duration_s"),
                                    "sample_rate": payload.get("sample_rate"),
                                    "bytes": len(base64.b64decode(audio_b64))
                                    if audio_b64
                                    else 0,
                                }
                            )
                        elif event_name == "done":
                            done = payload
                        elif event_name == "error":
                            raise RuntimeError(f"Alta stream error: {payload}")
                        event_name = "message"

        return {
            "client_first_byte_ms": None
            if first_byte_ms is None
            else round(first_byte_ms, 2),
            "client_total_ms": round((time.perf_counter() - t0) * 1000, 2),
            "service_done": done,
            "chunks": chunks,
            "chunk_count": len(chunks),
        }

    def capabilities_probe(self) -> dict[str, Any]:
        status = self.status()
        return {
            "available": status.available,
            "configured": self.configured,
            "enabled_for_calls": self.enabled,
            "production_wired": False,
            "name": status.name,
            "detail": status.detail,
            "base_url": self.base_url,
            "key_present": self.configured,
            "key_prefix": (self.api_key[:10] + "…") if self.configured else None,
        }
