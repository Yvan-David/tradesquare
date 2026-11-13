"""
The three latent-side modules of the VITS architecture:

``PosteriorEncoder``  linear spectrogram -> q(z | y): a WaveNet stack reads
                      the ground-truth spectrogram and emits per-frame mean /
                      log-std of the latent (training only -- the "encoder"
                      half of the conditional VAE).

``ResidualCouplingBlock``  the normalizing flow that maps the posterior latent
                      z into the prior space z_p (and back at inference).
                      Mean-only affine couplings (VITS choice: stabler than
                      full affine), each followed by a channel flip so every
                      channel gets transformed. Speaker-conditioned, so the
                      same flow disentangles voice identity.

``DurationPredictor`` predicts log-durations per input character from the
                      (detached) text-encoder hiddens + speaker embedding.
                      Deterministic (conv-relu-norm x2 -> 1x1), trained with
                      MSE against the durations discovered by monotonic
                      alignment search. Deterministic DP is the robust
                      production choice: identical rhythm for identical input,
                      no flow-sampling artifacts; expressiveness is recovered
                      at inference via ``noise_scale`` and ``length_scale``.
"""
from __future__ import annotations

import torch
from torch import nn

from .modules import WN, LayerNorm, sequence_mask


class PosteriorEncoder(nn.Module):
    def __init__(self, in_channels: int, out_channels: int,
                 hidden_channels: int, kernel_size: int, n_layers: int,
                 gin_channels: int = 0):
        super().__init__()
        self.out_channels = out_channels
        self.pre = nn.Conv1d(in_channels, hidden_channels, 1)
        self.enc = WN(hidden_channels, kernel_size, dilation_rate=1,
                      n_layers=n_layers, gin_channels=gin_channels)
        self.proj = nn.Conv1d(hidden_channels, out_channels * 2, 1)

    def forward(self, x, x_lengths, g=None):
        x_mask = sequence_mask(x_lengths, x.size(2)).unsqueeze(1).to(x.dtype)
        x = self.pre(x) * x_mask
        x = self.enc(x, x_mask, g=g)
        stats = self.proj(x) * x_mask
        m, logs = torch.split(stats, self.out_channels, dim=1)
        z = (m + torch.randn_like(m) * torch.exp(logs)) * x_mask
        return z, m, logs, x_mask


class ResidualCouplingLayer(nn.Module):
    """Mean-only affine coupling: half the channels predict a shift for the
    other half through a speaker-conditioned WN. Volume-preserving
    (logdet = 0), invertible in closed form."""

    def __init__(self, channels: int, hidden_channels: int, kernel_size: int,
                 n_layers: int, gin_channels: int = 0):
        super().__init__()
        self.half_channels = channels // 2
        self.pre = nn.Conv1d(self.half_channels, hidden_channels, 1)
        self.enc = WN(hidden_channels, kernel_size, dilation_rate=1,
                      n_layers=n_layers, gin_channels=gin_channels)
        self.post = nn.Conv1d(hidden_channels, self.half_channels, 1)
        self.post.weight.data.zero_()
        self.post.bias.data.zero_()

    def forward(self, x, x_mask, g=None, reverse: bool = False):
        x0, x1 = torch.split(x, self.half_channels, dim=1)
        h = self.pre(x0) * x_mask
        h = self.enc(h, x_mask, g=g)
        m = self.post(h) * x_mask
        if not reverse:
            x1 = (x1 + m) * x_mask
        else:
            x1 = (x1 - m) * x_mask
        return torch.cat([x0, x1], dim=1)


class Flip(nn.Module):
    def forward(self, x, x_mask, g=None, reverse: bool = False):
        return torch.flip(x, dims=[1])


class ResidualCouplingBlock(nn.Module):
    def __init__(self, channels: int, hidden_channels: int, kernel_size: int,
                 n_layers: int, n_flows: int = 4, gin_channels: int = 0):
        super().__init__()
        self.flows = nn.ModuleList()
        for _ in range(n_flows):
            self.flows.append(ResidualCouplingLayer(
                channels, hidden_channels, kernel_size, n_layers,
                gin_channels=gin_channels))
            self.flows.append(Flip())

    def forward(self, x, x_mask, g=None, reverse: bool = False):
        flows = reversed(self.flows) if reverse else self.flows
        for flow in flows:
            x = flow(x, x_mask, g=g, reverse=reverse)
        return x


class DurationPredictor(nn.Module):
    def __init__(self, in_channels: int, filter_channels: int,
                 kernel_size: int, p_dropout: float,
                 gin_channels: int = 0):
        super().__init__()
        self.drop = nn.Dropout(p_dropout)
        self.conv1 = nn.Conv1d(in_channels, filter_channels, kernel_size,
                               padding=kernel_size // 2)
        self.norm1 = LayerNorm(filter_channels)
        self.conv2 = nn.Conv1d(filter_channels, filter_channels, kernel_size,
                               padding=kernel_size // 2)
        self.norm2 = LayerNorm(filter_channels)
        self.proj = nn.Conv1d(filter_channels, 1, 1)
        if gin_channels:
            self.cond = nn.Conv1d(gin_channels, in_channels, 1)
        else:
            self.cond = None

    def forward(self, x, x_mask, g=None):
        x = x.detach()                      # duration loss must not shape h
        if g is not None and self.cond is not None:
            x = x + self.cond(g.detach())
        x = self.norm1(self.drop(torch.relu(self.conv1(x * x_mask))))
        x = self.norm2(self.drop(torch.relu(self.conv2(x * x_mask))))
        return self.proj(x * x_mask) * x_mask       # log-durations, (B,1,T)
