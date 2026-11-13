"""Modular LLM adapter for Discover conversational intelligence.

Default mode is a local heuristic router. Optional remote providers can be
enabled with environment variables. This module never invents business records.
"""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class LlmTurn:
    reply: str
    language: str
    intent: str
    mode: str
    note: str


class LocalHeuristicLlmAdapter:
    """Fast, offline intent helper used when no remote LLM is configured."""

    def status(self) -> dict:
        return {
            "available": True,
            "name": "local_heuristic_llm",
            "detail": (
                "Local multilingual intent routing and concise replies. "
                "Not a generative foundation model."
            ),
        }

    def complete(
        self,
        message: str,
        *,
        locale: str | None = None,
        history: list[dict] | None = None,
    ) -> LlmTurn:
        text = message.strip()
        lower = text.lower()
        history = history or []

        if any(token in lower for token in ("ndashaka", "abaguzi", "muri ", "ubucuruzi")):
            language = "rw"
        elif any(token in lower for token in ("nataka", "tafuta", "wanunuzi", "biashara")):
            language = "sw"
        elif any(token in lower for token in ("trouver", "acheter", "fournisseur", "bonjour")):
            language = "fr"
        else:
            language = (locale or "en").split("-")[0]

        follow_up = bool(history) and (
            lower.startswith(("and ", "also ", "what about", "kandi ", "na ", "et ", "aussi "))
            or len(lower) < 28
        )

        if any(token in lower for token in ("message", "ubutumwa", "ujumbe")):
            intent = "open_messages"
            reply = {
                "en": "Opening Messages.",
                "rw": "Ndagufungurira ubutumwa.",
                "sw": "Nafungua ujumbe.",
                "fr": "J’ouvre Messages.",
            }.get(language, "Opening Messages.")
        elif any(token in lower for token in ("my business", "umwirondoro", "profil")):
            intent = "open_business_profile"
            reply = {
                "en": "Opening your business profile.",
                "rw": "Ndagufungurira umwirondoro w’ubucuruzi bwawe.",
                "sw": "Nafungua wasifu wa biashara yako.",
                "fr": "J’ouvre le profil de votre entreprise.",
            }.get(language, "Opening your business profile.")
        elif follow_up:
            intent = "follow_up_search"
            reply = {
                "en": "Got it — I’ll refine that with your previous request.",
                "rw": "Byumvikanye — nzongera gushakisha hashingiye ku kibazo cyabanje.",
                "sw": "Sawa — nitaboresha kwa ombi lako la awali.",
                "fr": "Compris — je vais affiner avec votre demande précédente.",
            }.get(language, "Got it — I’ll refine that with your previous request.")
        else:
            intent = "search_businesses"
            reply = {
                "en": "I’ll search TradeSquare records for that.",
                "rw": "Ndashakisha mu makuru ya TradeSquare.",
                "sw": "Nitafuta katika rekodi za TradeSquare.",
                "fr": "Je vais chercher dans les enregistrements TradeSquare.",
            }.get(language, "I’ll search TradeSquare records for that.")

        return LlmTurn(
            reply=reply,
            language=language,
            intent=intent,
            mode="local_heuristic",
            note=self.status()["detail"],
        )


class OptionalRemoteLlmAdapter:
    """Boundary for a remote LLM endpoint.

    Set DISCOVER_LLM_URL to enable. Without it, this adapter reports unavailable
    and must not be treated as a live generative brain.
    """

    def __init__(self) -> None:
        self.url = os.getenv("DISCOVER_LLM_URL", "").strip()
        self.api_key = os.getenv("DISCOVER_LLM_API_KEY", "").strip()

    def status(self) -> dict:
        if not self.url:
            return {
                "available": False,
                "name": "remote_llm",
                "detail": (
                    "DISCOVER_LLM_URL is not set. Optional remote LLM remains disabled."
                ),
            }
        return {
            "available": True,
            "name": "remote_llm",
            "detail": f"Remote LLM endpoint configured at {self.url}.",
        }

    def complete(
        self,
        message: str,
        *,
        locale: str | None = None,
        history: list[dict] | None = None,
    ) -> LlmTurn:
        status = self.status()
        if not status["available"]:
            raise RuntimeError(status["detail"])
        # Networked completion is intentionally not implemented without an
        # approved provider. Refuse rather than fabricating model output.
        raise RuntimeError(
            "Remote LLM URL is set, but no approved provider client is wired yet. "
            "Use the local heuristic adapter or connect an approved model gateway."
        )


def get_llm_adapter() -> LocalHeuristicLlmAdapter | OptionalRemoteLlmAdapter:
    remote = OptionalRemoteLlmAdapter()
    if remote.status()["available"]:
        # Prefer local until a provider client is approved/wired.
        return LocalHeuristicLlmAdapter()
    return LocalHeuristicLlmAdapter()
