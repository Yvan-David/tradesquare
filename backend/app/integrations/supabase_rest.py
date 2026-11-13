"""Supabase PostgREST client — used when DATABASE_URL is unset."""

from __future__ import annotations

import os
from functools import lru_cache
from types import SimpleNamespace
from typing import Any

import httpx


class SupabaseRestError(RuntimeError):
    pass


@lru_cache
def load_supabase_rest_settings() -> tuple[str, str]:
    url = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
    key = (
        os.environ.get("SUPABASE_ANON_KEY", "").strip()
        or os.environ.get("SUPABASE_PUBLISHABLE_KEY", "").strip()
    )
    if not url or not key:
        raise SupabaseRestError(
            "Set SUPABASE_URL and SUPABASE_ANON_KEY (publishable key) in .env"
        )
    return url, key


def supabase_rest_configured() -> bool:
    try:
        load_supabase_rest_settings()
        return True
    except SupabaseRestError:
        return False


def _headers() -> dict[str, str]:
    _, key = load_supabase_rest_settings()
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Accept": "application/json",
    }


def rest_get(table: str, *, params: dict[str, str] | None = None) -> list[dict[str, Any]]:
    base, _ = load_supabase_rest_settings()
    with httpx.Client(timeout=60.0) as client:
        response = client.get(
            f"{base}/rest/v1/{table}",
            headers=_headers(),
            params=params or {"select": "*"},
        )
    if response.status_code >= 400:
        raise SupabaseRestError(
            f"Supabase REST {table} HTTP {response.status_code}: {response.text[:400]}"
        )
    data = response.json()
    if not isinstance(data, list):
        raise SupabaseRestError(f"Unexpected response for {table}")
    return data


def as_row(data: dict[str, Any]) -> SimpleNamespace:
    return SimpleNamespace(**data)


def as_rows(items: list[dict[str, Any]]) -> list[SimpleNamespace]:
    return [as_row(item) for item in items]
