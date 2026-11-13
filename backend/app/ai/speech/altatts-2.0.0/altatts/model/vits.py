"""
The ALTATTS synthesizer: a multi-speaker VITS backbone (Kim, Kong & Son,
2021) extended -- in ALTATTS 2 -- with a zero-shot style encoder, per-
character language ids and a MeanFlow latent prior.

Why this architecture
---------------------
* **Single-stage, end-to-end.** Text -> waveform in one jointly trained
  network (no mel vocoder mismatch), synthesized in one parallel pass.
* **Learns its own alignment (MAS).** No forced aligner, no phoneme
  durations: an ASR corpus (audio + transcript) is enough. The deterministic
  duration predictor + monotonic alignment is also what makes the model
  *robust*: it cannot skip or repeat words the way attention-based
  autoregressive TTS can -- essential for call-center word error rates.
* **Natural prosody from a learned joint prior.** v2 replaces the frame-wise
  Gaussian + volume-preserving flow at inference with a transformer trained
  by MeanFlow (Geng et al. 2025): the whole utterance's latent is generated
  jointly in 1-4 steps, conditioned on the aligned text prior and the style
  vector. The VITS flow + KL stay in training (they drive MAS) and remain
  available as a fallback (``prior="flow"``).
* **Style = speaker + emotion.** One global vector conditions the posterior,
  flow, duration predictor, decoder and prior. The speaker part comes from a
  trained table OR from the reference encoder on a few seconds of audio
  (voice cloning, no training); the emotion part is a category embedding
  scaled by an intensity.
* **Multilingual by character + language id.** Code-switched Kinyarwanda /
  English / French / Swahili text is read by one model.

Training forward pass
---------------------
    text(+lang ids) --TextEncoder--> h, (m_p, logs_p)     prior per character
    spec --PosteriorEncoder--> z ~ q(z|y,s)                ground-truth latent
    z --Flow--> z_p                                        into the prior space
    MAS(z_p, prior) -> alignment -> durations              (no gradients)
    expand prior by alignment; KL(q || p)                  VITS objective
    MeanFlow prior: regress u(z_t, r, t | m_p, logs_p, g)  v2 (target = z)
    reference encoder(ref mel) -> g_ref; regress to table  v2 (cloning)
    slice random segment of z --Generator--> y_hat         adversarial + mel
    DurationPredictor <- MSE on log durations

Inference
---------
    text -> prior stats + predicted durations -> expand -> (MeanFlow sample
    | Gaussian sample + inverse flow) -> Generator -> waveform.
"""
from __future__ import annotations

import math
from typing import Dict, Optional, Tuple

import torch
from torch import nn
from torch.nn import functional as F

from ..config import Config
from .latent import DurationPredictor, PosteriorEncoder, ResidualCouplingBlock
from .meanflow import LatentPrior, meanflow_loss, sample_latent
from .modules import generate_path, rand_slice_segments, sequence_mask
from .monotonic_align import maximum_path
from .style import ReferenceEncoder, compose_style
from .text_encoder import TextEncoder
from .waveform import Generator, MultiPeriodDiscriminator  # noqa: F401 (re-export)


class SynthesizerTrn(nn.Module):
    """Text-to-waveform synthesizer (training + inference graph)."""

    def __init__(self, n_vocab: int, spec_channels: int, cfg: Config):
        super().__init__()
        m = cfg.model
        self.cfg = cfg
        self.legacy = cfg.is_legacy
        self.spec_channels = spec_channels
        self.segment_size = cfg.train.segment_size
        inter = m.hidden_channels          # latent channel count
        self.inter_channels = inter
        self.gin_channels = m.gin_channels

        self.enc_p = TextEncoder(n_vocab, inter, m.hidden_channels,
                                 m.filter_channels, m.n_heads, m.n_layers,
                                 m.kernel_size, m.p_dropout, m.rel_window,
                                 n_languages=0 if self.legacy else cfg.n_languages())
        self.dec = Generator(inter, m.resblock_kernel_sizes,
                             m.resblock_dilation_sizes, m.upsample_rates,
                             m.upsample_initial_channel,
                             m.upsample_kernel_sizes,
                             gin_channels=m.gin_channels)
        self.enc_q = PosteriorEncoder(spec_channels, inter, inter,
                                      m.wn_kernel, m.posterior_layers,
                                      gin_channels=m.gin_channels)
        self.flow = ResidualCouplingBlock(inter, inter, m.flow_kernel,
                                          n_layers=4, n_flows=m.flow_layers,
                                          gin_channels=m.gin_channels)
        self.dp = DurationPredictor(m.hidden_channels, m.dp_filter_channels,
                                    m.dp_kernel_size, m.dp_dropout,
                                    gin_channels=m.gin_channels)
        self.emb_g = nn.Embedding(max(1, m.n_speakers), m.gin_channels)

        # ---- ALTATTS 2 additions ------------------------------------------ #
        self.ref_enc: Optional[ReferenceEncoder] = None
        self.emb_emo: Optional[nn.Embedding] = None
        self.prior: Optional[LatentPrior] = None
        if not self.legacy:
            s, p = cfg.style, cfg.prior
            if s.speaker_encoder == "builtin":
                self.ref_enc = ReferenceEncoder(cfg.audio.n_mels, s.ref_channels,
                                                m.gin_channels)
            if s.emotion_conditioning:
                self.emb_emo = nn.Embedding(cfg.n_emotions(), m.gin_channels)
                nn.init.zeros_(self.emb_emo.weight)
            self.null_style = nn.Parameter(torch.zeros(m.gin_channels))
            self.prior = LatentPrior(inter, 2 * inter, m.gin_channels,
                                     p.hidden, p.n_layers, p.n_heads,
                                     p.ffn_mult, p.conv_kernel)

    # ------------------------------------------------------------------ #
    #  Style
    # ------------------------------------------------------------------ #
    @property
    def has_cloning(self) -> bool:
        return self.ref_enc is not None

    @property
    def has_emotions(self) -> bool:
        return self.emb_emo is not None

    @property
    def has_meanflow(self) -> bool:
        return self.prior is not None

    def speaker_vector(self, sid: torch.Tensor) -> torch.Tensor:
        """Trained-speaker ids (B,) -> speaker vectors (B, gin)."""
        return self.emb_g(sid)

    def embed_reference(self, ref_mel: torch.Tensor,
                        ref_lengths: Optional[torch.Tensor] = None) -> torch.Tensor:
        """Reference log-mel (B, n_mels, T) -> speaker vectors (B, gin)."""
        if self.ref_enc is None:
            raise RuntimeError("this model has no speaker (reference) encoder; "
                               "voice cloning needs a v2 model trained with "
                               "style.speaker_encoder='builtin'")
        return self.ref_enc(ref_mel, ref_lengths)

    def style(self, sid: Optional[torch.Tensor] = None,
              spk: Optional[torch.Tensor] = None,
              emotion: Optional[torch.Tensor] = None,
              intensity: Optional[torch.Tensor] = None,
              drop: Optional[torch.Tensor] = None) -> torch.Tensor:
        """Compose the style vector (B, gin) from speaker ids OR vectors,
        plus optional emotion ids (B,) and intensities (B,)."""
        if spk is None:
            if sid is None:
                raise ValueError("style(): need sid or spk")
            spk = self.emb_g(sid)
        emo = None
        if self.emb_emo is not None and emotion is not None:
            emo = self.emb_emo(emotion.clamp(0, self.emb_emo.num_embeddings - 1))
        null = getattr(self, "null_style", None)
        return compose_style(spk, emo, intensity, null, drop)

    # ------------------------------------------------------------------ #
    def forward(self, x, x_lengths, spec, spec_lengths, sid,
                lang: Optional[torch.Tensor] = None,
                ref_mel: Optional[torch.Tensor] = None,
                ref_lengths: Optional[torch.Tensor] = None,
                emotion: Optional[torch.Tensor] = None,
                intensity: Optional[torch.Tensor] = None,
                use_ref: Optional[torch.Tensor] = None,
                style_drop: Optional[torch.Tensor] = None):
        """Training pass. Returns the VITS 7-tuple plus an ``extras`` dict
        with the v2 losses (``l_mf`` MeanFlow, ``l_spk`` reference-encoder
        regression) and diagnostics."""
        extras: Dict[str, torch.Tensor] = {}
        g_tab = self.emb_g(sid)                                # (B, gin)
        spk = g_tab
        if self.ref_enc is not None and ref_mel is not None:
            ref_emb = self.ref_enc(ref_mel, ref_lengths)
            # regress the reference embedding onto the trained table entry
            # so unseen speakers are embedded in the space the decoder knows
            cos = F.cosine_similarity(ref_emb.float(), g_tab.detach().float(), dim=-1)
            mse = F.mse_loss(ref_emb.float(), g_tab.detach().float())
            extras["l_spk"] = (1.0 - cos).mean() + 0.5 * mse
            extras["spk_cos"] = cos.mean().detach()
            if use_ref is not None:
                spk = torch.where(use_ref.unsqueeze(-1), ref_emb, g_tab)
        g = self.style(spk=spk, emotion=emotion, intensity=intensity,
                       drop=style_drop)
        g = g.unsqueeze(-1)                                     # (B, gin, 1)

        h, m_p, logs_p, x_mask = self.enc_p(x, x_lengths, lang)
        z, m_q, logs_q, y_mask = self.enc_q(spec, spec_lengths, g=g)
        z_p = self.flow(z, y_mask, g=g)

        # -- MAS: likelihood of every (frame, char) pair under the prior --- #
        with torch.no_grad():
            s_p_sq_r = torch.exp(-2.0 * logs_p)              # (B, C, T_x)
            neg1 = torch.sum(-0.5 * math.log(2 * math.pi) - logs_p,
                             dim=1, keepdim=True)            # (B, 1, T_x)
            neg2 = torch.matmul(-0.5 * (z_p ** 2).transpose(1, 2), s_p_sq_r)
            neg3 = torch.matmul(z_p.transpose(1, 2), m_p * s_p_sq_r)
            neg4 = torch.sum(-0.5 * (m_p ** 2) * s_p_sq_r,
                             dim=1, keepdim=True)
            neg_cent = neg1 + neg2 + neg3 + neg4             # (B, T_y, T_x)
            attn_mask = y_mask.transpose(1, 2) * x_mask      # (B, T_y, T_x)
            attn = maximum_path(neg_cent, attn_mask)         # (B, T_y, T_x)
            attn = attn.unsqueeze(1).detach()                # (B, 1, T_y, T_x)

        # -- duration loss --------------------------------------------------- #
        w = attn.sum(2)                                      # (B, 1, T_x)
        logw_ = torch.log(w + 1e-6) * x_mask
        logw = self.dp(h, x_mask, g=g)
        l_length = torch.sum((logw - logw_) ** 2) / torch.sum(x_lengths)

        # -- expand the prior along the alignment ----------------------------- #
        m_p = torch.matmul(attn.squeeze(1), m_p.transpose(1, 2)).transpose(1, 2)
        logs_p = torch.matmul(attn.squeeze(1),
                              logs_p.transpose(1, 2)).transpose(1, 2)

        # -- MeanFlow prior on the posterior latent --------------------------- #
        if self.prior is not None:
            p = self.cfg.prior
            cond = torch.cat([m_p, logs_p], dim=1)
            z_mf, cond_mf, mask_mf = z, cond, y_mask
            max_f = int(getattr(p, "max_frames", 0) or 0)
            if max_f and z.size(2) > max_f:
                # random window per batch (same offset for all items keeps the
                # masks consistent; items shorter than the window are padded)
                max_start = int(spec_lengths.max().item()) - max_f
                start = int(torch.randint(0, max(1, max_start + 1), (1,)))
                sl = slice(start, start + max_f)
                z_mf, cond_mf, mask_mf = z[:, :, sl], cond[:, :, sl], y_mask[:, :, sl]
            l_mf, mf_stats = meanflow_loss(
                self.prior, z_mf, cond_mf, mask_mf, g.squeeze(-1),
                ratio=p.meanflow_ratio, sampler=p.time_sampler,
                mu=p.time_mu, sigma=p.time_sigma,
                adaptive_p=p.adaptive_weight_p, jvp_mode=p.jvp_mode)
            extras["l_mf"] = l_mf
            for k, v in mf_stats.items():
                extras[k] = torch.tensor(v)

        # -- windowed decoding ------------------------------------------------ #
        z_slice, ids_slice = rand_slice_segments(z, spec_lengths,
                                                 self.segment_size)
        y_hat = self.dec(z_slice, g=g)
        return (y_hat, l_length, attn, ids_slice, x_mask, y_mask,
                (z, z_p, m_p, logs_p, m_q, logs_q), extras)

    # ------------------------------------------------------------------ #
    @torch.no_grad()
    def infer(self, x, x_lengths, sid: Optional[torch.Tensor] = None,
              noise_scale: float = 0.667, length_scale: float = 1.0,
              max_len: Optional[int] = None, *,
              g: Optional[torch.Tensor] = None,
              lang: Optional[torch.Tensor] = None,
              emotion: Optional[torch.Tensor] = None,
              intensity: Optional[torch.Tensor] = None,
              prior: Optional[str] = None, steps: Optional[int] = None,
              cfg_scale: Optional[float] = None,
              generator: Optional[torch.Generator] = None,
              duration_override: Optional[torch.Tensor] = None
              ) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        """Text ids -> waveform (B, 1, samples).

        sid           trained speaker ids (B,) -- or pass ``g`` (B, gin)
                      speaker vectors (enrolled / cloned voices)
        noise_scale   prosody variability (0.667 = the standard value; maps
                      to MeanFlow temperature 1.0)
        length_scale  speaking-rate control (>1 slower, <1 faster)
        prior         "meanflow" | "flow" (default: cfg.prior.type)
        steps         MeanFlow sampling steps (default cfg.prior.steps)
        """
        if g is None:
            g = self.style(sid=sid, emotion=emotion, intensity=intensity)
        elif g.dim() == 2 and (emotion is not None) and self.emb_emo is not None:
            g = self.style(spk=g, emotion=emotion, intensity=intensity)
        g = g.unsqueeze(-1) if g.dim() == 2 else g            # (B, gin, 1)

        h, m_p, logs_p, x_mask = self.enc_p(x, x_lengths, lang)
        logw = self.dp(h, x_mask, g=g)
        w = torch.exp(logw) * x_mask * length_scale
        if duration_override is not None:
            w = torch.where(duration_override > 0, duration_override, w)
        w_ceil = torch.ceil(w)
        y_lengths = torch.clamp_min(torch.sum(w_ceil, [1, 2]), 1).long()
        y_mask = sequence_mask(y_lengths).unsqueeze(1).to(x_mask.dtype)
        attn_mask = x_mask.unsqueeze(2) * y_mask.unsqueeze(-1)
        attn = generate_path(w_ceil, attn_mask)              # (B,1,T_y,T_x)

        m_p = torch.matmul(attn.squeeze(1), m_p.transpose(1, 2)).transpose(1, 2)
        logs_p = torch.matmul(attn.squeeze(1),
                              logs_p.transpose(1, 2)).transpose(1, 2)

        use_mf = (prior or self.cfg.prior.type) == "meanflow" and self.prior is not None
        if use_mf:
            cond = torch.cat([m_p, logs_p], dim=1)
            temperature = max(0.0, min(noise_scale / 0.667, 1.5))
            z = sample_latent(self.prior, cond, y_mask, g.squeeze(-1),
                              steps=steps or self.cfg.prior.steps,
                              temperature=temperature,
                              cfg_scale=(cfg_scale if cfg_scale is not None
                                         else self.cfg.prior.cfg_scale),
                              null_g=getattr(self, "null_style", None),
                              generator=generator)
            z = z.to(m_p.dtype)
        else:
            noise = (torch.randn(m_p.shape, device=m_p.device, dtype=m_p.dtype,
                                 generator=generator) if generator is not None
                     else torch.randn_like(m_p))
            z_p = m_p + noise * torch.exp(logs_p) * noise_scale
            z = self.flow(z_p, y_mask, g=g, reverse=True)
        z = (z * y_mask)[:, :, :max_len]
        o = self.dec(z, g=g)
        return o, attn, y_mask

    # ------------------------------------------------------------------ #
    def inference_state_dict(self) -> dict:
        """Weights needed at inference only (posterior encoder excluded)."""
        full = self.state_dict()
        return {k: v for k, v in full.items() if not k.startswith("enc_q.")}

    def remove_weight_norm(self) -> None:
        self.dec.remove_weight_norm()


def build_model(cfg: Config, n_vocab: int) -> SynthesizerTrn:
    spec_channels = cfg.audio.n_fft // 2 + 1
    return SynthesizerTrn(n_vocab, spec_channels, cfg)
