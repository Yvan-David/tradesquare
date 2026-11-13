"""Torch-free config behaviour + metadata reading (torch needed only for the
dataset class, skipped when absent)."""
import json

import pytest

from altatts.config import Config, load_config, preset
from altatts.training.data import normalize_age, normalize_gender, read_metadata


def test_presets_validate_and_roundtrip(tmp_path):
    for name in ("small", "base", "large"):
        cfg = preset(name)
        assert cfg.model.version == 2 and cfg.prior.type == "meanflow"
        cfg.save(str(tmp_path / f"{name}.json"))
        back = load_config(str(tmp_path / f"{name}.json"))
        assert back.to_dict() == cfg.to_dict()


def test_legacy_config_detected(tmp_path):
    d = preset("base").to_dict()
    del d["model"]["version"]
    for k in ("style", "prior", "privacy"):
        del d[k]
    (tmp_path / "c.json").write_text(json.dumps(d))
    cfg = load_config(str(tmp_path / "c.json"))
    assert cfg.is_legacy and cfg.prior.type == "flow"
    assert cfg.style.speaker_encoder == "none" and cfg.style.expose_training_speakers
    assert "v1" in cfg.summary()


def test_validation_errors():
    cfg = preset("base")
    cfg.text.languages = ["zz"]
    with pytest.raises(ValueError):
        cfg.validate()
    cfg = preset("base")
    cfg.model.version = 1
    with pytest.raises(ValueError):          # legacy has no meanflow
        cfg.validate()
    cfg = preset("base")
    cfg.style.emotions = ["happy"]
    cfg.validate()
    assert cfg.style.emotions[0] == "neutral"   # neutral is always present


def test_metadata_aliases(tmp_path):
    rows = [
        {"audio_path": "a.wav", "transcription": "muraho", "client_id": "s1", "sex": "F",
         "age": "twenties", "emotion_label": "Joy", "arousal": 70, "locale": "rw-RW",
         "silences": [{"offset": 3, "duration": 0.4}]},
        {"path": "b.mp3", "sentence": "hello", "speaker": "s2", "gender": "male_masculine",
         "age_group": "45+", "style": "angry", "intensity": 0.3, "lang": "en"},
        {"audio": "c.flac", "text": "bonjour", "duration": "2.5"},
    ]
    p = tmp_path / "m.jsonl"
    p.write_text("\n".join(json.dumps(r) for r in rows))
    recs = read_metadata(str(p))
    assert len(recs) == 3
    r0, r1, r2 = recs
    assert r0["speaker"] == "s1" and r0["gender"] == "female" and r0["age_group"] == "16-25"
    assert r0["emotion"] == "joy" and abs(r0["intensity"] - 0.7) < 1e-9 and r0["pauses"]
    assert r1["gender"] == "male" and r1["age_group"] == "45+" and r1["emotion"] == "angry"
    assert r1["intensity"] == 0.3 and r1["language"] == "en"
    assert r2["duration"] == 2.5 and "speaker" not in r2
    # CSV too
    c = tmp_path / "m.csv"
    c.write_text("id,audio_path,text,speaker,gender\nx,a.wav,muraho,s1,gabo\n")
    assert read_metadata(str(c))[0]["gender"] == "male"


def test_gender_and_age_normalizers():
    assert normalize_gender("female_feminine") == "female" and normalize_gender("gore") == "female"
    assert normalize_gender("non-binary") == "other" and normalize_gender(None) == "other"
    assert normalize_age(23) == "16-25" and normalize_age("thirties") == "25-45"
    assert normalize_age("fifties") == "45+" and normalize_age("?") is None


def test_load_records_emotion_language_pauses(tmp_path):
    pytest.importorskip("torch")
    from altatts.training.data import load_records
    cfg = preset("small")
    cfg.text.languages = ["rw", "en"]
    rows = [{"audio_path": "a.wav", "text": "muraho neza amakuru", "speaker": "s", "duration": 2.0,
             "emotion": "happy", "pauses": [{"word": 0, "duration": 0.3}]},
            {"audio_path": "b.wav", "text": "[sad:0.4] ndababaye", "speaker": "s", "duration": 2.0},
            {"audio_path": "c.wav", "text": "hello there", "speaker": "s", "duration": 2.0, "language": "en"},
            {"audio_path": "d.wav", "text": "too long" * 500, "speaker": "s", "duration": 2.0},
            {"audio_path": "e.wav", "text": "x", "speaker": "s", "duration": 99.0}]
    p = tmp_path / "m.json"
    p.write_text(json.dumps(rows))
    recs = load_records([str(p)], cfg)
    assert [r["audio_path"] for r in recs] == ["a.wav", "b.wav", "c.wav"]
    assert recs[0]["norm_text"] == "muraho [pause:0.3] neza amakuru"
    assert recs[0]["emotion_id"] == cfg.style.emotions.index("happy") + 1
    assert recs[1]["emotion_id"] == cfg.style.emotions.index("sad") + 1 and recs[1]["intensity"] == 0.4
    assert recs[2]["language"] == "en" and recs[0]["language"] == "rw"
