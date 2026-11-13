"""Translation providers — ALTA for rw/en/fr; Swahili requires a separate provider."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol

from .client import AltaApiError, AltaClient
from .config import load_alta_settings


ALTA_TRANSLATION_LANGS = frozenset({"rw", "en", "fr"})


@dataclass(frozen=True)
class TranslationResult:
    text: str
    source: str | None
    target: str
    provider: str
    ok: bool
    warnings: list[str] = field(default_factory=list)
    raw: dict[str, Any] | None = None
    detail: str | None = None


class TranslationProvider(Protocol):
    name: str

    def supports(self, source: str | None, target: str) -> bool: ...

    async def translate(
        self,
        text: str,
        *,
        target: str,
        source: str = "auto",
        **kwargs: Any,
    ) -> TranslationResult: ...


class AltaTranslationProvider:
    name = "alta"

    def __init__(self, client: AltaClient | None = None):
        self.client = client or AltaClient()

    def supports(self, source: str | None, target: str) -> bool:
        target_n = (target or "").lower()
        if target_n not in ALTA_TRANSLATION_LANGS:
            return False
        if source in (None, "", "auto"):
            return True
        return source.lower() in ALTA_TRANSLATION_LANGS

    async def translate(
        self,
        text: str,
        *,
        target: str,
        source: str = "auto",
        quality: bool = True,
        sentence_level: bool = True,
        source_hint: str | None = None,
        preserve_lines: bool = True,
        on_unsupported: str = "error",
    ) -> TranslationResult:
        settings = load_alta_settings()
        if not settings.feature_on("translation"):
            return TranslationResult(
                text="",
                source=source,
                target=target,
                provider=self.name,
                ok=False,
                detail="ALTA translation disabled or not configured.",
            )
        target_n = target.lower()
        source_n = (source or "auto").lower()
        if target_n not in ALTA_TRANSLATION_LANGS:
            return TranslationResult(
                text="",
                source=source_n,
                target=target_n,
                provider=self.name,
                ok=False,
                detail=(
                    "ALTA translation target must be rw, en or fr. "
                    "Swahili is unsupported by Alta Translator."
                ),
                warnings=["unsupported_language"],
            )
        if source_n == "sw":
            return TranslationResult(
                text="",
                source=source_n,
                target=target_n,
                provider=self.name,
                ok=False,
                detail=(
                    "ALTA translation does not support Swahili source. "
                    "Route via SwahiliTranslationProvider when configured."
                ),
                warnings=["unsupported_language"],
            )
        payload: dict[str, Any] = {
            "text": text,
            "target": target_n,
            "source": source_n,
            "quality": quality,
            "sentence_level": sentence_level,
            "preserve_lines": preserve_lines,
            "on_unsupported": on_unsupported
            if on_unsupported in {"error", "copy"}
            else "error",
        }
        if source_hint in ALTA_TRANSLATION_LANGS:
            payload["source_hint"] = source_hint
        try:
            raw = await self.client.post_json("/translation/translate", payload)
        except AltaApiError as exc:
            return TranslationResult(
                text="",
                source=source_n,
                target=target_n,
                provider=self.name,
                ok=False,
                detail=str(exc),
                raw={"status_code": exc.status_code, "body": exc.body},
            )
        translated = (
            raw.get("translation")
            or raw.get("translated_text")
            or raw.get("text")
            or ""
        )
        warnings = list(raw.get("warnings") or [])
        return TranslationResult(
            text=str(translated),
            source=str(raw.get("source") or source_n),
            target=target_n,
            provider=self.name,
            ok=bool(translated),
            warnings=[str(w) for w in warnings],
            raw=raw if isinstance(raw, dict) else None,
        )

    async def detect(self, text: str) -> dict[str, Any]:
        return await self.client.post_json("/translation/detect", {"text": text})

    async def languages(self) -> dict[str, Any]:
        return await self.client.get_json("/translation/languages")

    async def translate_batch(
        self,
        items: list[dict[str, Any]],
        *,
        mode: str = "quality",
    ) -> dict[str, Any]:
        """POST /translation/translate/batch — up to 256 items (hosted chunk 64)."""
        settings = load_alta_settings()
        if not settings.feature_on("translation"):
            raise AltaApiError(503, {"detail": "ALTA translation disabled"})
        return await self.client.post_json(
            "/translation/translate/batch",
            {"items": items, "mode": mode if mode in {"quality", "draft"} else "quality"},
        )


class SwahiliTranslationProvider:
    """Placeholder — no invented Swahili MT. Configure CALL_LIBRETRANSLATE_URL later."""

    name = "swahili_external"

    def supports(self, source: str | None, target: str) -> bool:
        pair = {(source or "").lower(), (target or "").lower()}
        return "sw" in pair

    async def translate(
        self,
        text: str,
        *,
        target: str,
        source: str = "auto",
        **kwargs: Any,
    ) -> TranslationResult:
        return TranslationResult(
            text="",
            source=source,
            target=target,
            provider=self.name,
            ok=False,
            detail=(
                "No Swahili-capable translation worker is configured. "
                "Do not treat copied Swahili as a translation. "
                "Set a tested provider (e.g. LibreTranslate with sw models) later."
            ),
            warnings=["unsupported_language"],
        )


class TranslationProviderRegistry:
    def __init__(self, providers: list[TranslationProvider] | None = None):
        self.providers = providers or [
            AltaTranslationProvider(),
            SwahiliTranslationProvider(),
        ]

    def resolve(self, source: str | None, target: str) -> TranslationProvider | None:
        for provider in self.providers:
            if provider.supports(source, target):
                # Prefer external SW provider for any pair involving sw.
                if "sw" in {(source or "").lower(), target.lower()}:
                    if provider.name == "swahili_external":
                        return provider
                    continue
                return provider
        for provider in self.providers:
            if provider.supports(source, target):
                return provider
        return None

    async def translate(
        self,
        text: str,
        *,
        target: str,
        source: str = "auto",
        **kwargs: Any,
    ) -> TranslationResult:
        provider = self.resolve(source, target)
        if provider is None:
            return TranslationResult(
                text="",
                source=source,
                target=target,
                provider="none",
                ok=False,
                detail=f"No translation provider for {source}->{target}",
                warnings=["unsupported_language"],
            )
        return await provider.translate(text, target=target, source=source, **kwargs)
