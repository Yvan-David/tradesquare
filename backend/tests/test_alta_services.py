import asyncio

import pytest
from fastapi.testclient import TestClient

from app.ai.alta.audio import BYTES_S16_FRAME, validate_live_audio_hint
from app.ai.alta.config import load_alta_settings
from app.ai.alta.orchestrator import CallLanguagePrefs, CallTranslationOrchestrator
from app.ai.alta.transcription import validate_consent_profile
from app.ai.alta.translation import (
    AltaTranslationProvider,
    TranslationProviderRegistry,
)
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_consent_profile_validation():
    assert validate_consent_profile(consent=False, gender="prefer_not_to_say")
    assert validate_consent_profile(consent=True, gender=None)
    assert validate_consent_profile(consent=True, gender="prefer_not_to_say") == []
    # Official ALTA genders only — non_binary is not accepted
    assert validate_consent_profile(consent=True, gender="non_binary")
    assert validate_consent_profile(consent=True, gender="other") == []


def test_audio_format_warnings():
    from app.ai.alta.audio import BYTES_F32_FRAME, MAX_FRAME_BYTES

    warnings = validate_live_audio_hint(
        sample_rate=48000,
        channels=2,
        encoding="opus",
    )
    assert any("48000" in w for w in warnings)
    assert any("mono" in w for w in warnings)
    assert BYTES_S16_FRAME == 1600
    assert BYTES_F32_FRAME == 3200
    assert MAX_FRAME_BYTES == 4194304
    assert validate_live_audio_hint(
        sample_rate=16000, channels=1, encoding="pcm_f32le"
    ) == []


def test_swahili_not_supported_by_alta_provider():
    provider = AltaTranslationProvider()
    assert provider.supports("rw", "en") is True
    assert provider.supports("sw", "rw") is False


def test_registry_routes_swahili_to_external_unavailable():
    registry = TranslationProviderRegistry()
    result = asyncio.run(registry.translate("Habari", target="rw", source="sw"))
    assert result.ok is False
    assert result.provider == "swahili_external"
    assert "unsupported_language" in result.warnings


def test_orchestrator_same_language_bypass(monkeypatch):
    monkeypatch.setenv("ALTA_ENABLED", "true")
    monkeypatch.setenv("ALTA_CALL_TRANSLATION_ENABLED", "true")
    orch = CallTranslationOrchestrator()
    prefs = CallLanguagePrefs(local_language="rw", remote_language="rw")
    assert orch.should_bypass(prefs) is True
    turn = asyncio.run(
        orch.process_final_utterance(
            direction="a_to_b",
            source_text="Muraho",
            source_lang="rw",
            target_lang="rw",
            prefs=prefs,
        )
    )
    assert turn.bypassed is True


def test_alta_status_route(client, monkeypatch):
    monkeypatch.delenv("ALTA_API_KEY", raising=False)
    monkeypatch.setenv("ALTA_ENABLED", "false")
    response = client.get("/api/v1/alta/status")
    assert response.status_code == 200
    body = response.json()
    assert body["ok"] is True
    assert body["privacy"]["api_key_on_client"] is False
    assert body["capabilities"]["matrix"]["translation_swahili"]["available"] is False


def test_alta_languages_route(client):
    response = client.get("/api/v1/alta/languages")
    assert response.status_code == 200
    body = response.json()
    assert body["translation_alta"] == ["rw", "en", "fr"]
    assert body["translation_swahili"]["supported_by_alta"] is False
    assert "sw" in body["tts"]


def test_settings_loader_defaults(monkeypatch):
    monkeypatch.delenv("ALTA_API_KEY", raising=False)
    monkeypatch.setenv("ALTA_ENABLED", "false")
    settings = load_alta_settings()
    assert settings.configured is False
    assert settings.live_transcription_persist is False
    assert settings.feature_on("tts") is False
