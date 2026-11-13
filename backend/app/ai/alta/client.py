"""Authenticated HTTP client for Alta Console. Never logs the API key."""

from __future__ import annotations

from typing import Any

import httpx

from .config import AltaSettings, load_alta_settings


class AltaApiError(RuntimeError):
    def __init__(self, status_code: int, body: Any, message: str | None = None):
        self.status_code = status_code
        self.body = body
        super().__init__(message or f"Alta API HTTP {status_code}")


class AltaClient:
    def __init__(self, settings: AltaSettings | None = None):
        self.settings = settings or load_alta_settings()

    @property
    def configured(self) -> bool:
        return self.settings.configured

    def _headers(self, *, json_body: bool = True) -> dict[str, str]:
        headers = {
            "Authorization": f"Bearer {self.settings.api_key}",
            "Accept": "application/json",
        }
        if json_body:
            headers["Content-Type"] = "application/json"
        return headers

    async def request(
        self,
        method: str,
        path: str,
        *,
        json: dict[str, Any] | None = None,
        data: dict[str, Any] | None = None,
        files: Any = None,
        params: dict[str, Any] | None = None,
        expect_json: bool = True,
    ) -> Any:
        if not self.settings.configured:
            raise AltaApiError(503, {"detail": "ALTA_API_KEY unset"}, "ALTA not configured")
        url = f"{self.settings.http_base}{path if path.startswith('/') else '/' + path}"
        timeout = httpx.Timeout(self.settings.request_timeout)
        async with httpx.AsyncClient(timeout=timeout) as client:
            kwargs: dict[str, Any] = {"params": params}
            if files is not None:
                kwargs["headers"] = self._headers(json_body=False)
                kwargs["data"] = data
                kwargs["files"] = files
            else:
                kwargs["headers"] = self._headers(json_body=json is not None)
                if json is not None:
                    kwargs["json"] = json
                elif data is not None:
                    kwargs["data"] = data
            response = await client.request(method, url, **kwargs)
        if response.status_code >= 400:
            try:
                body: Any = response.json()
            except Exception:
                body = {"raw": response.text[:500]}
            raise AltaApiError(response.status_code, body)
        if response.status_code == 204 or not response.content:
            return None
        if expect_json and "application/json" in response.headers.get("content-type", ""):
            return response.json()
        return response.content

    async def get_json(self, path: str, **kwargs: Any) -> Any:
        return await self.request("GET", path, expect_json=True, **kwargs)

    async def post_json(self, path: str, payload: dict[str, Any], **kwargs: Any) -> Any:
        return await self.request("POST", path, json=payload, expect_json=True, **kwargs)
