"""Voice plan (privacy groups) -- pure logic, no model."""
from altatts.config import preset
from altatts.languages import canonical_code, is_mixed_code
from altatts.training.anonymize import assign_speakers, plan_voice_groups, voice_name
from altatts.training.data import SpeakerRegistry


def test_auto_plan_four_languages_gives_12_voices():
    cfg = preset("base")
    cfg.text.languages = ["rw", "en", "fr", "sw"]
    cfg.validate()
    groups = plan_voice_groups(cfg)
    assert [g.name for g in groups] == ["french", "english", "bantu"]
    assert sum(g.n_voices() for g in groups) == 12
    assert all(g.n_female == 2 and g.n_male == 2 for g in groups)
    bantu = groups[-1]
    assert bantu.languages == ["rw", "sw"] and bantu.cross_lingual


def test_auto_plan_single_language():
    groups = plan_voice_groups(preset("base"))
    assert len(groups) == 1 and groups[0].name == "bantu"
    assert groups[0].n_female == 3 and groups[0].n_male == 3


def test_custom_plan_and_iso3_codes():
    cfg = preset("base")
    cfg.text.languages = ["rw", "en", "fr", "sw"]
    cfg.privacy.plan = "custom"
    cfg.privacy.groups = [{"name": "europe", "languages": ["fra", "eng"], "n_female": 1, "n_male": 1},
                          {"name": "bantu", "languages": ["kin", "swa"]}]
    cfg.validate()
    groups = plan_voice_groups(cfg)
    assert groups[0].languages == ["fr", "en"] and groups[0].n_voices() == 2
    assert groups[1].cross_lingual and groups[1].n_voices() == 4
    assert canonical_code("kin") == "rw" and canonical_code("eng") == "en"
    assert canonical_code("fra") == "fr" and canonical_code("swa") == "sw"
    assert is_mixed_code("code-switch") and canonical_code("mixed", "rw") == "rw"


def test_assign_speakers_by_language_share():
    cfg = preset("base")
    cfg.text.languages = ["rw", "en", "fr", "sw"]
    groups = plan_voice_groups(cfg)
    reg = SpeakerRegistry({
        "f1": {"id": 0, "gender": "female", "languages": {"fr": 100}},
        "e1": {"id": 1, "gender": "male", "languages": {"en": 50, "fr": 2}},
        "cs": {"id": 2, "gender": "female", "languages": {"rw": 40, "en": 30}, "cross_lingual": True},
        "sw1": {"id": 3, "gender": "male", "languages": {"sw": 20}},
        "nolang": {"id": 4, "gender": "male"},
    })
    out = assign_speakers(reg, groups, "rw")
    assert out == {"french": [0], "english": [1], "bantu": [2, 3, 4]}
    assert voice_name("bantu", "female", 2) == "bantu_female_2"


def test_registry_tracks_languages_and_cross_lingual():
    recs = [{"speaker": "a", "gender": "female", "language": "rw"}] * 8 + \
           [{"speaker": "a", "gender": "female", "language": "en"}] * 2 + \
           [{"speaker": "b", "gender": "male", "language": "sw"}] * 3
    reg = SpeakerRegistry.from_records(recs)
    assert reg.table["a"]["languages"] == {"rw": 8, "en": 2}
    assert reg.table["a"]["cross_lingual"] is True        # 20% English
    assert reg.table["b"]["cross_lingual"] is False
