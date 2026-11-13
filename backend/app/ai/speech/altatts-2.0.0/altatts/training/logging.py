"""
Training logs that answer "how is my run doing?" at a glance -- locally, on
a remote server over ssh, or in a dashboard.

Every run folder gets:

    logs/train.log      every console line with a timestamp (rank 0)
    metrics.jsonl       one line per logged STEP: losses, grad norms, lr,
                        throughput, GPU memory, step time
    history.jsonl       one line per EPOCH: averaged losses, validation
                        (overall + per dataset + per language), best flag,
                        early-stopping state, timing
    status.json         the live summary (rewritten every log interval):
                        epoch/step/ETA, last metrics, best validation, the
                        per-dataset validation table, early-stop counter
    logs/tensorboard/   TensorBoard event files when `tensorboard` is installed
    (optional)          Weights & Biases when `wandb` is installed and
                        train.wandb_project is set

Read them with ``altatts logs --run runs/x`` (table + optional PNG curves),
``tail -f runs/x/logs/train.log``, ``cat runs/x/status.json`` or
``tensorboard --logdir runs/x/logs/tensorboard``.

Metric glossary (training, per step / epoch average)
----------------------------------------------------
loss_g      total generator loss (sum of the terms below) -- noisy, trend only
mel         L1 between the mel of the generated and real waveform x 45:
            THE quality signal during training; falls fast then slowly
kl          prior/posterior KL: how well text explains the audio latent
dur         duration-predictor MSE (log frames): rhythm accuracy
fm          discriminator feature matching x 2
adv         generator adversarial (LSGAN)
mf          MeanFlow prior regression: the naturalness prior learning
spk         reference-encoder regression to the speaker table (cloning)
spk_cos     cosine similarity reference embedding vs table (-> 1 = cloning works)
loss_d      discriminator loss (~1-3; near 0 = discriminator winning = check data)
grad_norm_g / grad_norm_d   gradient norms before clipping (spikes = instability)
lr          current learning rate (warmup + per-epoch decay)
clips_per_s, audio_s_per_s  throughput; gpu_mem_gb peak allocated memory
nonfinite   steps skipped because a loss was NaN/inf

Validation (per epoch)
----------------------
val_mel_l1              teacher-forced mel L1 on the dev set (lower = better):
                        THE metric for checkpoint selection and early stopping
val_mf                  MeanFlow loss on dev
val_mel_l1_by_dataset / val_mel_l1_by_language   the same per corpus / language
val_worst_dataset       the corpus with the highest error this epoch
"""
from __future__ import annotations

import json
import os
import sys
import time
from typing import Dict, Optional


class TrainLogger:
    def __init__(self, out_dir: str, enabled: bool = True, tensorboard: bool = True,
                 wandb_project: str = "", run_name: Optional[str] = None,
                 config: Optional[Dict] = None):
        self.out_dir = out_dir
        self.enabled = enabled
        self.log_path = os.path.join(out_dir, "logs", "train.log")
        self.metrics_path = os.path.join(out_dir, "metrics.jsonl")
        self.history_path = os.path.join(out_dir, "history.jsonl")
        self.status_path = os.path.join(out_dir, "status.json")
        self._tb = None
        self._wandb = None
        self._status: Dict = {"run": os.path.abspath(out_dir), "started_at": _now()}
        if not enabled:
            return
        os.makedirs(os.path.dirname(self.log_path), exist_ok=True)
        if tensorboard:
            try:
                from torch.utils.tensorboard import SummaryWriter
                self._tb = SummaryWriter(os.path.join(out_dir, "logs", "tensorboard"))
            except Exception:                                # noqa: BLE001
                self._tb = None
        if wandb_project:
            try:
                import wandb
                self._wandb = wandb.init(project=wandb_project, dir=out_dir,
                                         name=run_name or os.path.basename(os.path.abspath(out_dir)),
                                         config=config or {}, resume="allow")
            except Exception as exc:                         # noqa: BLE001
                self.say(f"[log] wandb disabled ({exc})")
                self._wandb = None
        self.say(f"[log] file {self.log_path} | metrics {self.metrics_path} | "
                 f"status {self.status_path}"
                 + (f" | tensorboard {os.path.join(out_dir, 'logs', 'tensorboard')}" if self._tb else
                    " | tensorboard: pip install tensorboard to enable")
                 + (" | wandb: on" if self._wandb else ""))

    # ------------------------------------------------------------------ #
    def say(self, msg: str) -> None:
        """Print (rank 0) and append to logs/train.log with a timestamp."""
        if not self.enabled:
            return
        print(msg, flush=True)
        try:
            with open(self.log_path, "a", encoding="utf-8") as fh:
                fh.write(f"{_now()} {msg}\n")
        except OSError:
            pass

    def step(self, step: int, epoch: int, metrics: Dict[str, float]) -> None:
        if not self.enabled:
            return
        row = {"step": step, "epoch": epoch, "time": time.time()}
        row.update({k: _num(v) for k, v in metrics.items()})
        with open(self.metrics_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row) + "\n")
        if self._tb is not None:
            for k, v in metrics.items():
                if isinstance(v, (int, float)):
                    group = "throughput" if k in ("clips_per_s", "audio_s_per_s", "step_time_s") else "train"
                    self._tb.add_scalar(f"{group}/{k}", v, step)
        if self._wandb is not None:
            self._wandb.log({f"train/{k}": v for k, v in metrics.items() if isinstance(v, (int, float))},
                            step=step)

    def epoch(self, payload: Dict) -> None:
        if not self.enabled:
            return
        payload = dict(payload)
        payload["time"] = time.time()
        with open(self.history_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(payload) + "\n")
        step = int(payload.get("step", 0))
        if self._tb is not None:
            for k, v in payload.items():
                if isinstance(v, (int, float)) and k not in ("epoch", "step", "time"):
                    self._tb.add_scalar(f"epoch/{k}" if not k.startswith("val") else f"val/{k}", v, step)
            for key, tag in (("val_mel_l1_by_dataset", "val_by_dataset"),
                             ("val_mel_l1_by_language", "val_by_language")):
                for name, v in (payload.get(key) or {}).items():
                    self._tb.add_scalar(f"{tag}/{name}", v, step)
        if self._wandb is not None:
            flat = {k: v for k, v in payload.items() if isinstance(v, (int, float))}
            for key in ("val_mel_l1_by_dataset", "val_mel_l1_by_language"):
                for name, v in (payload.get(key) or {}).items():
                    flat[f"{key}/{name}"] = v
            self._wandb.log(flat, step=step)

    def status(self, **fields) -> None:
        """Rewrite status.json atomically (safe to read any time)."""
        if not self.enabled:
            return
        self._status.update(fields)
        self._status["updated_at"] = _now()
        tmp = self.status_path + ".tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as fh:
                json.dump(self._status, fh, indent=1, ensure_ascii=False, default=_num)
            os.replace(tmp, self.status_path)
        except OSError:
            pass

    def close(self) -> None:
        if self._tb is not None:
            try:
                self._tb.flush()
                self._tb.close()
            except Exception:                                # noqa: BLE001
                pass
        if self._wandb is not None:
            try:
                self._wandb.finish()
            except Exception:                                # noqa: BLE001
                pass


class StepTable:
    """The ALTASR step table for TTS: one aligned row per logged step, a
    header every ``HEADER_EVERY`` rows, a legend once per run, and
    *elapsed* / *ETA* columns so a glance tells how far the run is and
    when it ends. Rows go through ``say`` so they land in train.log too."""

    HEADER_EVERY = 20
    _COLS = (("epoch", 5), ("step/epoch", 12), ("step/total", 15), ("gen", 7), ("mel", 6),
             ("kl", 6), ("dur", 6), ("mf", 6), ("disc", 6), ("lr", 8), ("grad", 6),
             ("steps/s", 7), ("xRT", 6), ("mem", 6), ("elapsed", 9), ("ETA", 9))
    LEGEND = (
        "  step/epoch = optimizer steps done in the CURRENT epoch · step/total = whole-training progress",
        "  gen = total generator loss · mel = mel L1 (the quality number) · kl = flow/posterior KL · "
        "dur = duration · mf = MeanFlow prior · disc = discriminator loss",
        "  lr = learning rate · grad = generator gradient norm (before clipping) · "
        "steps/s = optimizer steps per second · xRT = seconds of audio trained per second",
        "  mem = peak GPU memory (GB) · elapsed = wall-clock time of this run so far (resumes included) · "
        "ETA = estimated time to finish all epochs",
    )

    def __init__(self, say):
        self.say = say
        self._rows_since_header = self.HEADER_EVERY
        self._legend_pending = True

    @property
    def header(self) -> str:
        return " ".join(f"{name:>{w}}" for name, w in self._COLS)

    @staticmethod
    def _f(v, w: int, fmt: str = ".3f") -> str:
        return f"{v:>{w}{fmt}}" if isinstance(v, (int, float)) else f"{'--':>{w}}"

    def row(self, *, epoch: int, in_epoch: int, steps_per_epoch: int, step: int, total_steps: int,
            stats: Dict[str, float], steps_per_s: float, xrt: float, mem_gb: Optional[float],
            elapsed_s: float, eta_s: Optional[float]) -> str:
        from ..utils import fmt_duration
        cells = [f"{epoch + 1:>5}", f"{f'{in_epoch}/{steps_per_epoch}':>12}",
                 f"{f'{step}/{total_steps}':>15}",
                 self._f(stats.get("loss_g"), 7), self._f(stats.get("mel"), 6),
                 self._f(stats.get("kl"), 6), self._f(stats.get("dur"), 6),
                 self._f(stats.get("mf"), 6), self._f(stats.get("loss_d"), 6),
                 self._f(stats.get("lr"), 8, ".2e"), self._f(stats.get("grad_norm_g"), 6, ".1f"),
                 self._f(steps_per_s, 7, ".2f"), f"{f'{xrt:.0f}x' if xrt else '--':>6}",
                 f"{f'{mem_gb:.1f}G' if mem_gb else '--':>6}",
                 f"{fmt_duration(elapsed_s):>9}",
                 f"{fmt_duration(eta_s) if eta_s is not None else '--':>9}"]
        return " ".join(cells)

    def emit(self, **kw) -> None:
        if self._rows_since_header >= self.HEADER_EVERY:
            self.say(self.header)
            if self._legend_pending:
                for line in self.LEGEND:
                    self.say(line)
                self._legend_pending = False
            self.say("─" * len(self.header))
            self._rows_since_header = 0
        self.say(self.row(**kw))
        self._rows_since_header += 1


def box(title: str, lines, width: int = 96) -> str:
    """ALTASR-style framed block: ┌─ title ──…, │ lines, └──…"""
    top = f"┌─ {title} "
    out = [top + "─" * max(1, width - len(top))]
    out += [f"│ {line}" for line in lines]
    out.append("└" + "─" * (width - 1))
    return "\n".join(out)


def _now() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S")


def _num(v):
    try:
        import torch
        if torch.is_tensor(v):
            return float(v.detach().float().mean())
    except Exception:                                        # noqa: BLE001
        pass
    if isinstance(v, (int, float, str, bool)) or v is None:
        return v
    if isinstance(v, dict):
        return {k: _num(x) for k, x in v.items()}
    return str(v)


# --------------------------------------------------------------------------- #
#  ``altatts logs`` -- read a run folder
# --------------------------------------------------------------------------- #
def read_history(run_dir: str):
    p = os.path.join(run_dir, "history.jsonl")
    if not os.path.isfile(p):
        return []
    with open(p, encoding="utf-8") as fh:
        return [json.loads(l) for l in fh if l.strip()]


def read_metrics(run_dir: str, last: int = 0):
    p = os.path.join(run_dir, "metrics.jsonl")
    if not os.path.isfile(p):
        return []
    with open(p, encoding="utf-8") as fh:
        rows = [json.loads(l) for l in fh if l.strip()]
    return rows[-last:] if last else rows


def history_table(hist) -> str:
    if not hist:
        return "(no epochs logged yet)"
    cols = ["epoch", "step", "loss_g", "mel", "kl", "dur", "mf", "spk_cos", "val_mel_l1", "val_mf"]
    cols = [c for c in cols if any(c in h for h in hist)]
    lines = ["| " + " | ".join(cols) + " | best | worst dataset | epoch time |",
             "|" + "---|" * (len(cols) + 3)]
    best_epoch = next((h.get("best_epoch") for h in reversed(hist) if h.get("best_epoch") is not None), None)
    best = min((h.get("val_mel_l1", float("inf")) for h in hist), default=None)
    for h in hist:
        cells = []
        for c in cols:
            v = h.get(c)
            cells.append(f"{v:.4f}" if isinstance(v, float) else (str(v) if v is not None else "-"))
        if best_epoch is not None:
            is_best = "*" if h.get("epoch") == best_epoch else ""
        else:
            is_best = "*" if h.get("val_mel_l1") is not None and h.get("val_mel_l1") == best else ""
        worst = h.get("val_worst_dataset") or "-"
        from ..utils import fmt_duration
        lines.append("| " + " | ".join(cells) + f" | {is_best} | {worst} | "
                     f"{fmt_duration(h.get('epoch_seconds', 0))} |")
    return "\n".join(lines)


def plot_curves(run_dir: str, out_png: str) -> bool:
    """Train/val curves -> PNG (needs matplotlib)."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except Exception:                                        # noqa: BLE001
        return False
    hist, metrics = read_history(run_dir), read_metrics(run_dir)
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    if metrics:
        steps = [m["step"] for m in metrics]
        for k in ("mel", "mf", "kl", "dur"):
            if any(k in m for m in metrics):
                axes[0, 0].plot(steps, [m.get(k) for m in metrics], label=k, lw=0.8)
        axes[0, 0].set_title("training losses per step")
        axes[0, 0].legend()
        axes[0, 0].set_yscale("log")
        axes[0, 1].plot(steps, [m.get("grad_norm_g") for m in metrics], label="grad_norm_g", lw=0.8)
        axes[0, 1].plot(steps, [m.get("grad_norm_d") for m in metrics], label="grad_norm_d", lw=0.8)
        axes[0, 1].set_title("gradient norms")
        axes[0, 1].legend()
        axes[0, 1].set_yscale("log")
    if hist:
        ep = [h["epoch"] for h in hist]
        axes[1, 0].plot(ep, [h.get("val_mel_l1") for h in hist], "o-", label="val_mel_l1")
        axes[1, 0].plot(ep, [h.get("mel", 0) / 45.0 for h in hist], "s--", label="train mel / 45")
        axes[1, 0].set_title("validation mel L1 per epoch")
        axes[1, 0].legend()
        names = sorted({k for h in hist for k in (h.get("val_mel_l1_by_dataset") or {})})
        for n in names:
            axes[1, 1].plot(ep, [(h.get("val_mel_l1_by_dataset") or {}).get(n) for h in hist], label=n, lw=0.9)
        axes[1, 1].set_title("validation per dataset")
        if names:
            axes[1, 1].legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(out_png, dpi=110)
    return True


def main(argv=None) -> int:
    import argparse
    p = argparse.ArgumentParser(prog="altatts logs", description="Summarise a training run folder")
    p.add_argument("--run", required=True, help="run folder (the --out of altatts-train)")
    p.add_argument("--last", type=int, default=5, help="show the last N step rows")
    p.add_argument("--png", default=None, help="write training curves to this PNG (needs matplotlib)")
    args = p.parse_args(argv)
    sp = os.path.join(args.run, "status.json")
    if os.path.isfile(sp):
        st = json.load(open(sp, encoding="utf-8"))
        print(f"status ({st.get('updated_at')}): epoch {st.get('epoch')} step {st.get('step')} "
              f"| {st.get('state', '?')} | best val_mel_l1 {st.get('best_val')} (epoch {st.get('best_epoch')}) "
              f"| elapsed {st.get('elapsed')} | eta {st.get('eta_total')}")
        if st.get("early_stop"):
            print(f"early stopping: {st['early_stop']}")
    hist = read_history(args.run)
    print(history_table(hist))
    rows = read_metrics(args.run, args.last)
    if rows:
        keys = [k for k in ("step", "loss_g", "mel", "mf", "spk_cos", "loss_d", "grad_norm_g", "lr",
                            "clips_per_s", "gpu_mem_gb") if k in rows[-1]]
        print("\nlast steps:")
        print("  " + "  ".join(f"{k:>11}" for k in keys))
        for r in rows:
            print("  " + "  ".join(f"{r.get(k):>11.4g}" if isinstance(r.get(k), float) else f"{str(r.get(k)):>11}" for k in keys))
    if args.png:
        ok = plot_curves(args.run, args.png)
        print(f"curves -> {args.png}" if ok else "matplotlib not installed: no PNG (pip install matplotlib)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
