from app.ai.alta_console_tts import AltaConsoleTtsAdapter


def test_alta_console_unavailable_without_key(monkeypatch):
    monkeypatch.delenv("ALTA_API_KEY", raising=False)
    monkeypatch.delenv("ENABLE_ALTA_CONSOLE_TTS", raising=False)
    status = AltaConsoleTtsAdapter().status()
    assert status.available is False
    assert "ALTA_API_KEY" in status.detail


def test_alta_console_configured_but_disabled(monkeypatch):
    monkeypatch.setenv("ALTA_API_KEY", "ak_test.example")
    monkeypatch.setenv("ENABLE_ALTA_CONSOLE_TTS", "0")
    adapter = AltaConsoleTtsAdapter()
    assert adapter.configured is True
    assert adapter.status().available is False
    probe = adapter.capabilities_probe()
    assert probe["production_wired"] is False
    assert probe["key_prefix"] == "ak_test.ex…"
