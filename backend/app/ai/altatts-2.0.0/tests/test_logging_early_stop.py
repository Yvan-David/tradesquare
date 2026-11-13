"""Structured logging, LR warmup and early stopping on a tiny synthetic run."""
import json
import os

import numpy as np
import pytest

torch = pytest.importorskip("torch")

from altatts.audio import save_wav                                       # noqa: E402
from altatts.config import preset                                        # noqa: E402
from altatts.model import build_model                                    # noqa: E402
from altatts.text import build_tokenizer                                 # noqa: E402
from altatts.training.data import SpeakerRegistry, TTSDataset, load_records  # noqa: E402
from altatts.training.logging import TrainLogger, history_table, read_history, read_metrics  # noqa: E402
from altatts.training.trainer import Trainer                             # noqa: E402


def _tiny_run(tmp_path, **train_overrides):
    sr = 22050
    rows = []
    for i in range(12):
        t = np.arange(int(1.1 * sr)) / sr
        save_wav(str(tmp_path / f"{i}.wav"), (0.3 * np.sin(2 * np.pi * (140 + 15 * i) * t)).astype(np.float32), sr)
        rows.append({"audio_path": f"{i}.wav", "text": "muraho neza", "speaker": "s", "duration": 1.1,
                     "dataset": "corpusA" if i % 2 else "corpusB"})
    meta = tmp_path / "m.jsonl"
    meta.write_text("\n".join(json.dumps(r) for r in rows))
    cfg = preset("small")
    cfg.data.audio_root = str(tmp_path)
    cfg.model.hidden_channels = 32; cfg.model.filter_channels = 64; cfg.model.n_layers = 1; cfg.model.n_heads = 2
    cfg.model.posterior_layers = 2; cfg.model.flow_layers = 1; cfg.model.upsample_initial_channel = 64
    cfg.prior.hidden = 32; cfg.prior.n_layers = 1; cfg.prior.n_heads = 2; cfg.train.segment_size = 8
    cfg.train.num_workers = 0; cfg.train.batch_size = 4; cfg.train.device = "cpu"; cfg.train.amp = False
    cfg.train.log_every = 1; cfg.train.n_val_samples = 1; cfg.train.build_default_voices = False
    cfg.train.tensorboard = False
    for k, v in train_overrides.items():
        setattr(cfg.train, k, v)
    cfg.validate()
    recs = load_records([str(meta)], cfg)
    tok = build_tokenizer([r["norm_text"] for r in recs], languages=cfg.text.languages)
    spk = SpeakerRegistry.from_records(recs)
    ds = TTSDataset(recs, cfg, tok, spk)
    out = str(tmp_path / "run")
    tr = Trainer(cfg, build_model(cfg, len(tok)), ds, ds, out, tokenizer=tok, speakers=spk)
    return cfg, tr, out


def test_logger_writes_all_files(tmp_path):
    lg = TrainLogger(str(tmp_path), enabled=True, tensorboard=False)
    lg.say("hello")
    lg.step(1, 0, {"mel": 1.0, "lr": 1e-4})
    lg.epoch({"epoch": 0, "step": 1, "val_mel_l1": 0.5, "val_mel_l1_by_dataset": {"a": 0.4, "b": 0.6}})
    lg.status(state="training", epoch=0)
    lg.close()
    assert "hello" in open(tmp_path / "logs" / "train.log").read()
    assert read_metrics(str(tmp_path))[0]["mel"] == 1.0
    hist = read_history(str(tmp_path))
    assert hist[0]["val_mel_l1_by_dataset"]["b"] == 0.6 and "val_mel_l1" in history_table(hist)
    assert json.load(open(tmp_path / "status.json"))["state"] == "training"


def test_warmup_and_early_stopping(tmp_path):
    cfg, tr, out = _tiny_run(tmp_path, epochs=6, lr_warmup_steps=4, early_stop_patience=1,
                             early_stop_min_delta=100.0)      # nothing can "improve" by 100
    tr.step = 0
    assert abs(tr.current_lr() - cfg.train.lr / 4) < 1e-12
    tr.step = 10
    assert abs(tr.current_lr() - cfg.train.lr) < 1e-12
    tr.fit()
    hist = read_history(out)
    # epoch 0 sets the best; epoch 1 shows no improvement >= patience 1 -> stop after epoch 1
    assert len(hist) == 2 and hist[0]["improved"] is True and hist[1]["bad_epochs"] == 1
    assert "early" in tr.stop_reason
    st = json.load(open(os.path.join(out, "status.json")))
    assert st["state"] == "early-stopped" and st["best_epoch"] == 0
    assert os.path.isfile(os.path.join(out, "best.pt")) and os.path.isfile(os.path.join(out, "metrics.jsonl"))
    rows = read_metrics(out)
    assert rows and {"grad_norm_g", "grad_norm_d", "lr", "clips_per_s"} <= set(rows[-1])
    assert hist[0]["val_worst_dataset"] in ("corpusA", "corpusB")
    log = open(os.path.join(out, "logs", "train.log")).read()
    assert "validation error by dataset" in log and "stopping: early stopping" in log


def test_time_budget_stops(tmp_path):
    cfg, tr, out = _tiny_run(tmp_path, epochs=5, max_hours=1e-9)
    tr.fit()
    assert "budget" in tr.stop_reason and len(read_history(out)) == 1


def test_step_table_header_legend_and_alignment(capsys):
    from altatts.training.logging import StepTable, box
    said = []
    table = StepTable(said.append)
    stats = {"loss_g": 41.2345, "mel": 0.5123, "kl": 1.2, "dur": 0.4, "loss_d": 2.5,
             "lr": 2e-4, "grad_norm_g": 12.3}
    for i in range(1, 4):
        table.emit(epoch=0, in_epoch=i, steps_per_epoch=500, step=i, total_steps=100_000, stats=stats,
                   steps_per_s=0.0 if i == 1 else 1.25, xrt=0.0 if i == 1 else 180.0,
                   mem_gb=18.2, elapsed_s=3700, eta_s=None if i == 1 else 86_400 * 2 + 3 * 3600)
    assert said[0] == table.header
    assert said[1:5] == list(StepTable.LEGEND)          # legend printed once, under the first header
    assert said[5].startswith("─")
    rows = said[6:]
    assert len(rows) == 3 and all(len(r) == len(table.header) for r in rows)   # aligned
    assert "--" in rows[0] and rows[0].endswith("1h01m        --")            # no ETA before a rate exists
    assert rows[1].endswith("1h01m     2d03h") and "180x" in rows[1] and "18.2G" in rows[1]
    assert "2.00e-04" in rows[1] and "1/500" in rows[0] and "3/100000" in rows[2]
    for _ in range(StepTable.HEADER_EVERY):
        table.emit(epoch=0, in_epoch=9, steps_per_epoch=500, step=9, total_steps=10, stats={},
                   steps_per_s=1, xrt=1, mem_gb=None, elapsed_s=1, eta_s=1)
    assert said.count(table.header) == 2 and said.count(StepTable.LEGEND[0]) == 1   # header repeats, legend not
    framed = box("epoch 1/2 done", ["a", "b"], width=40).splitlines()
    assert framed[0].startswith("┌─ epoch 1/2 done ") and len(framed[0]) == 40
    assert framed[1:3] == ["│ a", "│ b"] and framed[3] == "└" + "─" * 39


def test_jit_warning_source_removed_and_children_quiet(monkeypatch):
    import inspect
    import subprocess
    import sys
    import altatts.model.modules as modules
    from altatts.utils import CHILD_WARNING_FILTERS, quiet_warnings
    assert "@torch.jit.script" not in inspect.getsource(modules)
    monkeypatch.delenv("PYTHONWARNINGS", raising=False)
    monkeypatch.delenv("ALTATTS_VERBOSE", raising=False)
    quiet_warnings()
    assert os.environ["PYTHONWARNINGS"] == CHILD_WARNING_FILTERS
    # a fresh interpreter (what a spawned DataLoader worker is) inherits the silence
    code = "import warnings; warnings.warn('`torch.jit.script` is deprecated. x', FutureWarning); print('ran')"
    p = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, env=dict(os.environ))
    assert p.returncode == 0 and "ran" in p.stdout and p.stderr.strip() == "", p.stderr
    p = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True,
                       env={**os.environ, "PYTHONWARNINGS": ""})
    assert "FutureWarning" in p.stderr                   # control: without the filters it prints
