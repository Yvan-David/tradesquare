"""The combine pipeline on synthetic corpora in two source formats, run
twice to check versioning (re-run replaces the previous version, reuses
unchanged audio, deletes orphans)."""
import csv
import json
import os

import numpy as np
import pytest

torch = pytest.importorskip("torch")

from altatts.audio import save_wav                                     # noqa: E402
from altatts.datasets import DatasetSpec, run                          # noqa: E402
from altatts.datasets.combine import balance, split_records, tag_language, clean  # noqa: E402


def _tone(path, f0, seconds, sr=16000):
    t = np.arange(int(seconds * sr)) / sr
    save_wav(path, (0.3 * np.sin(2 * np.pi * f0 * t)).astype(np.float32), sr)


@pytest.fixture(scope="module")
def corpus(tmp_path_factory):
    root = tmp_path_factory.mktemp("data")
    # corpus A: ALTATTS metadata jsonl, two speakers, one with emotion labels
    a = root / "corpusA"
    (a / "audio").mkdir(parents=True)
    rows = []
    for i in range(24):
        spk = "f1" if i % 2 == 0 else "m1"
        _tone(str(a / "audio" / f"{i}.wav"), 220 if spk == "f1" else 110, 1.5 + 0.1 * (i % 5))
        rows.append({"audio_path": f"audio/{i}.wav", "text": f"muraho neza {i} amakuru", "speaker": spk,
                     "emotion": "happy" if i % 3 == 0 else None, "intensity": 0.7 if i % 3 == 0 else None})
    rows.append({"audio_path": "audio/missing.wav", "text": "x", "speaker": "f1"})
    rows.append({"audio_path": "audio/0.wav", "text": "muraho neza 0 amakuru", "speaker": "f1"})  # duplicate
    with open(a / "meta.jsonl", "w") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")
    # corpus B: LJSpeech-style csv, English, mixed sentence detection
    b = root / "corpusB"
    (b / "audio").mkdir(parents=True)
    with open(b / "metadata.csv", "w") as fh:
        for i in range(12):
            _tone(str(b / "audio" / f"LJ{i}.wav"), 200, 2.0)
            fh.write(f"LJ{i}|raw {i}|the quick brown fox number {i}\n")
    specs = [
        DatasetSpec(name="corpusA", path="corpusA", adapter="metadata", language="rw", family="bantu",
                    options={"files": ["meta.jsonl"], "audio_root": ""}, description="A"),
        DatasetSpec(name="corpusB", path="corpusB", adapter="ljspeech", language="en", family="english",
                    options={"speaker": "lj", "gender": "female"}, max_hours=0.004, description="B"),
    ]
    return str(root), specs


def test_pipeline_versions_and_outputs(corpus, tmp_path):
    root, specs = corpus
    out = str(tmp_path / "combined")
    r1 = run(specs, out, root, workers=2, convert=True, verbose=False, dev_fraction=0.1)
    assert r1.version["version"] == 1
    for f in ("train.jsonl", "dev.jsonl", "test.jsonl", "report.md", "report.json", "VERSION.json",
              "speakers.json", "config.json"):
        assert os.path.isfile(os.path.join(out, f)), f
    train = [json.loads(l) for l in open(os.path.join(out, "train.jsonl"))]
    dev = [json.loads(l) for l in open(os.path.join(out, "dev.jsonl"))]
    assert train and dev and all(r["audio_path"].startswith("audio/") for r in train)
    assert all(os.path.isfile(os.path.join(out, r["audio_path"])) for r in train + dev)
    assert {r["dataset"] for r in dev} == {"corpusA", "corpusB"}, "every dataset must reach dev"
    a = [d for d in r1.datasets if d["name"] == "corpusA"][0]
    assert a["dropped"].get("missing_audio") == 1 and a["dropped"].get("duplicate") == 1
    genders = {r["speaker"]: r["gender"] for r in train if r["dataset"] == "corpusA"}
    assert genders["corpusA/f1"] == "female" and genders["corpusA/m1"] == "male"   # from pitch
    assert any(r.get("emotion") == "happy" and r.get("intensity") == 0.7 for r in train)
    b = [d for d in r1.datasets if d["name"] == "corpusB"][0]
    assert b["hours_before_balance"] and b["kept"]["hours"] <= 0.004 + 1e-6
    assert all(len(v) == 3 for v in r1.samples.values())
    assert r1.voice_plan and sum(g["n_female"] + g["n_male"] for g in r1.voice_plan) == 8
    md = open(r1.report_path, encoding="utf-8").read()
    assert "version 1" in md and "corpusA" in md and "By language family" in md
    # ---- rerun: version 2, audio reused, orphans pruned ----
    n_audio_before = sum(len(f) for _, _, f in os.walk(os.path.join(out, "audio")))
    mtime = os.path.getmtime(os.path.join(out, train[0]["audio_path"]))
    specs2 = [specs[0]]                            # corpusB removed -> its audio is orphaned
    r2 = run(specs2, out, root, workers=2, convert=True, verbose=False, dev_fraction=0.1)
    assert r2.version["version"] == 2 and r2.version["previous_version"] == 1
    n_audio_after = sum(len(f) for _, _, f in os.walk(os.path.join(out, "audio")))
    assert n_audio_after < n_audio_before and not os.path.isdir(os.path.join(out, "audio", "corpusB"))
    assert os.path.getmtime(os.path.join(out, train[0]["audio_path"])) == mtime, "unchanged audio reused"
    assert not os.path.isdir(os.path.join(out, "samples", "corpusB"))


def test_helpers():
    assert tag_language("Ndashaka gusobanurira umuntu ko Mobile Money PIN ari confidential") == ("mixed", True)
    assert tag_language("muraho neza amakuru yawe") == ("rw", False)
    recs = [{"id": i, "speaker": "s", "duration": 10.0, "exists": True, "text": "abc def"} for i in range(100)]
    spec = DatasetSpec(name="x", path="x", adapter="metadata", language="rw", family="bantu",
                       max_hours=0.1, max_hours_per_speaker=0.2)
    kept = balance(recs, spec)
    assert abs(sum(r["duration"] for r in kept) / 3600 - 0.1) < 0.01
    tr, dv, te = split_records(recs, spec, dev_fraction=0.02, dev_min=2)
    assert len(dv) == 2 and len(tr) == 98 and not te
    spec_t = DatasetSpec(name="t", path="t", adapter="metadata", language="rw", family="bantu", role="test")
    assert split_records(recs, spec_t)[2] == recs
    kept, dropped = clean([{"exists": False}, {"exists": True, "text": "", "duration": 2},
                           {"exists": True, "text": "ok", "duration": 0.2, "speaker": "s"}], spec)
    assert not kept and dropped == {"missing_audio": 1, "empty_text": 1, "too_short": 1}


def test_registry_specs_are_consistent():
    from altatts.datasets import DATASETS, FAMILIES
    from altatts.datasets.adapters import ADAPTERS
    names = [s.name for s in DATASETS]
    assert len(names) == len(set(names))
    for s in DATASETS:
        assert s.adapter in ADAPTERS, s.adapter
        assert s.family in FAMILIES and s.role in ("train", "test")
        assert s.language in ("rw", "en", "fr", "sw", "mixed")
