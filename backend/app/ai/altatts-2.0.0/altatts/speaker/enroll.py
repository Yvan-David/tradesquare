"""
Speaker enrollment: a few seconds of someone's voice -> a style vector that
the model speaks with, no training required.

How cloning works in ALTATTS 2
------------------------------
The model's reference encoder was trained to map a log-mel spectrogram of a
speaker to the same embedding space as the trained speaker table (it is
regressed onto the table rows and used as the decoder's conditioning half of
the time). At enrollment we therefore:

1. decode and clean the reference audio (any format / rate; silence trimmed,
   peak normalized) -- several clips are better than one;
2. cut it into windows of a few seconds, embed each window, and **average**
   the embeddings (averaging over windows and clips is what speaker-
   verification systems do to get a stable identity vector; it also removes
   content and prosody specifics of any single sentence);
3. optionally **adapt** the vector with a few hundred gradient steps on the
   enrollment clips when transcripts are available (``adapt_steps > 0``):
   only the embedding is optimised, every network weight stays frozen, so
   it takes minutes on a CPU and cannot damage the model;
4. store it in ``voices.json`` under a name (``Synthesizer.enroll_speaker``,
   ``altatts-enroll``). The gender is detected from pitch when not given.

Quality scales with the speaker diversity the model was trained on; with a
handful of training speakers use ``adapt_steps`` (few-shot) rather than pure
zero-shot.
"""
from __future__ import annotations

import os
from typing import Dict, Iterable, List, Optional, Sequence, Tuple, Union

import numpy as np
import torch

from ..audio import (AudioDecodeError, load_audio, mel_spectrogram_torch,
                     peak_normalize, resample, spectrogram_torch, trim_silence)
from ..config import Config
from ..metrics import gender_from_f0

AudioLike = Union[str, os.PathLike, np.ndarray, Tuple[np.ndarray, int]]


def load_reference_audio(audio: AudioLike, target_sr: int,
                         sample_rate: Optional[int] = None,
                         trim_db: float = 35.0) -> np.ndarray:
    """Path / array / (array, sr) -> mono float32 at ``target_sr``, trimmed
    and peak-normalized like training audio."""
    if isinstance(audio, tuple):
        wav, sr = audio
        wav = np.asarray(wav, dtype=np.float32).reshape(-1)
        wav = resample(wav, int(sr), target_sr)
    elif isinstance(audio, np.ndarray):
        wav = np.asarray(audio, dtype=np.float32).reshape(-1)
        if sample_rate and sample_rate != target_sr:
            wav = resample(wav, int(sample_rate), target_sr)
    elif torch.is_tensor(audio):
        wav = audio.detach().float().cpu().numpy().reshape(-1)
        if sample_rate and sample_rate != target_sr:
            wav = resample(wav, int(sample_rate), target_sr)
    else:
        wav = load_audio(os.fspath(audio), target_sr)
    wav = trim_silence(wav, target_sr, trim_db)
    return peak_normalize(wav, 0.95)


@torch.no_grad()
def embed_speaker_audio(model, cfg: Config, audios: Iterable[AudioLike],
                        device=None, sample_rate: Optional[int] = None,
                        window_s: float = 4.0, hop_s: float = 2.0,
                        return_windows: bool = False):
    """Average reference-encoder embedding over all windows of all clips.

    Returns (embedding (gin,), info) -- ``info`` has the number of clips and
    windows, total seconds and the pitch-based gender guess."""
    if not getattr(model, "has_cloning", False):
        raise RuntimeError(
            "this model has no speaker encoder (ALTATTS 0.1 checkpoint or "
            "trained with style.speaker_encoder='none'); voice cloning needs "
            "an ALTATTS 2 model -- fine-tune with `altatts-train --init-from "
            "<this folder>` to upgrade it.")
    device = device or next(model.parameters()).device
    a = cfg.audio
    sr = a.sample_rate
    win = int(window_s * sr)
    hop = int(hop_s * sr)
    embs: List[np.ndarray] = []
    f0_wavs: List[np.ndarray] = []
    total_s, n_clips = 0.0, 0
    for item in audios:
        try:
            wav = load_reference_audio(item, sr, sample_rate, cfg.data.trim_db)
        except (AudioDecodeError, OSError) as exc:
            raise AudioDecodeError(str(item), {"reference": str(exc)})
        if len(wav) < sr // 2:
            continue
        n_clips += 1
        total_s += len(wav) / sr
        f0_wavs.append(wav[: 20 * sr])
        starts = list(range(0, max(1, len(wav) - win + 1), hop)) or [0]
        if len(wav) > win and (len(wav) - win) % hop:
            starts.append(len(wav) - win)
        for s in starts[:32]:
            seg = wav[s: s + win]
            if len(seg) < sr // 2:
                continue
            y = torch.from_numpy(np.ascontiguousarray(seg)).unsqueeze(0).to(device)
            mel = mel_spectrogram_torch(y, sr, a.n_fft, a.hop_length, a.win_length,
                                        a.n_mels, a.mel_fmin, a.mel_fmax)
            embs.append(model.embed_reference(mel).squeeze(0).float().cpu().numpy())
    if not embs:
        raise ValueError("reference audio too short: need at least ~1 s of speech")
    emb = np.mean(np.stack(embs), axis=0).astype(np.float32)
    gender = None
    if f0_wavs:
        cat = np.concatenate(f0_wavs)
        gender = gender_from_f0(resample(cat, sr, 16000), 16000)
    info = {"n_clips": n_clips, "n_windows": len(embs),
            "seconds": round(total_s, 2), "gender_detected": gender}
    if return_windows:
        info["windows"] = np.stack(embs)
    return emb, info


def adapt_embedding(model, cfg: Config, tokenizer, clips: Sequence[Tuple[AudioLike, str]],
                    init: np.ndarray, steps: int = 300, lr: float = 2e-2,
                    device=None, verbose: bool = True,
                    folder: Optional[str] = None) -> np.ndarray:
    """Few-shot refinement: optimise ONLY the style vector on (audio, text)
    pairs with the teacher-forced generator losses (mel + KL + duration +
    MeanFlow). All network weights stay frozen."""
    from ..audio import spec_to_mel_torch
    from ..model.losses import kl_loss
    from ..model.modules import slice_segments
    from ..text import normalize_text
    import torch.nn.functional as F
    device = device or next(model.parameters()).device
    a, tc = cfg.audio, cfg.text
    model.eval()
    if folder is not None:
        from ..inference.checkpoint import ensure_posterior_weights
        if not ensure_posterior_weights(model, folder):
            raise RuntimeError(
                "few-shot adaptation needs the posterior encoder, which "
                "model.pt does not contain: keep checkpoint.pt or best.pt in "
                f"{folder!r} (or use adapt_steps=0 for zero-shot enrollment)")
        model.to(device)
    data = []
    for audio, text in clips:
        wav = load_reference_audio(audio, a.sample_rate, None, cfg.data.trim_db)
        norm = normalize_text(text, tc.keep_punctuation, tc.punctuation, tc.expand_numbers,
                              transliterate_foreign=tc.transliterate_foreign,
                              languages=tc.languages, detect_languages=tc.language_detection)
        ids, lids = tokenizer.encode_full(norm, tc.intersperse_blank,
                                          detect_languages=tc.language_detection)
        y = torch.from_numpy(wav).unsqueeze(0)
        spec = spectrogram_torch(y, a.n_fft, a.hop_length, a.win_length)
        y = y[:, : spec.size(2) * a.hop_length]
        data.append((torch.LongTensor(ids), torch.LongTensor(lids), spec, y))
    if not data:
        return init
    g = torch.nn.Parameter(torch.from_numpy(np.asarray(init, dtype=np.float32)).to(device))
    opt = torch.optim.Adam([g], lr=lr)
    frozen = [p for p in model.parameters() if p.requires_grad]
    for p in frozen:
        p.requires_grad_(False)
    seg = cfg.train.segment_size
    for step in range(steps):
        ids, lids, spec, y = data[step % len(data)]
        x = ids.unsqueeze(0).to(device)
        xl = torch.LongTensor([x.size(1)]).to(device)
        lang = lids.unsqueeze(0).to(device)
        spec_d, y_d = spec.to(device), y.to(device)
        sl = torch.LongTensor([spec_d.size(2)]).to(device)
        gg = g.view(1, -1, 1)
        h, m_p, logs_p, x_mask = model.enc_p(x, xl, lang)
        z, m_q, logs_q, y_mask = model.enc_q(spec_d, sl, g=gg)
        z_p = model.flow(z, y_mask, g=gg)
        with torch.no_grad():
            import math
            from ..model.monotonic_align import maximum_path
            s_p_sq_r = torch.exp(-2.0 * logs_p)
            neg1 = torch.sum(-0.5 * math.log(2 * math.pi) - logs_p, dim=1, keepdim=True)
            neg2 = torch.matmul(-0.5 * (z_p ** 2).transpose(1, 2), s_p_sq_r)
            neg3 = torch.matmul(z_p.transpose(1, 2), m_p * s_p_sq_r)
            neg4 = torch.sum(-0.5 * (m_p ** 2) * s_p_sq_r, dim=1, keepdim=True)
            attn = maximum_path(neg1 + neg2 + neg3 + neg4, y_mask.transpose(1, 2) * x_mask)
        w = attn.sum(1, keepdim=True)
        logw = model.dp(h, x_mask, g=gg)
        l_dur = torch.sum((logw - torch.log(w + 1e-6) * x_mask) ** 2) / torch.sum(xl)
        m_p_e = torch.matmul(attn, m_p.transpose(1, 2)).transpose(1, 2)
        logs_p_e = torch.matmul(attn, logs_p.transpose(1, 2)).transpose(1, 2)
        l_kl = kl_loss(z_p, logs_q, m_p_e, logs_p_e, y_mask)
        z_slice, ids_slice = (z[:, :, :seg], torch.zeros(1, dtype=torch.long, device=device)) \
            if z.size(2) <= seg else (None, None)
        if z_slice is None:
            start = int(torch.randint(0, z.size(2) - seg + 1, (1,)))
            ids_slice = torch.LongTensor([start]).to(device)
            z_slice = z[:, :, start:start + seg]
        y_hat = model.dec(z_slice, g=gg)
        y_true = slice_segments(y_d.unsqueeze(0), ids_slice * a.hop_length, seg * a.hop_length)
        mel_hat = spec_to_mel_torch(spectrogram_torch(y_hat.squeeze(1), a.n_fft, a.hop_length, a.win_length),
                                    a.sample_rate, a.n_fft, a.n_mels, a.mel_fmin, a.mel_fmax)
        mel_true = spec_to_mel_torch(spectrogram_torch(y_true.squeeze(1), a.n_fft, a.hop_length, a.win_length),
                                     a.sample_rate, a.n_fft, a.n_mels, a.mel_fmin, a.mel_fmax)
        loss = F.l1_loss(mel_hat, mel_true) * cfg.train.c_mel + l_kl * cfg.train.c_kl + l_dur
        if model.has_meanflow:
            from ..model.meanflow import meanflow_loss
            l_mf, _ = meanflow_loss(model.prior, z, torch.cat([m_p_e, logs_p_e], 1), y_mask, g.unsqueeze(0),
                                    ratio=0.0, adaptive_p=0.0)
            loss = loss + l_mf
        opt.zero_grad()
        loss.backward()
        opt.step()
        if verbose and (step % 50 == 0 or step == steps - 1):
            print(f"[enroll] adapt step {step + 1}/{steps} loss={float(loss):.3f}")
    for p in frozen:
        p.requires_grad_(True)
    return g.detach().float().cpu().numpy()


def enroll_speaker(synth, name: str, audios: Sequence[AudioLike],
                   gender: Optional[str] = None, age_group: Optional[str] = None,
                   save: bool = True, adapt_steps: int = 0,
                   texts: Optional[Sequence[str]] = None,
                   sample_rate: Optional[int] = None, **meta) -> Dict:
    """Embed ``audios``, optionally adapt, store under ``name`` in the
    synthesizer's voice bank (and voices.json when ``save``)."""
    audios = list(audios)
    emb, info = embed_speaker_audio(synth.model, synth.cfg, audios, synth.device,
                                    sample_rate=sample_rate)
    if adapt_steps > 0:
        if not texts or len(texts) != len(audios):
            raise ValueError("adapt_steps > 0 needs one transcript per clip "
                             "(texts=[...]) -- or use adapt_steps=0 (zero-shot)")
        emb = adapt_embedding(synth.model, synth.cfg, synth.tokenizer,
                              list(zip(audios, texts)), emb, steps=adapt_steps,
                              device=synth.device, folder=synth.folder)
    entry = synth.voice_bank.add(
        name, emb, kind="enrolled",
        gender=gender or info.get("gender_detected") or "unknown",
        age_group=age_group,
        source=[os.fspath(a) for a in audios if isinstance(a, (str, os.PathLike))],
        seconds=info["seconds"], n_clips=info["n_clips"],
        adapted_steps=adapt_steps or None, **meta)
    if save and synth.folder:
        synth.voice_bank.save(synth.folder)
    return {k: v for k, v in entry.items() if k != "embedding"}
