"""VITS + MeanFlow GAN trainer for ALTATTS.

Objective (ALTATTS 2):

    L_G = L_adv + c_fm*L_fm + c_mel*L_mel + c_dur*L_dur + c_kl*L_kl
          + c_mf*L_meanflow + c_spk*L_spk
    L_D = LSGAN real/fake loss

Features: bf16/fp16 autocast, DDP (torchrun / --gpus / multi-node, CPU
gloo), duration-bucketed batches, LR warmup + per-epoch decay, NaN guard,
resume + auto-resume, rolling mid-epoch checkpoints, full-dev validation
broken down per dataset and language, **early stopping** on the validation
metric with a patience and a wall-clock budget, structured logging
(``logs/train.log``, ``metrics.jsonl``, ``history.jsonl``, ``status.json``,
optional TensorBoard / W&B -- see ``training/logging.py``), sample synthesis
spread over corpora, and the production-voice builder at the end.
"""

from __future__ import annotations

import json
import math
import os
import time
from typing import Dict, Optional

import torch
import torch.nn.functional as F
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data import DataLoader

from ..config import Config
from ..audio import mel_spectrogram_torch, spec_to_mel_torch, save_wav
from ..utils import (is_main_process, ddp_active, ddp_rank, ddp_world_size,
                     fmt_duration as _fmt_dur, ensure_writable_dir)
from ..model import (
    SynthesizerTrn,
    MultiPeriodDiscriminator,
    discriminator_loss,
    generator_adv_loss,
    feature_matching_loss,
    kl_loss,
)
from ..model.modules import slice_segments
from .data import TTSDataset, collate, BucketBatchSampler
from .logging import TrainLogger, StepTable, box


def _worker_init(worker_id: int) -> None:
    torch.set_num_threads(1)


class Trainer:
    def __init__(
        self,
        cfg: Config,
        net_g: SynthesizerTrn,
        train_dataset: TTSDataset,
        val_dataset: Optional[TTSDataset],
        out_dir: str,
        device: Optional["torch.device"] = None,
        tokenizer=None,
        speakers=None,
    ):
        self.cfg = cfg
        self.out_dir = out_dir
        self.tokenizer = tokenizer
        self.speakers = speakers
        ensure_writable_dir(out_dir)
        os.makedirs(os.path.join(out_dir, "samples"), exist_ok=True)
        t = cfg.train
        self.log = TrainLogger(out_dir, enabled=is_main_process(),
                               tensorboard=getattr(t, "tensorboard", True),
                               wandb_project=getattr(t, "wandb_project", ""),
                               config=cfg.to_dict())

        if device is None:
            if ddp_active() and torch.cuda.is_available():
                device = torch.device(f"cuda:{int(os.environ.get('LOCAL_RANK', 0))}")
            else:
                from ..utils import resolve_device
                device = torch.device(resolve_device(cfg.train.device))
        self.device = device
        if device.type == "cpu":
            from ..utils import ensure_cpu_conv_sanity
            msg = ensure_cpu_conv_sanity(verbose=False)
            if msg:
                self.log.say(msg)

        self.net_g = net_g.to(device)
        self.net_d = MultiPeriodDiscriminator().to(device)
        if ddp_active():
            ids = [device.index] if device.type == "cuda" else None
            self.net_g = DDP(self.net_g, device_ids=ids)
            self.net_d = DDP(self.net_d, device_ids=ids)

        freeze = [f.strip() for f in getattr(t, "freeze", "").split(",") if f.strip()]
        if freeze:
            frozen = 0
            for name, param in self._g().named_parameters():
                if any(name.startswith(pfx) for pfx in freeze):
                    param.requires_grad = False
                    frozen += 1
            self.log.say(f"[trainer] fine-tune freeze: {', '.join(freeze)} ({frozen} tensors fixed)")
        self.optim_g = torch.optim.AdamW(
            (p for p in self.net_g.parameters() if p.requires_grad),
            t.lr, betas=tuple(t.betas), eps=t.eps)
        self.optim_d = torch.optim.AdamW(
            self.net_d.parameters(), t.lr, betas=tuple(t.betas), eps=t.eps)

        self.use_amp = t.amp and device.type == "cuda"
        self.amp_dtype = torch.float16
        if self.use_amp:
            try:
                if torch.cuda.is_bf16_supported():
                    self.amp_dtype = torch.bfloat16
            except Exception:                                # noqa: BLE001
                pass
        self.scaler = torch.amp.GradScaler(
            "cuda", enabled=self.use_amp and self.amp_dtype == torch.float16)

        self.sampler = BucketBatchSampler(
            train_dataset.durations, t.batch_size, seed=t.seed,
            rank=ddp_rank(), world_size=ddp_world_size(),
            max_batch_seconds=getattr(t, "max_batch_seconds", 0.0))
        worker_kwargs = {}
        if t.num_workers > 0:
            worker_kwargs = dict(multiprocessing_context="spawn", persistent_workers=True,
                                 prefetch_factor=4, worker_init_fn=_worker_init)
        self.train_loader = DataLoader(
            train_dataset, batch_sampler=self.sampler, collate_fn=collate,
            num_workers=t.num_workers, pin_memory=device.type == "cuda", **worker_kwargs)
        self.train_dataset = train_dataset
        self.val_dataset = val_dataset
        self.val_loader = None
        if val_dataset is not None and len(val_dataset) > 0:
            val_workers = min(2, t.num_workers)
            val_kwargs = {}
            if val_workers > 0:
                val_kwargs = dict(multiprocessing_context="spawn", persistent_workers=True,
                                  worker_init_fn=_worker_init)
            # a FIXED seeded permutation: manifests are grouped by corpus, so a
            # capped validation (eval_batches > 0) still spans every dataset
            import random as _random
            from torch.utils.data import Subset
            perm = list(range(len(val_dataset)))
            _random.Random(t.seed).shuffle(perm)
            self.val_loader = DataLoader(
                Subset(val_dataset, perm), batch_size=max(1, t.batch_size // 2),
                shuffle=False, collate_fn=collate, num_workers=val_workers, **val_kwargs)

        self.epoch = 0
        self.step = 0
        self.prior_elapsed = 0.0
        self.fit_start = time.time()
        self.best_val = math.inf
        self.best_epoch = -1
        self.bad_epochs = 0                 # epochs without improvement (early stopping)
        self.nonfinite = 0
        self._nonfinite_streak = 0
        self.stop_reason = ""
        self.history_path = os.path.join(out_dir, "history.jsonl")

    # ------------------------------------------------------------------ #
    def _g(self) -> SynthesizerTrn:
        return self.net_g.module if isinstance(self.net_g, DDP) else self.net_g

    def _d(self):
        return self.net_d.module if isinstance(self.net_d, DDP) else self.net_d

    def _autocast(self):
        return torch.autocast("cuda", dtype=self.amp_dtype, enabled=self.use_amp)

    def _mel(self, wav: torch.Tensor) -> torch.Tensor:
        a = self.cfg.audio
        if wav.dim() == 3:
            wav = wav.squeeze(1)
        return mel_spectrogram_torch(wav, a.sample_rate, a.n_fft, a.hop_length, a.win_length,
                                     a.n_mels, a.mel_fmin, a.mel_fmax)

    def _spec_to_mel(self, spec: torch.Tensor) -> torch.Tensor:
        a = self.cfg.audio
        return spec_to_mel_torch(spec, a.sample_rate, a.n_fft, a.n_mels, a.mel_fmin, a.mel_fmax)

    # -- learning rate: linear warmup x exponential per-epoch decay ----------- #
    def current_lr(self) -> float:
        t = self.cfg.train
        lr = t.lr * (t.lr_decay ** self.epoch)
        warm = int(getattr(t, "lr_warmup_steps", 0))
        if warm > 0 and self.step < warm:
            lr *= (self.step + 1) / float(warm)
        return lr

    def _apply_lr(self) -> float:
        lr = self.current_lr()
        for opt in (self.optim_g, self.optim_d):
            for g in opt.param_groups:
                g["lr"] = lr
        return lr

    def _model_inputs(self, batch: dict, train: bool) -> dict:
        dev = self.device
        nb = lambda k: batch[k].to(dev, non_blocking=True)      # noqa: E731
        kw = dict(x=nb("x"), x_lengths=nb("x_lengths"), spec=nb("spec"),
                  spec_lengths=nb("spec_lengths"), sid=nb("sid"))
        g = self._g()
        if g.legacy:
            return kw
        kw["lang"] = nb("lang")
        kw["emotion"] = nb("emotion")
        kw["intensity"] = nb("intensity")
        b = kw["x"].size(0)
        s = self.cfg.style
        if "ref_spec" in batch and g.ref_enc is not None:
            kw["ref_mel"] = self._spec_to_mel(nb("ref_spec"))
            kw["ref_lengths"] = nb("ref_lengths")
            p = s.p_ref if train else 0.0
            kw["use_ref"] = torch.rand(b, device=dev) < p
        if train and s.cond_dropout > 0:
            kw["style_drop"] = torch.rand(b, device=dev) < s.cond_dropout
        return kw

    # ------------------------------------------------------------------ #
    def train_step(self, batch: dict) -> dict:
        a, t = self.cfg.audio, self.cfg.train
        lr = self._apply_lr()
        wav = batch["wav"].to(self.device, non_blocking=True)
        kw = self._model_inputs(batch, train=True)

        with self._autocast():
            (y_hat, l_length, attn, ids_slice, x_mask, z_mask,
             (z, z_p, m_p, logs_p, m_q, logs_q), extras) = self.net_g(**kw)
            mel = self._spec_to_mel(kw["spec"])
            y_mel = slice_segments(mel, ids_slice, t.segment_size)
            y = slice_segments(wav, ids_slice * a.hop_length, t.segment_size * a.hop_length)
            y_hat_mel = self._mel(y_hat.float())
            d_rs, d_gs, _, _ = self.net_d(y, y_hat.detach())
            loss_disc, _, _ = discriminator_loss(d_rs, d_gs)

        if not torch.isfinite(loss_disc):
            return self._skip_step("discriminator loss not finite")
        self.optim_d.zero_grad(set_to_none=True)
        self.scaler.scale(loss_disc).backward()
        self.scaler.unscale_(self.optim_d)
        gn_d = torch.nn.utils.clip_grad_norm_(self.net_d.parameters(), t.grad_clip)
        self.scaler.step(self.optim_d)

        with self._autocast():
            _, d_gs, f_rs, f_gs = self.net_d(y, y_hat)
            loss_mel = F.l1_loss(y_mel, y_hat_mel) * t.c_mel
            loss_dur = torch.sum(l_length.float()) * t.c_dur
            loss_kl = kl_loss(z_p, logs_q, m_p, logs_p, z_mask) * t.c_kl
            loss_fm = feature_matching_loss(f_rs, f_gs) * t.c_fm
            loss_adv = generator_adv_loss(d_gs)
            loss_gen = loss_adv + loss_fm + loss_mel + loss_dur + loss_kl
            stats_extra: Dict[str, float] = {}
            if "l_mf" in extras:
                loss_mf = extras["l_mf"].float() * self.cfg.prior.c_mf
                loss_gen = loss_gen + loss_mf
                stats_extra["mf"] = float(loss_mf.detach())
            if "l_spk" in extras:
                loss_spk = extras["l_spk"].float() * self.cfg.style.c_spk
                loss_gen = loss_gen + loss_spk
                stats_extra["spk"] = float(loss_spk.detach())
                stats_extra["spk_cos"] = float(extras["spk_cos"])

        if not torch.isfinite(loss_gen):
            return self._skip_step("generator loss not finite")
        self.optim_g.zero_grad(set_to_none=True)
        self.scaler.scale(loss_gen).backward()
        self.scaler.unscale_(self.optim_g)
        gn_g = torch.nn.utils.clip_grad_norm_(self.net_g.parameters(), t.grad_clip)
        self.scaler.step(self.optim_g)
        self.scaler.update()
        self._nonfinite_streak = 0

        out = {"loss_d": float(loss_disc.detach()), "loss_g": float(loss_gen.detach()),
               "mel": float(loss_mel.detach()), "dur": float(loss_dur.detach()),
               "kl": float(loss_kl.detach()), "fm": float(loss_fm.detach()),
               "adv": float(loss_adv.detach())}
        out.update(stats_extra)
        out.update({"grad_norm_g": float(gn_g), "grad_norm_d": float(gn_d), "lr": lr})
        return out

    def _skip_step(self, why: str) -> dict:
        self.optim_g.zero_grad(set_to_none=True)
        self.optim_d.zero_grad(set_to_none=True)
        self.nonfinite += 1
        self._nonfinite_streak += 1
        limit = int(getattr(self.cfg.train, "max_nonfinite_steps", 50))
        self.log.say(f"[trainer] step {self.step + 1} skipped: {why} "
                     f"({self._nonfinite_streak} in a row, {self.nonfinite} total)")
        if limit and self._nonfinite_streak >= limit:
            raise SystemExit(f"{limit} consecutive non-finite losses: lower --lr, add "
                             f"--lr-warmup-steps, check the data (silent/corrupt clips) or "
                             f"resume from the last good checkpoint.")
        return {"skipped": 1.0}

    # ------------------------------------------------------------------ #
    @torch.no_grad()
    def validate(self) -> Optional[dict]:
        """Teacher-forced mel L1 (+ MeanFlow loss) over the validation set
        (``eval_batches`` batches, 0 = all), per dataset and per language."""
        if self.val_loader is None:
            return None
        a, t = self.cfg.audio, self.cfg.train
        self.net_g.eval()
        total, total_mf, n = 0.0, 0.0, 0
        per_cat: Dict[str, list] = {}
        per_lang: Dict[str, list] = {}
        for i, batch in enumerate(self.val_loader):
            if t.eval_batches and i >= t.eval_batches:
                break
            wav = batch["wav"].to(self.device)
            kw = self._model_inputs(batch, train=False)
            y_hat, _, _, ids_slice, _, _, _, extras = self.net_g(**kw)
            y = slice_segments(wav, ids_slice * a.hop_length, t.segment_size * a.hop_length)
            per_item = F.l1_loss(self._mel(y_hat.float()), self._mel(y.float()),
                                 reduction="none").mean(dim=(1, 2))
            total += float(per_item.mean())
            for j, v in enumerate(per_item.tolist()):
                cat = batch.get("category", ["all"] * len(per_item))[j]
                lang = batch.get("language", [""] * len(per_item))[j]
                per_cat.setdefault(cat, []).append(v)
                if lang:
                    per_lang.setdefault(lang, []).append(v)
            if "l_mf" in extras:
                total_mf += float(extras["l_mf"])
            n += 1
        self.net_g.train()
        out = {"val_mel_l1": total / max(1, n)}
        if total_mf:
            out["val_mf"] = total_mf / max(1, n)
        if len(per_cat) > 1 or (per_cat and "all" not in per_cat):
            by_ds = {k: round(sum(v) / len(v), 4) for k, v in sorted(per_cat.items())}
            out["val_mel_l1_by_dataset"] = by_ds
            out["val_clips_by_dataset"] = {k: len(v) for k, v in sorted(per_cat.items())}
            out["val_worst_dataset"] = max(by_ds, key=by_ds.get)
        if len(per_lang) > 1:
            out["val_mel_l1_by_language"] = {k: round(sum(v) / len(v), 4) for k, v in sorted(per_lang.items())}
        return out

    @torch.no_grad()
    def synthesize_samples(self, tag: str = "") -> None:
        """A few validation utterances end to end, one per corpus first."""
        if (not is_main_process() or self.val_dataset is None
                or self.tokenizer is None or not self.val_dataset.items):
            return
        g = self._g()
        g.eval()
        a = self.cfg.audio
        n = min(self.cfg.train.n_val_samples, len(self.val_dataset.items))
        seen, chosen = set(), []
        for it in self.val_dataset.items:
            if it[6] not in seen:
                seen.add(it[6])
                chosen.append(it)
            if len(chosen) >= n:
                break
        for it in self.val_dataset.items:
            if len(chosen) >= n:
                break
            if it not in chosen:
                chosen.append(it)
        for i, item in enumerate(chosen):
            _path, norm_text, spk_id, emo, inten, lang, _cat = item
            ids, lids = self.tokenizer.encode_full(
                norm_text, self.cfg.text.intersperse_blank, default_language=lang,
                detect_languages=self.cfg.text.language_detection)
            if not ids:
                continue
            x = torch.LongTensor(ids).unsqueeze(0).to(self.device)
            x_lengths = torch.LongTensor([x.size(1)]).to(self.device)
            sid = torch.LongTensor([spk_id]).to(self.device)
            kw = {}
            if not g.legacy:
                kw = dict(lang=torch.LongTensor(lids).unsqueeze(0).to(self.device),
                          emotion=torch.LongTensor([emo]).to(self.device),
                          intensity=torch.tensor([inten]).to(self.device))
            try:
                y, _, _ = g.infer(x, x_lengths, sid=sid, **kw)
                stem = tag or f"epoch{self.epoch:04d}"
                save_wav(os.path.join(self.out_dir, "samples", f"{stem}_{i}_{_cat}.wav"),
                         y.squeeze().float().cpu().numpy(), a.sample_rate)
            except Exception as e:                            # noqa: BLE001
                self.log.say(f"[trainer] sample synthesis failed: {e}")
        g.train()

    # ------------------------------------------------------------------ #
    def save_checkpoint(self, name: str = "checkpoint.pt", mid_epoch: bool = False) -> None:
        if not is_main_process():
            return
        torch.save({
            "epoch": self.epoch, "step": self.step, "best_val": self.best_val,
            "best_epoch": self.best_epoch, "bad_epochs": self.bad_epochs,
            "nonfinite": self.nonfinite, "elapsed_s": self.global_elapsed(),
            "mid_epoch": mid_epoch, "model_version": self.cfg.model.version,
            "net_g": self._g().state_dict(), "net_d": self._d().state_dict(),
            "optim_g": self.optim_g.state_dict(), "optim_d": self.optim_d.state_dict(),
            "scaler": self.scaler.state_dict(),
        }, os.path.join(self.out_dir, name))
        torch.save(self._g().inference_state_dict(), os.path.join(self.out_dir, "model.pt"))

    def _init_from_pretrained(self, path: str) -> None:
        """Warm-start from another run (folder or .pt): every matching tensor,
        text-embedding rows by symbol, speaker rows by name; fresh optimizer."""
        init_dir = path if os.path.isdir(path) else os.path.dirname(path)
        if os.path.isdir(path):
            for cand in ("best.pt", "checkpoint.pt", "model.pt"):
                fp = os.path.join(path, cand)
                if os.path.isfile(fp):
                    path = fp
                    break
        ckpt = torch.load(path, map_location="cpu", weights_only=False)
        g_sd = ckpt.get("net_g", ckpt if isinstance(ckpt, dict) else None)
        if g_sd is None:
            raise RuntimeError(f"no generator weights found in {path!r}")

        def transfer(module, src_sd, label):
            if src_sd is None:
                return
            dst = module.state_dict()
            keep = {k: v for k, v in src_sd.items() if k in dst and dst[k].shape == v.shape}
            skipped = sorted(set(src_sd) - set(keep))
            module.load_state_dict(keep, strict=False)
            msg = f"[trainer] init-from {os.path.basename(path)}: {label} loaded {len(keep)}/{len(dst)} tensors"
            if skipped:
                heads = sorted({k.split('.')[0] for k in skipped})
                msg += f", skipped {len(skipped)} ({', '.join(heads)})"
            self.log.say(msg)

        transfer(self._g(), g_sd, "generator")
        transfer(self._d(), ckpt.get("net_d"), "discriminator")
        key = "enc_p.emb.weight"
        if key in g_sd and self.tokenizer is not None:
            src_emb, dst_emb = g_sd[key], self._g().enc_p.emb.weight
            tok_path = os.path.join(init_dir, "tokenizer.json")
            if src_emb.shape != dst_emb.shape and os.path.isfile(tok_path):
                try:
                    src_syms = json.load(open(tok_path, encoding="utf-8"))["symbols"]
                    with torch.no_grad():
                        n = 0
                        for i, sym in enumerate(src_syms):
                            j = self.tokenizer.sym2id.get(sym)
                            if j is not None and i < src_emb.shape[0]:
                                dst_emb[j].copy_(src_emb[i])
                                n += 1
                    self.log.say(f"[trainer] init-from vocabulary: {n} symbol embeddings carried over, "
                                 f"{dst_emb.shape[0] - n} new symbols fresh")
                except Exception as exc:                     # noqa: BLE001
                    self.log.say(f"[trainer] vocabulary transfer skipped: {exc}")
        mode = getattr(self.cfg.train, "init_speaker_mode", "mean")
        if mode == "mean" and "emb_g.weight" in g_sd and hasattr(self._g(), "emb_g"):
            src_emb, dst_emb = g_sd["emb_g.weight"], self._g().emb_g.weight
            if src_emb.shape != dst_emb.shape and src_emb.shape[1] == dst_emb.shape[1]:
                src_map, dst_map = {}, {}
                try:
                    sp = os.path.join(init_dir, "speakers.json")
                    if os.path.isfile(sp):
                        src_map = {n: e["id"] for n, e in json.load(open(sp, encoding="utf-8")).items()}
                    dp = os.path.join(self.out_dir, "speakers.json")
                    if os.path.isfile(dp):
                        dst_map = {n: e["id"] for n, e in json.load(open(dp, encoding="utf-8")).items()}
                except Exception:                            # noqa: BLE001
                    src_map, dst_map = {}, {}
                with torch.no_grad():
                    dst_emb.copy_(src_emb.mean(dim=0, keepdim=True).expand_as(dst_emb))
                    carried = 0
                    for name, new_id in dst_map.items():
                        old_id = src_map.get(name)
                        if old_id is not None and old_id < src_emb.shape[0] and new_id < dst_emb.shape[0]:
                            dst_emb[new_id].copy_(src_emb[old_id])
                            carried += 1
                self.log.say(f"[trainer] init-from speakers: {carried} returning voice(s) kept their "
                             f"trained embeddings, {dst_emb.shape[0] - carried} new voice(s) "
                             f"initialized from the mean of {src_emb.shape[0]} pretrained voices")
        if ckpt.get("model_version", 1) < self.cfg.model.version:
            self.log.say("[trainer] upgrading a v1 checkpoint to ALTATTS 2: the style encoder, "
                         "language embeddings and MeanFlow prior start fresh.")

    def load_checkpoint(self, path: str) -> None:
        ckpt = torch.load(path, map_location=self.device, weights_only=False)
        try:
            self._g().load_state_dict(ckpt["net_g"])
        except RuntimeError as exc:
            raise SystemExit(
                f"cannot resume from {path}: the checkpoint was trained with a different model "
                f"(speaker table, vocabulary or preset).\n  - to continue THAT run, use the same "
                f"data and config;\n  - to start a new run, pass a new --out folder (or delete "
                f"the old one);\n  - to transfer its weights into this model, use --init-from "
                f"instead.\n  ({str(exc).splitlines()[0][:160]})") from None
        try:
            self._d().load_state_dict(ckpt["net_d"])
        except RuntimeError:
            # 0.1 checkpoints parametrise the scale discriminator with spectral
            # norm; load what matches and let the rest re-train
            missing, unexpected = self._d().load_state_dict(ckpt["net_d"], strict=False)
            self.log.say(f"[trainer] discriminator partially restored ({len(missing)} tensors "
                         f"re-initialised: 0.1 checkpoint layout)")
        self.optim_g.load_state_dict(ckpt["optim_g"])
        self.optim_d.load_state_dict(ckpt["optim_d"])
        try:
            self.scaler.load_state_dict(ckpt["scaler"])
        except Exception:                                    # noqa: BLE001
            pass
        self.epoch = int(ckpt["epoch"]) + (0 if ckpt.get("mid_epoch") else 1)
        self.step = int(ckpt["step"])
        self.best_val = float(ckpt.get("best_val", math.inf))
        self.best_epoch = int(ckpt.get("best_epoch", -1))
        self.bad_epochs = int(ckpt.get("bad_epochs", 0))
        self.nonfinite = int(ckpt.get("nonfinite", 0))
        self.prior_elapsed = float(ckpt.get("elapsed_s", 0.0))
        self.log.say(f"[trainer] resumed from {path} (epoch {self.epoch}, step {self.step}, "
                     f"best val {self.best_val:.4f} at epoch {self.best_epoch}, prior time "
                     f"{_fmt_dur(self.prior_elapsed)})")

    # ------------------------------------------------------------------ #
    def global_elapsed(self) -> float:
        return self.prior_elapsed + (time.time() - self.fit_start)

    def _should_stop(self, val: Optional[dict]) -> str:
        """Early-stopping / time-budget decision (rank 0), broadcast to all ranks."""
        t = self.cfg.train
        reason = ""
        if is_main_process():
            metric_name = getattr(t, "early_stop_metric", "val_mel_l1")
            patience = int(getattr(t, "early_stop_patience", 0))
            if patience > 0 and val and val.get(metric_name) is not None:
                if self.bad_epochs >= patience:
                    reason = (f"early stopping: no improvement of {metric_name} by more than "
                              f"{t.early_stop_min_delta} for {patience} epochs "
                              f"(best {self.best_val:.4f} at epoch {self.best_epoch})")
            max_hours = float(getattr(t, "max_hours", 0.0) or 0.0)
            if max_hours > 0 and self.global_elapsed() >= max_hours * 3600:
                reason = f"time budget reached ({max_hours} h)"
        if ddp_active():
            import torch.distributed as dist
            flag = torch.tensor([1 if reason else 0], device=self.device if self.device.type == "cuda" else "cpu")
            dist.broadcast(flag, src=0)
            if int(flag.item()) and not reason:
                reason = "stopped by rank 0"
        return reason

    def _update_best(self, val: Optional[dict]) -> bool:
        """Track the early-stopping metric; returns True when it improved."""
        t = self.cfg.train
        metric_name = getattr(t, "early_stop_metric", "val_mel_l1")
        if not val or val.get(metric_name) is None:
            return False
        v = float(val[metric_name])
        if v < self.best_val - float(getattr(t, "early_stop_min_delta", 0.0)):
            self.best_val, self.best_epoch, self.bad_epochs = v, self.epoch, 0
            return True
        self.bad_epochs += 1
        return False

    def fit(self) -> None:
        t = self.cfg.train
        self.prior_elapsed = getattr(self, "prior_elapsed", 0.0)
        self.fit_start = time.time()
        step_ckpt = os.path.join(self.out_dir, "checkpoint_step.pt")
        epoch_ckpt = os.path.join(self.out_dir, "checkpoint.pt")

        resume_path = t.resume
        if not resume_path:
            candidates = [p for p in (epoch_ckpt, step_ckpt) if os.path.isfile(p)]
            if candidates:
                resume_path = max(candidates, key=os.path.getmtime)
        if resume_path and os.path.isfile(resume_path):
            self.load_checkpoint(resume_path)
            self.fit_start = time.time()
        elif getattr(t, "init_from", ""):
            self._init_from_pretrained(t.init_from)

        steps_per_epoch = len(self.sampler)
        step_every = int(getattr(t, "step_checkpoint_every", 0))
        log_every = max(1, int(getattr(t, "log_every", 50)))
        patience = int(getattr(t, "early_stop_patience", 0))
        sr = self.cfg.audio.sample_rate

        self.log.say(f"[trainer] device={self.device} amp="
                     f"{'off' if not self.use_amp else str(self.amp_dtype).split('.')[-1]} "
                     f"world={ddp_world_size()} steps/epoch={steps_per_epoch} "
                     f"lr={t.lr} warmup={getattr(t, 'lr_warmup_steps', 0)} steps "
                     f"early-stop={'off' if not patience else f'patience {patience} on {t.early_stop_metric} (min delta {t.early_stop_min_delta})'}"
                     + (f" max_hours={t.max_hours}" if getattr(t, 'max_hours', 0) else ""))
        if t.num_workers > 0:
            self.log.say(f"[trainer] starting {t.num_workers} data workers (spawn) -- the first "
                         f"batch can take a minute while workers initialize...")
        first_batch_t0, first_batch_seen = time.time(), False
        total_steps = steps_per_epoch * t.epochs
        self.log.status(state="training", epoch=self.epoch, step=self.step,
                        steps_per_epoch=steps_per_epoch, epochs=t.epochs, total_steps=total_steps,
                        early_stop={"patience": patience, "bad_epochs": self.bad_epochs,
                                    "metric": t.early_stop_metric})
        table = StepTable(self.log.say)
        # throughput window: from the first batch of THIS run (after the
        # pipeline warm-up), exactly like ALTASR's RunControl
        run_t0, steps_at_t0, run_audio_s = None, self.step, 0.0

        def rate():
            dt = max(1e-6, time.time() - run_t0) if run_t0 else 0.0
            sps = (self.step - steps_at_t0) / dt if dt else 0.0
            return sps, (run_audio_s / dt if dt else 0.0)

        def eta_total(sps: float) -> Optional[float]:
            return (max(0, total_steps - self.step) / sps) if sps > 0 else None

        self.net_g.train()
        self.net_d.train()
        for epoch in range(self.epoch, t.epochs):
            self.epoch = epoch
            self.sampler.set_epoch(epoch)
            epoch_stats, n_batches, n_clips, audio_s = {}, 0, 0, 0.0
            t0 = time.time()
            t_last = time.time()
            for batch in self.train_loader:
                if not first_batch_seen:
                    first_batch_seen = True
                    self.log.say(f"[trainer] pipeline warm: first batch after "
                                 f"{_fmt_dur(time.time() - first_batch_t0)}")
                    run_t0, steps_at_t0 = time.time(), self.step
                stats = self.train_step(batch)
                self.step += 1
                n_batches += 1
                n_clips += int(batch["x"].size(0))
                batch_audio_s = float(batch["wav_lengths"].sum()) / sr
                audio_s += batch_audio_s
                run_audio_s += batch_audio_s
                for k, v in stats.items():
                    epoch_stats[k] = epoch_stats.get(k, 0.0) + v

                # the first step of every epoch always logs (a slow-step run
                # must never look hung); then every log_every steps
                if n_batches == 1 or self.step % log_every == 0:
                    now = time.time()
                    dt = max(1e-6, now - t_last)
                    t_last = now
                    ep_elapsed = now - t0
                    remaining = max(0, steps_per_epoch - n_batches)
                    ep_eta = (ep_elapsed / max(1, n_batches)) * remaining
                    sps, xrt = rate()
                    eta = eta_total(sps)
                    mem_gb = None
                    extra = {"clips_per_s": round(n_clips / max(1e-6, ep_elapsed), 2),
                             "audio_s_per_s": round(xrt, 1), "steps_per_s": round(sps, 3),
                             "step_time_s": round(dt / (1 if n_batches == 1 else log_every), 3)}
                    if self.device.type == "cuda":
                        mem_gb = torch.cuda.max_memory_allocated(self.device) / 2**30
                        extra["gpu_mem_gb"] = round(mem_gb, 2)
                    if self.nonfinite:
                        extra["nonfinite"] = self.nonfinite
                    self.log.step(self.step, epoch, {**stats, **extra})
                    table.emit(epoch=epoch, in_epoch=n_batches, steps_per_epoch=steps_per_epoch,
                               step=self.step, total_steps=total_steps, stats=stats,
                               steps_per_s=sps, xrt=xrt, mem_gb=mem_gb,
                               elapsed_s=self.global_elapsed(), eta_s=eta)
                    self.log.status(epoch=epoch, step=self.step, lr=stats.get("lr"), last=stats,
                                    throughput=extra, elapsed=_fmt_dur(self.global_elapsed()),
                                    progress=round(100.0 * self.step / max(1, total_steps), 2),
                                    eta_epoch=_fmt_dur(ep_eta),
                                    eta_total=(_fmt_dur(eta) if eta is not None else None),
                                    best_val=(None if self.best_val == math.inf else round(self.best_val, 4)),
                                    best_epoch=self.best_epoch,
                                    early_stop={"patience": patience, "bad_epochs": self.bad_epochs,
                                                "metric": t.early_stop_metric})
                if step_every > 0 and self.step % step_every == 0:
                    self.save_checkpoint("checkpoint_step.pt", mid_epoch=True)
                    self.synthesize_samples(tag="latest_step")
                    self.log.say(f"[trainer] rolling checkpoint + samples saved at step {self.step}")

            avg = {k: v / max(1, n_batches) for k, v in epoch_stats.items()}
            val = self.validate()
            improved = self._update_best(val)
            epoch_seconds = time.time() - t0
            avg.update({"epoch": epoch, "step": self.step, "lr": self.current_lr(),
                        "epoch_seconds": round(epoch_seconds, 1),
                        "total_seconds": round(self.global_elapsed(), 1),
                        "clips_per_s": round(n_clips / max(1e-6, epoch_seconds), 2),
                        "nonfinite": self.nonfinite})
            val_mel = None
            if val is not None:
                avg.update(val)
                val_mel = val["val_mel_l1"]
                avg.update({"improved": improved, "best_val": (None if self.best_val == math.inf else self.best_val),
                            "best_epoch": self.best_epoch, "bad_epochs": self.bad_epochs})
            self.log.epoch(avg)

            if improved:
                self.save_checkpoint("best.pt")
            if (epoch + 1) % t.checkpoint_every == 0 or epoch == t.epochs - 1:
                self.save_checkpoint()
                self.synthesize_samples()
            if is_main_process() and os.path.isfile(step_ckpt):
                try:
                    os.remove(step_ckpt)
                except OSError:
                    pass

            epochs_left = t.epochs - (epoch + 1)
            sps, _ = rate()
            eta = eta_total(sps)
            if eta is None:
                eta = epoch_seconds * epochs_left
            title = (f"epoch {epoch + 1}/{t.epochs} done in {_fmt_dur(epoch_seconds)} · "
                     f"elapsed {_fmt_dur(self.global_elapsed())} · "
                     f"ETA {_fmt_dur(eta)} ({epochs_left} epoch(s) left)")
            lines = [f"train: gen {avg.get('loss_g', 0):.3f}  mel {avg.get('mel', 0):.3f}  "
                     f"kl {avg.get('kl', 0):.3f}  dur {avg.get('dur', 0):.3f}"
                     + (f"  mf {avg['mf']:.3f}" if "mf" in avg else "")
                     + f"  disc {avg.get('loss_d', 0):.3f}  |  {avg['clips_per_s']} clips/s"
                     + (f"  |  {self.nonfinite} non-finite step(s) skipped" if self.nonfinite else "")]
            if val_mel is not None:
                verdict = ("BEST so far" if improved else
                           f"no gain for {self.bad_epochs}" + (f"/{patience}" if patience else "") + " epoch(s)")
                best_txt = ("" if self.best_val == math.inf else
                            f"   best {self.best_val:.4f} @ epoch {self.best_epoch + 1}")
                lines.append(f"val_mel_l1 {val_mel:.4f} ({verdict}){best_txt}"
                             + (f"   val_mf {val['val_mf']:.3f}" if val.get("val_mf") is not None else ""))
            if val and val.get("val_mel_l1_by_dataset"):
                counts = val.get("val_clips_by_dataset", {})
                by_ds = val["val_mel_l1_by_dataset"]
                best = min(by_ds.values())
                worst = val.get("val_worst_dataset")
                lines.append("")
                lines.append(f"{'validation error by dataset':<30}{'mel L1':>8}{'vs best':>9}{'clips':>7}   (lower is better)")
                for k, v in sorted(by_ds.items(), key=lambda kv: kv[1]):
                    flag = "   <- worst" if k == worst and len(by_ds) > 1 else ""
                    lines.append(f"{k:<30}{v:>8.4f}{v - best:>+9.3f}{counts.get(k, 0):>7}{flag}")
                if val.get("val_mel_l1_by_language"):
                    lines.append("by language: " + "  ".join(
                        f"{k} {v:.4f}" for k, v in val["val_mel_l1_by_language"].items()))
            self.log.say(box(title, lines))
            self.log.status(epoch=epoch + 1, step=self.step, val=val, best_val=(None if self.best_val == math.inf else round(self.best_val, 4)),
                            best_epoch=self.best_epoch, elapsed=_fmt_dur(self.global_elapsed()),
                            early_stop={"patience": patience, "bad_epochs": self.bad_epochs,
                                        "metric": t.early_stop_metric})
            reason = self._should_stop(val)
            if reason:
                self.stop_reason = reason
                self.log.say(f"[trainer] stopping: {reason}")
                break
        self.save_checkpoint()
        self.finalize()
        state = "early-stopped" if "early" in self.stop_reason else ("time-budget" if "budget" in self.stop_reason else "finished")
        self.log.status(state=state, stop_reason=self.stop_reason, elapsed=_fmt_dur(self.global_elapsed()))
        self.log.say(f"[trainer] {state} in {_fmt_dur(self.global_elapsed())}. best val_mel_l1 "
                     f"{self.best_val:.4f} at epoch {self.best_epoch} (best.pt); checkpoints in {self.out_dir}")
        self.log.close()

    # ------------------------------------------------------------------ #
    def finalize(self) -> None:
        if not is_main_process():
            return
        summary = {"model_version": self.cfg.model.version, "steps": self.step,
                   "epochs": self.epoch + 1, "best_val_mel_l1": self.best_val,
                   "best_epoch": self.best_epoch, "stop_reason": self.stop_reason,
                   "train_clips": len(self.train_dataset),
                   "train_hours": round(sum(self.train_dataset.durations) / 3600, 2),
                   "languages": list(self.cfg.text.languages),
                   "n_speakers": len(self.speakers) if self.speakers else None,
                   "nonfinite_steps": self.nonfinite}
        emo_counts: Dict[str, int] = {}
        for it in self.train_dataset.items:
            name = "unlabeled" if it[3] == 0 else self.cfg.style.emotions[it[3] - 1]
            emo_counts[name] = emo_counts.get(name, 0) + 1
        summary["emotion_counts"] = emo_counts
        with open(os.path.join(self.out_dir, "training_summary.json"), "w", encoding="utf-8") as fh:
            json.dump(summary, fh, indent=2, ensure_ascii=False)
        g = self._g()
        if g.legacy or not self.cfg.train.build_default_voices:
            return
        try:
            from .anonymize import build_default_voices
            build_default_voices(g, self.cfg, self.speakers, self.tokenizer, self.out_dir,
                                 dataset=self.train_dataset, device=self.device, verbose=True)
        except Exception as exc:                             # noqa: BLE001
            self.log.say(f"[trainer] default-voice builder failed ({exc}); run "
                         f"`altatts voices build --model {self.out_dir}` later.")
