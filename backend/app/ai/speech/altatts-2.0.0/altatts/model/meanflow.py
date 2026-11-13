"""
MeanFlow latent prior -- one/few-step generation of the VITS latent.

Why
---
VITS samples its latent from a frame-independent Gaussian prior and pushes it
through a volume-preserving normalizing flow. That prior is the main cap on
prosodic richness: every frame is drawn independently, so intonation,
rhythm and emphasis come out flatter than a human reading. Flow-matching /
diffusion priors (Matcha-TTS, StableTTS, CosyVoice's flow decoder, F5-TTS)
model the *joint* distribution of the whole utterance and are the reason
current systems sound natural -- at the cost of 10-50 sampling steps.

**MeanFlow** (Geng, Deng, Bai, Kolter & He, "Mean Flows for One-step
Generative Modeling", 2025) removes that cost. Instead of the instantaneous
velocity ``v(z_t, t)`` it learns the *average velocity* over an interval::

    u(z_t, r, t) = 1/(t - r) * integral_r^t v(z_tau, tau) d tau

which satisfies the MeanFlow identity (differentiating w.r.t. t)::

    u(z_t, r, t) = v(z_t, t) - (t - r) * d/dt u(z_t, r, t)
    d/dt u = (dz_t/dt) . grad_z u + d_t u     (a Jacobian-vector product)

Training regresses the network on that identity with a stop-gradient on the
right-hand side; sampling in ONE step is ``z_0 = z_1 - u(z_1, 0, 1)``, and a
few steps (default 4) give a quality margin. With ``r = t`` the objective is
exactly conditional flow matching, so ``meanflow_ratio = 0`` recovers the
standard CFM prior.

Parameterization follows the paper (predict ``u``; logit-normal time
sampling; adaptive ``1/(err^2 + c)^p`` loss weighting). The network is a
DiT-style transformer with adaLN-Zero modulation from (t, t-r, style), a
depthwise convolution per block for local context, and rotary positions so
it is length-agnostic. Conditioning = the MAS-aligned text prior
``(m_p, logs_p)`` expanded to frame rate -- the alignment/duration machinery
of VITS stays untouched, which is what keeps word error rates low.

The JVP is computed with ``torch.func.jvp`` (forward-mode AD); when a
backend lacks forward-mode support for some op, a finite-difference estimate
(also suggested by the authors) is used instead, selected automatically.
"""
from __future__ import annotations

import math
from typing import Dict, Optional, Tuple

import torch
from torch import nn
from torch.nn import functional as F


# --------------------------------------------------------------------------- #
#  Building blocks (all forward-mode-AD friendly: no fused SDPA, no inplace)
# --------------------------------------------------------------------------- #
class TimestepEmbedding(nn.Module):
    """Scalar in [0, 1] -> (B, dim) via sinusoidal features + MLP."""

    def __init__(self, dim: int, freq_dim: int = 256, scale: float = 1000.0):
        super().__init__()
        self.freq_dim = freq_dim
        self.scale = scale
        self.mlp = nn.Sequential(nn.Linear(freq_dim, dim), nn.SiLU(),
                                 nn.Linear(dim, dim))

    def forward(self, t: torch.Tensor) -> torch.Tensor:
        half = self.freq_dim // 2
        freqs = torch.exp(-math.log(10000.0) * torch.arange(half, device=t.device,
                                                            dtype=torch.float32) / half)
        args = t.float().unsqueeze(-1) * self.scale * freqs.unsqueeze(0)
        emb = torch.cat([torch.cos(args), torch.sin(args)], dim=-1)
        return self.mlp(emb.to(self.mlp[0].weight.dtype))


def _rope_cache(t: int, dim: int, device, dtype) -> Tuple[torch.Tensor, torch.Tensor]:
    half = dim // 2
    inv = 1.0 / (10000 ** (torch.arange(0, half, device=device, dtype=torch.float32) / half))
    pos = torch.arange(t, device=device, dtype=torch.float32)
    ang = pos.unsqueeze(1) * inv.unsqueeze(0)                # (T, half)
    cos = torch.cat([ang.cos(), ang.cos()], dim=-1).to(dtype)
    sin = torch.cat([ang.sin(), ang.sin()], dim=-1).to(dtype)
    return cos, sin


def _rotate_half(x: torch.Tensor) -> torch.Tensor:
    x1, x2 = x.chunk(2, dim=-1)
    return torch.cat([-x2, x1], dim=-1)


class Attention(nn.Module):
    def __init__(self, dim: int, n_heads: int):
        super().__init__()
        assert dim % n_heads == 0
        self.h = n_heads
        self.dk = dim // n_heads
        self.qkv = nn.Linear(dim, 3 * dim)
        self.out = nn.Linear(dim, dim)

    def forward(self, x: torch.Tensor, key_mask: torch.Tensor) -> torch.Tensor:
        b, t, d = x.shape
        q, k, v = self.qkv(x).view(b, t, 3, self.h, self.dk).unbind(2)
        q, k, v = (z.transpose(1, 2) for z in (q, k, v))     # (B,H,T,dk)
        cos, sin = _rope_cache(t, self.dk, x.device, q.dtype)
        q = q * cos + _rotate_half(q) * sin
        k = k * cos + _rotate_half(k) * sin
        scores = torch.matmul(q, k.transpose(-2, -1)) / math.sqrt(self.dk)
        scores = scores.masked_fill(key_mask[:, None, None, :] == 0, -1e4)
        p = torch.softmax(scores.float(), dim=-1).to(v.dtype)
        o = torch.matmul(p, v).transpose(1, 2).reshape(b, t, d)
        return self.out(o)


def _modulate(x: torch.Tensor, shift: torch.Tensor, scale: torch.Tensor) -> torch.Tensor:
    return x * (1 + scale.unsqueeze(1)) + shift.unsqueeze(1)


class DiTBlock(nn.Module):
    def __init__(self, dim: int, n_heads: int, ffn_mult: int = 4,
                 conv_kernel: int = 5):
        super().__init__()
        self.norm1 = nn.LayerNorm(dim, elementwise_affine=False, eps=1e-6)
        self.dwconv = nn.Conv1d(dim, dim, conv_kernel, padding=conv_kernel // 2,
                                groups=dim)
        self.attn = Attention(dim, n_heads)
        self.norm2 = nn.LayerNorm(dim, elementwise_affine=False, eps=1e-6)
        self.ffn = nn.Sequential(nn.Linear(dim, dim * ffn_mult),
                                 nn.GELU(approximate="tanh"),
                                 nn.Linear(dim * ffn_mult, dim))
        self.ada = nn.Linear(dim, 6 * dim)
        nn.init.zeros_(self.ada.weight)
        nn.init.zeros_(self.ada.bias)

    def forward(self, x: torch.Tensor, c: torch.Tensor, mask: torch.Tensor
                ) -> torch.Tensor:
        """x (B,T,D), c (B,D), mask (B,T) -> (B,T,D)"""
        sh1, sc1, g1, sh2, sc2, g2 = self.ada(F.silu(c)).chunk(6, dim=-1)
        m = mask.unsqueeze(-1).to(x.dtype)
        h = _modulate(self.norm1(x), sh1, sc1) * m
        h = h + self.dwconv(h.transpose(1, 2)).transpose(1, 2) * m
        x = x + g1.unsqueeze(1) * self.attn(h, mask)
        h = _modulate(self.norm2(x), sh2, sc2)
        x = x + g2.unsqueeze(1) * self.ffn(h)
        return x * m


class LatentPrior(nn.Module):
    """u_theta(z_t, r, t | cond, style): average-velocity network."""

    def __init__(self, channels: int, cond_channels: int, gin_channels: int,
                 hidden: int = 256, n_layers: int = 6, n_heads: int = 4,
                 ffn_mult: int = 4, conv_kernel: int = 5):
        super().__init__()
        self.channels = channels
        self.in_proj = nn.Linear(channels + cond_channels, hidden)
        self.t_emb = TimestepEmbedding(hidden)
        self.dt_emb = TimestepEmbedding(hidden)
        self.g_proj = nn.Linear(gin_channels, hidden) if gin_channels else None
        self.blocks = nn.ModuleList([DiTBlock(hidden, n_heads, ffn_mult, conv_kernel)
                                     for _ in range(n_layers)])
        self.final_norm = nn.LayerNorm(hidden, elementwise_affine=False, eps=1e-6)
        self.final_ada = nn.Linear(hidden, 2 * hidden)
        self.out = nn.Linear(hidden, channels)
        for lin in (self.final_ada, self.out):
            nn.init.zeros_(lin.weight)
            nn.init.zeros_(lin.bias)

    def forward(self, z_t: torch.Tensor, r: torch.Tensor, t: torch.Tensor,
                cond: torch.Tensor, mask: torch.Tensor,
                g: Optional[torch.Tensor] = None) -> torch.Tensor:
        """z_t (B,C,T), r/t (B,), cond (B,Cc,T), mask (B,1,T), g (B,G) -> u (B,C,T)"""
        m1 = mask.squeeze(1)                                   # (B,T)
        x = torch.cat([z_t, cond], dim=1).transpose(1, 2)      # (B,T,C+Cc)
        x = self.in_proj(x)
        c = self.t_emb(t) + self.dt_emb(t - r)
        if g is not None and self.g_proj is not None:
            c = c + self.g_proj(g.to(c.dtype))
        for blk in self.blocks:
            x = blk(x, c, m1)
        sh, sc = self.final_ada(F.silu(c)).chunk(2, dim=-1)
        x = _modulate(self.final_norm(x), sh, sc)
        return self.out(x).transpose(1, 2) * mask


# --------------------------------------------------------------------------- #
#  Training objective
# --------------------------------------------------------------------------- #
def sample_times(batch: int, ratio: float, sampler: str, mu: float, sigma: float,
                 device) -> Tuple[torch.Tensor, torch.Tensor]:
    """(t, r) with 0 <= r <= t <= 1; r == t for a (1 - ratio) fraction."""
    if sampler == "logit_normal":
        a = torch.sigmoid(torch.randn(batch, 2, device=device) * sigma + mu)
    else:
        a = torch.rand(batch, 2, device=device)
    t = a.max(dim=1).values
    r = a.min(dim=1).values
    same = torch.rand(batch, device=device) >= ratio
    r = torch.where(same, t, r)
    return t, r


_JVP_STATE = {"mode": None}     # resolved once per process ("jvp" or "fd")


def _dudt_fd(fn, z_t, r, t, v, delta: float = 1e-2):
    with torch.no_grad():
        u2 = fn(z_t + delta * v, r, t + delta)
        u1 = fn(z_t, r, t)
    return (u2 - u1) / delta


def meanflow_loss(prior: LatentPrior, x: torch.Tensor, cond: torch.Tensor,
                  mask: torch.Tensor, g: Optional[torch.Tensor], *,
                  ratio: float = 0.25, sampler: str = "logit_normal",
                  mu: float = -0.4, sigma: float = 1.0,
                  adaptive_p: float = 1.0, jvp_mode: str = "auto",
                  ) -> Tuple[torch.Tensor, Dict[str, float]]:
    """MeanFlow regression loss on latents ``x`` (B,C,T) (target, detached).

    Returns (loss, stats). ``mask`` (B,1,T) marks valid frames.
    """
    x = x.detach().float()
    b = x.size(0)
    t, r = sample_times(b, ratio, sampler, mu, sigma, x.device)
    tb, rb = t.view(b, 1, 1), r.view(b, 1, 1)
    eps = torch.randn_like(x)
    z_t = ((1.0 - tb) * x + tb * eps) * mask
    v = (eps - x) * mask

    def fn(z, r_, t_):
        return prior(z.to(cond.dtype), r_, t_, cond, mask, g).float()

    need_jvp = bool((t != r).any())
    if need_jvp:
        mode = jvp_mode if jvp_mode != "auto" else (_JVP_STATE["mode"] or "jvp")
        if mode == "jvp":
            try:
                import warnings
                with warnings.catch_warnings():
                    # torch.func.jvp registers its decompositions through
                    # the deprecated torch.jit.script on first use: silence
                    # that chatter (and keep it from breaking under -W error)
                    warnings.simplefilter("ignore", DeprecationWarning)
                    warnings.simplefilter("ignore", FutureWarning)
                    u, dudt = torch.func.jvp(
                        fn, (z_t, r, t),
                        (v, torch.zeros_like(r), torch.ones_like(t)))
                _JVP_STATE["mode"] = "jvp"
            except Exception as exc:                 # noqa: BLE001
                if jvp_mode == "jvp":
                    raise
                if _JVP_STATE["mode"] != "fd":
                    import warnings
                    warnings.warn(f"[meanflow] torch.func.jvp unavailable "
                                  f"({str(exc)[:80]}); using finite "
                                  f"differences for d/dt u", RuntimeWarning)
                _JVP_STATE["mode"] = "fd"
                u = fn(z_t, r, t)
                dudt = _dudt_fd(fn, z_t, r, t, v)
        else:
            u = fn(z_t, r, t)
            dudt = _dudt_fd(fn, z_t, r, t, v)
        u_tgt = v - (tb - rb) * dudt
    else:
        u = fn(z_t, r, t)
        u_tgt = v
    err = ((u - u_tgt.detach()) ** 2) * mask
    denom = mask.sum(dim=(1, 2)).clamp_min(1.0) * x.size(1)
    mse = err.sum(dim=(1, 2)) / denom                    # per sample
    if adaptive_p > 0:
        w = 1.0 / (mse.detach() + 1e-3) ** adaptive_p
        w = w / w.mean().clamp_min(1e-8)                  # keep the scale
        loss = (w * mse).mean()
    else:
        loss = mse.mean()
    stats = {"mf_mse": float(mse.mean().detach()),
             "mf_frac_interval": float((t != r).float().mean())}
    return loss, stats


# --------------------------------------------------------------------------- #
#  Sampling
# --------------------------------------------------------------------------- #
@torch.no_grad()
def sample_latent(prior: LatentPrior, cond: torch.Tensor, mask: torch.Tensor,
                  g: Optional[torch.Tensor], steps: int = 4,
                  temperature: float = 1.0, cfg_scale: float = 1.0,
                  null_g: Optional[torch.Tensor] = None,
                  generator: Optional[torch.Generator] = None) -> torch.Tensor:
    """Noise -> latent in ``steps`` MeanFlow steps (1 is valid)."""
    b, _, t_len = cond.shape
    z = torch.randn(b, prior.channels, t_len, device=cond.device,
                    dtype=torch.float32, generator=generator) * temperature
    z = z * mask
    steps = max(1, int(steps))
    ts = torch.linspace(1.0, 0.0, steps + 1, device=cond.device)
    for i in range(steps):
        t_cur = ts[i].expand(b)
        t_nxt = ts[i + 1].expand(b)
        u = prior(z.to(cond.dtype), t_nxt, t_cur, cond, mask, g).float()
        if cfg_scale != 1.0 and null_g is not None:
            u_null = prior(z.to(cond.dtype), t_nxt, t_cur, cond, mask,
                           null_g.unsqueeze(0).expand(b, -1)).float()
            u = u_null + cfg_scale * (u - u_null)
        z = z - (t_cur - t_nxt).view(b, 1, 1) * u
    return z * mask
