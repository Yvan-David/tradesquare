from app.ai.altatts_adapter import AltaTtsCallAdapter


def test_altatts_adapter_is_unavailable_without_model(monkeypatch):
    monkeypatch.delenv("ALTATTS_MODEL_PATH", raising=False)
    monkeypatch.delenv("ENABLE_ALTATTS_CALLS", raising=False)
    status = AltaTtsCallAdapter().status()
    assert status.available is False
    assert "ALTATTS" in status.name


def test_altatts_capabilities_probe_marks_not_production(monkeypatch):
    monkeypatch.delenv("ALTATTS_MODEL_PATH", raising=False)
    probe = AltaTtsCallAdapter().capabilities_probe()
    assert probe["production_wired"] is False
    assert probe["weights_bundled_in_pypi"] is False
    assert probe["voice_cloning_api"]["reference_audio"] is True
    assert probe["streaming_api"]["native_frame_streaming"] is False
