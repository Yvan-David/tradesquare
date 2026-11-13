"""``altatts-train`` -- train an ALTATTS voice from ALTASR-format data.

Single GPU / CPU (the default -- no flags needed):
    altatts-train --preset base \
        --train-metadata data/tts_train.json \
        --val-metadata data/tts_val.json \
        --audio-root data/ --out runs/kinyarwanda

All GPUs of the machine:
    altatts-train --gpus all ...

Multi-node (node 0 and node 1, 8 GPUs each):
    altatts-train --nodes 2 --node-rank 0 --master-addr node0 --gpus all ...
    altatts-train --nodes 2 --node-rank 1 --master-addr node0 --gpus all ...

Classic torchrun still works:
    torchrun --nproc_per_node=4 -m altatts.training.train --preset base ...

Multilingual / code-switched corpus:
    altatts-train --languages rw en fr sw ...

The output folder becomes a self-contained checkpoint:
    config.json tokenizer.json speakers.json voices.json model.pt checkpoint.pt
which ``altatts.Synthesizer.from_pretrained(folder)`` loads directly.
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import List, Optional

from ..config import Config, preset, load_config, PRESET_NAMES
from ..utils import (quiet_warnings, clear_terminal, set_seed, ddp_init,
                     ddp_cleanup, is_main_process, ensure_writable_dir)


def _build_tokenizer(cfg: Config, train_records, init_src: str):
    """Fresh tokenizer from the training text, or -- when fine-tuning -- the
    source run's tokenizer extended with any new symbols (so the pretrained
    text embeddings stay valid and new characters/tags get fresh rows)."""
    from ..text import build_tokenizer, CharTokenizer
    from ..tags import SPECIAL_TOKENS
    tok_path = (os.path.join(init_src, "tokenizer.json")
                if init_src and os.path.isdir(init_src) else "")
    specials = list(SPECIAL_TOKENS) if not cfg.is_legacy else []
    fresh = build_tokenizer([r["norm_text"] for r in train_records],
                            specials=specials, languages=cfg.text.languages)
    if tok_path and os.path.isfile(tok_path):
        old = CharTokenizer.load(tok_path)
        syms = list(old.symbols)
        added = [s for s in fresh.symbols if s not in old.sym2id]
        syms += added
        tok = CharTokenizer(syms, specials=[s for s in specials if s in syms],
                            languages=cfg.text.languages)
        if is_main_process():
            print(f"[train] fine-tuning: reusing tokenizer from {init_src} "
                  f"({len(old)} symbols, +{len(added)} new) so text weights transfer")
        return tok
    return fresh


def run(cfg: Config, out_dir: str, limit: int = 0, val_limit: int = 0,
        dry_run: bool = False) -> None:
    quiet_warnings()
    import torch  # noqa: F401  (fail fast with a clear message if missing)

    from ..model import build_model
    from .data import load_records, SpeakerRegistry, TTSDataset
    from .trainer import Trainer

    set_seed(cfg.train.seed)
    ddp_init(cfg.train.ddp_timeout_min)
    ensure_writable_dir(out_dir)

    d = cfg.data
    train_records = load_records(d.train_metadata, cfg)
    val_records = load_records(d.val_metadata, cfg) if d.val_metadata else []
    def _even_subset(recs, n):
        """Every k-th record so a quick run still spans all corpora/speakers."""
        if not n or n >= len(recs):
            return recs
        step = len(recs) / float(n)
        return [recs[int(i * step)] for i in range(n)]
    train_records = _even_subset(train_records, limit)
    val_records = _even_subset(val_records, val_limit)
    if not train_records:
        raise SystemExit("No usable training records. Check --train-metadata "
                         "and --audio-root, or run altatts-prepare-data first.")

    init_src = getattr(cfg.train, "init_from", "")
    tokenizer = _build_tokenizer(cfg, train_records, init_src)
    speakers = SpeakerRegistry.from_records(train_records)
    cfg.model.n_speakers = max(cfg.model.n_speakers, len(speakers))
    cfg.validate()

    if is_main_process():
        cfg.save(os.path.join(out_dir, "config.json"))
        tokenizer.save(os.path.join(out_dir, "tokenizer.json"))
        speakers.save(os.path.join(out_dir, "speakers.json"))
        hours = sum(float(r.get("duration") or 0) for r in train_records) / 3600
        print(f"[train] {cfg.summary()}")
        print(f"[train] {len(train_records)} train / {len(val_records)} val "
              f"clips ({hours:.1f} h), {len(speakers)} speaker(s), "
              f"{len(tokenizer)} symbols")
        genders: dict = {}
        for v in speakers.voices().values():
            genders[v.get("gender", "?")] = genders.get(v.get("gender", "?"), 0) + 1
        print(f"[train] speaker genders: {genders}")
        if not cfg.is_legacy:
            emo: dict = {}
            for r in train_records:
                k = ("unlabeled" if not r.get("emotion_id")
                     else cfg.style.emotions[r["emotion_id"] - 1])
                emo[k] = emo.get(k, 0) + 1
            langs: dict = {}
            for r in train_records:
                langs[r.get("language")] = langs.get(r.get("language"), 0) + 1
            n_pause = sum("[pause" in r["norm_text"] for r in train_records)
            cats: dict = {}
            for r in train_records:
                cats[r.get("dataset") or "all"] = cats.get(r.get("dataset") or "all", 0) + 1
            if len(cats) > 1:
                print(f"[train] dataset categories (validation error is reported per category): {cats}")
            print(f"[train] emotions: {emo}")
            print(f"[train] record languages: {langs}  clips with [pause] "
                  f"tokens: {n_pause}")
        for alias in ("male", "female"):
            try:
                sid = speakers.resolve_voice(alias)
                name = speakers.name_of(sid)
                short = name if len(name) <= 20 else name[:8] + "..." + name[-4:]
                print(f"[train] default voice '{alias}': speaker {short}")
            except (KeyError, StopIteration, TypeError):
                print(f"[train] default voice '{alias}': none available")

    train_ds = TTSDataset(train_records, cfg, tokenizer, speakers)
    val_ds = TTSDataset(val_records, cfg, tokenizer, speakers) if val_records else None

    net_g = build_model(cfg, len(tokenizer))
    if is_main_process():
        n = sum(p.numel() for p in net_g.parameters()) / 1e6
        print(f"[train] generator parameters: {n:.1f}M")
    if dry_run:
        from .data import collate
        batch = collate([train_ds[i] for i in range(min(2, len(train_ds)))])
        print("[train] dry run: one batch -> "
              + ", ".join(f"{k}={tuple(v.shape)}" for k, v in batch.items()))
        return
    trainer = Trainer(cfg, net_g, train_ds, val_ds, out_dir,
                      tokenizer=tokenizer, speakers=speakers)
    try:
        trainer.fit()
    finally:
        ddp_cleanup()


def build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Train an ALTATTS voice (VITS + MeanFlow, multi-speaker, "
                    "multilingual, zero-shot cloning).")
    p.add_argument("--preset", default="base", choices=list(PRESET_NAMES))
    p.add_argument("--config", default=None, help="Config JSON (overrides preset)")
    p.add_argument("--recipe", default=None,
                   help="Ready-made config shipped with altatts (see `altatts "
                        "recipes`), e.g. multilingual_callcenter")
    p.add_argument("--train-metadata", nargs="+", default=None)
    p.add_argument("--val-metadata", nargs="+", default=None)
    p.add_argument("--audio-root", default=None)
    p.add_argument("--out", "--out-dir", dest="out", default=None,
                   help="Output/checkpoint folder")
    p.add_argument("--epochs", type=int, default=None)
    p.add_argument("--batch-size", type=int, default=None)
    p.add_argument("--lr", "--learning-rate", dest="lr", type=float, default=None)
    p.add_argument("--num-workers", type=int, default=None)
    p.add_argument("--device", default=None, help="auto | cpu | cuda | cuda:N")
    p.add_argument("--seed", type=int, default=None)
    p.add_argument("--no-amp", action="store_true", help="Disable mixed precision")
    p.add_argument("--segment-size", type=int, default=None)
    p.add_argument("--max-batch-seconds", type=float, default=None)
    p.add_argument("--min-duration", type=float, default=None)
    p.add_argument("--max-duration", type=float, default=None)
    p.add_argument("--checkpoint-every", type=int, default=None)
    p.add_argument("--step-checkpoint-every", type=int, default=None)
    p.add_argument("--log-every", type=int, default=None)
    p.add_argument("--resume", default=None, help="checkpoint.pt to resume from")
    s = p.add_argument_group("schedule, early stopping, logging")
    s.add_argument("--lr-warmup-steps", type=int, default=None, help="linear LR warmup steps (default 500)")
    s.add_argument("--early-stop-patience", type=int, default=None,
                   help="stop after N epochs without improvement of the validation metric (0 = off)")
    s.add_argument("--early-stop-min-delta", type=float, default=None)
    s.add_argument("--early-stop-metric", choices=["val_mel_l1", "val_mf"], default=None)
    s.add_argument("--max-hours", type=float, default=None, help="wall-clock training budget")
    s.add_argument("--wandb-project", default=None, help="log to Weights & Biases (pip install wandb)")
    s.add_argument("--no-tensorboard", action="store_true")
    p.add_argument("--init-from", default=None,
                   help="Fine-tune: run FOLDER (or .pt) of a previous model "
                        "to warm-start from (v1 checkpoints upgrade to v2).")
    p.add_argument("--init-speaker-mode", choices=["mean", "random"], default=None)
    p.add_argument("--freeze", default=None,
                   help="Comma-separated modules to freeze while fine-tuning, "
                        "e.g. 'enc_p,flow' (also: dec, dp, enc_q, emb_g, "
                        "prior, ref_enc, emb_emo)")
    # ---- v2 ---------------------------------------------------------------- #
    g = p.add_argument_group("languages, style, prior (ALTATTS 2)")
    g.add_argument("--languages", nargs="+", default=None, metavar="CODE",
                   help="Languages the model speaks, primary first "
                        "(e.g. rw en fr sw). Default: rw")
    g.add_argument("--language", default=None,
                   help="Record language when metadata has none (default: "
                        "the primary language)")
    g.add_argument("--emotions", nargs="+", default=None,
                   help="Emotion categories (default: neutral happy sad angry "
                        "fearful surprised disgusted calm excited)")
    g.add_argument("--no-emotions", action="store_true",
                   help="Disable emotion conditioning")
    g.add_argument("--no-cloning", action="store_true",
                   help="Disable the zero-shot speaker encoder")
    g.add_argument("--prior", choices=["meanflow", "flow"], default=None,
                   help="Latent prior used at inference (both are trained)")
    g.add_argument("--meanflow-ratio", type=float, default=None)
    g.add_argument("--steps", type=int, default=None,
                   help="Default MeanFlow sampling steps")
    g.add_argument("--auto-pauses", choices=["off", "punct"], default=None)
    g.add_argument("--no-default-voices", action="store_true",
                   help="Skip building the anonymized default voices")
    g.add_argument("--legacy-v1", action="store_true",
                   help="Train the exact ALTATTS 0.1 network (no style "
                        "encoder / MeanFlow / language ids)")
    p.add_argument("--limit", type=int, default=0,
                   help="Use only the first N training records (quick runs)")
    p.add_argument("--val-limit", type=int, default=0)
    p.add_argument("--dry-run", action="store_true",
                   help="Resolve data, build the model, load one batch, exit")
    from .launch import add_launch_args
    add_launch_args(p)
    return p


def config_from_args(args) -> Config:
    if args.config:
        cfg = load_config(args.config)
    elif getattr(args, "recipe", None):
        from ..recipes import path_of
        cfg = load_config(path_of(args.recipe))
    else:
        cfg = preset(args.preset)
    if args.legacy_v1:
        cfg.model.version = 1
        cfg.prior.type = "flow"
        cfg.style.speaker_encoder = "none"
        cfg.style.emotion_conditioning = False
        cfg.style.expose_training_speakers = True
    if args.train_metadata:
        cfg.data.train_metadata = args.train_metadata
    if args.val_metadata:
        cfg.data.val_metadata = args.val_metadata
    if args.audio_root is not None:
        cfg.data.audio_root = args.audio_root
    simple = {"epochs": ("train", "epochs"), "batch_size": ("train", "batch_size"),
              "lr": ("train", "lr"), "num_workers": ("train", "num_workers"),
              "device": ("train", "device"), "seed": ("train", "seed"),
              "segment_size": ("train", "segment_size"),
              "max_batch_seconds": ("train", "max_batch_seconds"),
              "checkpoint_every": ("train", "checkpoint_every"),
              "step_checkpoint_every": ("train", "step_checkpoint_every"),
              "log_every": ("train", "log_every"), "resume": ("train", "resume"),
              "init_from": ("train", "init_from"),
              "init_speaker_mode": ("train", "init_speaker_mode"),
              "freeze": ("train", "freeze"),
              "min_duration": ("data", "min_duration_s"),
              "max_duration": ("data", "max_duration_s"),
              "language": ("data", "default_language"),
              "auto_pauses": ("data", "auto_pauses"),
              "prior": ("prior", "type"), "meanflow_ratio": ("prior", "meanflow_ratio"),
              "steps": ("prior", "steps"),
              "lr_warmup_steps": ("train", "lr_warmup_steps"),
              "early_stop_patience": ("train", "early_stop_patience"),
              "early_stop_min_delta": ("train", "early_stop_min_delta"),
              "early_stop_metric": ("train", "early_stop_metric"),
              "max_hours": ("train", "max_hours"), "wandb_project": ("train", "wandb_project")}
    for arg, (sec, key) in simple.items():
        v = getattr(args, arg, None)
        if v is not None:
            setattr(getattr(cfg, sec), key, v)
    if args.no_amp:
        cfg.train.amp = False
    if getattr(args, "no_tensorboard", False):
        cfg.train.tensorboard = False
    if args.languages:
        from ..languages import canonical_code
        cfg.text.languages = [canonical_code(c, c) for c in args.languages]
    if args.emotions:
        cfg.style.emotions = [e.lower() for e in args.emotions]
    if args.no_emotions:
        cfg.style.emotion_conditioning = False
    if args.no_cloning:
        cfg.style.speaker_encoder = "none"
    if args.no_default_voices:
        cfg.train.build_default_voices = False
    cfg.validate()
    return cfg


def main(argv: Optional[List[str]] = None) -> None:
    quiet_warnings()
    clear_terminal()
    args = build_argparser().parse_args(argv)
    from .launch import maybe_relaunch
    maybe_relaunch("altatts.training.train", args, argv)
    cfg = config_from_args(args)
    if not cfg.data.train_metadata:
        print("ERROR: no training metadata. Pass --train-metadata (and "
              "--audio-root) or a --config that defines them.", file=sys.stderr)
        raise SystemExit(2)
    out_dir = args.out or cfg.train.out_dir
    cfg.train.out_dir = out_dir
    run(cfg, out_dir, limit=args.limit, val_limit=args.val_limit,
        dry_run=args.dry_run)


if __name__ == "__main__":
    main()
