"""
Style conditioning: WHO speaks (speaker identity) and HOW (emotion).

ALTATTS 2 composes the global style vector ``g`` (``gin_channels``) from:

* a **speaker vector** -- either a row of the trained speaker table
  (``emb_g``) or the output of the :class:`ReferenceEncoder` on a few seconds
  of reference mel (zero-shot voice cloning / enrolled voices). The reference
  encoder is trained jointly and regressed onto the speaker table, so
  embeddings of unseen speakers land in the same space the decoder knows;
* an **emotion vector** -- a learned embedding per emotion category scaled by
  an intensity in [0, 1] (index 0 = "unlabeled", used for corpora without
  emotion annotation so they never disturb the labelled categories);
* a **null vector** that replaces the style with probability
  ``cond_dropout`` during training, enabling classifier-free guidance
  (``cfg_scale``) on the MeanFlow prior at inference.

The reference encoder is a compact ECAPA-style network: a 2-D conv stack over
the mel spectrogram followed by *attentive statistics pooling* (mean and
standard deviation under a learned attention), which is what speaker-
verification systems use to be robust to clip length and content.
"""
from __future__ import annotations

from typing import List, Optional, Sequence

import torch
from torch import nn
from torch.nn import functional as F

from .modules import sequence_mask


class ReferenceEncoder(nn.Module):
    """log-mel (B, n_mels, T) -> speaker/style embedding (B, out_dim)."""

    def __init__(self, n_mels: int = 80,
                 channels: Sequence[int] = (32, 32, 64, 64, 128, 128),
                 out_dim: int = 256, hidden: int = 256):
        super().__init__()
        chs = [1] + list(channels)
        self.convs = nn.ModuleList()
        self.norms = nn.ModuleList()
        for i, o in zip(chs[:-1], chs[1:]):
            self.convs.append(nn.Conv2d(i, o, 3, stride=2, padding=1))
            self.norms.append(nn.GroupNorm(min(8, o), o))
        self.n_down = len(channels)
        f = n_mels
        for _ in channels:
            f = (f + 1) // 2
        self.proj = nn.Linear(chs[-1] * f, hidden)
        # attentive statistics pooling
        self.attn = nn.Sequential(nn.Conv1d(hidden, hidden // 2, 1), nn.Tanh(),
                                  nn.Conv1d(hidden // 2, 1, 1))
        self.out = nn.Linear(2 * hidden, out_dim)
        self.out_dim = out_dim

    def forward(self, mel: torch.Tensor,
                lengths: Optional[torch.Tensor] = None) -> torch.Tensor:
        x = mel.unsqueeze(1)                                # (B,1,F,T)
        for conv, norm in zip(self.convs, self.norms):
            x = F.silu(norm(conv(x)))
        b, c, f, t = x.shape
        x = x.permute(0, 3, 1, 2).reshape(b, t, c * f)      # (B,T',C*F')
        x = F.silu(self.proj(x)).transpose(1, 2)            # (B,H,T')
        if lengths is not None:
            l2 = torch.clamp((lengths.float() / (2 ** self.n_down)).ceil().long(), 1, t)
            m = sequence_mask(l2, t).unsqueeze(1).to(x.dtype)  # (B,1,T')
        else:
            m = torch.ones(b, 1, t, device=x.device, dtype=x.dtype)
        logits = self.attn(x).masked_fill(m == 0, -1e4)
        w = torch.softmax(logits, dim=-1)                   # (B,1,T')
        mean = torch.sum(x * w, dim=-1)
        var = torch.sum((x ** 2) * w, dim=-1) - mean ** 2
        std = torch.sqrt(torch.clamp(var, min=1e-5))
        return self.out(torch.cat([mean, std], dim=-1))


def compose_style(spk: torch.Tensor,
                  emo_emb: Optional[torch.Tensor] = None,
                  intensity: Optional[torch.Tensor] = None,
                  null: Optional[torch.Tensor] = None,
                  drop: Optional[torch.Tensor] = None) -> torch.Tensor:
    """speaker (B,G) [+ emotion (B,G) * intensity (B,)] -> style (B,G).

    ``drop`` (B,) bool replaces dropped rows by ``null`` (G,) -- used both for
    training-time style dropout and for the unconditional branch of CFG.
    """
    g = spk
    if emo_emb is not None:
        if intensity is None:
            intensity = torch.ones(spk.size(0), device=spk.device, dtype=spk.dtype)
        g = g + emo_emb * intensity.to(spk.dtype).unsqueeze(-1)
    if drop is not None and null is not None:
        g = torch.where(drop.unsqueeze(-1), null.to(g.dtype).unsqueeze(0).expand_as(g), g)
    return g
