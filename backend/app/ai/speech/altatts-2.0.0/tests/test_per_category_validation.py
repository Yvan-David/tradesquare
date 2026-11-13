"""Training reports validation error per dataset category."""
import json
import os

import numpy as np
import pytest

torch = pytest.importorskip("torch")

from altatts.audio import save_wav                                # noqa: E402
from altatts.config import preset                                 # noqa: E402
from altatts.training.data import load_records, SpeakerRegistry, TTSDataset, collate  # noqa: E402


def test_dataset_field_flows_to_validation(tmp_path):
    sr = 22050
    rows = []
    for i in range(8):
        t = np.arange(int(1.2 * sr)) / sr
        save_wav(str(tmp_path / f"{i}.wav"), (0.3 * np.sin(2 * np.pi * (150 + 20 * i) * t)).astype(np.float32), sr)
        rows.append({"audio_path": f"{i}.wav", "text": "muraho neza", "speaker": "s", "duration": 1.2,
                     "dataset": "corpusA" if i % 2 else "corpusB", "language": "rw"})
    meta = tmp_path / "m.jsonl"
    meta.write_text("\n".join(json.dumps(r) for r in rows))
    cfg = preset("small")
    cfg.data.audio_root = str(tmp_path)
    recs = load_records([str(meta)], cfg)
    assert {r["dataset"] for r in recs} == {"corpusA", "corpusB"}
    from altatts.text import build_tokenizer
    tok = build_tokenizer([r["norm_text"] for r in recs], languages=cfg.text.languages)
    ds = TTSDataset(recs, cfg, tok, SpeakerRegistry.from_records(recs))
    assert ds.categories == ["corpusA", "corpusB"]
    batch = collate([ds[0], ds[1]])
    assert batch["category"] == ["corpusB", "corpusA"] and batch["language"] == ["rw", "rw"]
    # the trainer's per-category aggregation on a tiny model
    cfg.model.hidden_channels = 32; cfg.model.filter_channels = 64; cfg.model.n_layers = 1; cfg.model.n_heads = 2
    cfg.model.posterior_layers = 2; cfg.model.flow_layers = 1; cfg.model.upsample_initial_channel = 64
    cfg.prior.hidden = 32; cfg.prior.n_layers = 1; cfg.prior.n_heads = 2; cfg.train.segment_size = 8
    cfg.train.num_workers = 0; cfg.train.batch_size = 4; cfg.train.device = "cpu"; cfg.train.amp = False
    cfg.validate()
    from altatts.model import build_model
    from altatts.training.trainer import Trainer
    tr = Trainer(cfg, build_model(cfg, len(tok)), ds, ds, str(tmp_path / "run"), tokenizer=tok)
    val = tr.validate()
    assert set(val["val_mel_l1_by_dataset"]) == {"corpusA", "corpusB"}
    assert val["val_clips_by_dataset"] == {"corpusA": 4, "corpusB": 4}
