"""
Shared building blocks used across the ALTATTS network.

* mask / path utilities (``sequence_mask``, ``generate_path``) -- turn lengths
  into boolean masks and durations into hard monotonic alignment matrices;
* ``slice_segments`` / ``rand_slice_segments`` -- the windowed-training trick:
  the decoder+discriminators only ever see short random slices of each
  utterance, which is what makes end-to-end waveform GAN training fit in
  memory;
* ``WN`` -- the non-causal WaveNet stack (gated dilated convs with global
  speaker conditioning) used by both the posterior encoder and every flow
  coupling layer;
* ``ResBlock1`` -- the HiFi-GAN multi-receptive-field residual block;
* ``LayerNorm`` -- channels-first layer norm for (B, C, T) tensors.
"""
from __future__ import annotations

import torch
from torch import nn
from torch.nn import functional as F
from torch.nn.utils.parametrizations import weight_norm
from torch.nn.utils.parametrize import remove_parametrizations

LRELU_SLOPE = 0.1


def get_padding(kernel_size: int, dilation: int = 1) -> int:
    return (kernel_size * dilation - dilation) // 2


def init_weights(m, mean: float = 0.0, std: float = 0.01) -> None:
    if isinstance(m, (nn.Conv1d, nn.ConvTranspose1d)):
        m.weight.data.normal_(mean, std)


def sequence_mask(lengths: torch.Tensor, max_len: int = 0) -> torch.Tensor:
    """(B,) lengths -> (B, T) boolean mask."""
    max_len = max_len or int(lengths.max())
    ids = torch.arange(max_len, device=lengths.device)
    return ids.unsqueeze(0) < lengths.unsqueeze(1)


def generate_path(duration: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    """Durations (B, 1, T_text) + mask (B, 1, T_mel, T_text) -> hard monotonic
    alignment path (B, 1, T_mel, T_text)."""
    b, _, t_y, t_x = mask.shape
    cum = torch.cumsum(duration, -1)                        # (B, 1, T_text)
    cum_flat = cum.view(b * t_x)
    path = sequence_mask(cum_flat, t_y).to(mask.dtype)
    path = path.view(b, t_x, t_y)
    path = path - F.pad(path, (0, 0, 1, 0, 0, 0))[:, :-1]
    return path.unsqueeze(1).transpose(2, 3) * mask


def slice_segments(x: torch.Tensor, ids_str: torch.Tensor,
                   segment_size: int) -> torch.Tensor:
    """Gather (B, C, segment_size) windows starting at per-item ``ids_str``."""
    out = torch.zeros(x.size(0), x.size(1), segment_size,
                      device=x.device, dtype=x.dtype)
    for i in range(x.size(0)):
        s = int(ids_str[i])
        out[i] = x[i, :, s: s + segment_size]
    return out


def rand_slice_segments(x: torch.Tensor, x_lengths: torch.Tensor,
                        segment_size: int):
    b = x.size(0)
    max_start = (x_lengths - segment_size).clamp(min=0)
    ids_str = (torch.rand(b, device=x.device) * (max_start + 1)).long()
    return slice_segments(x, ids_str, segment_size), ids_str


class LayerNorm(nn.Module):
    """LayerNorm over the channel dim of (B, C, T)."""

    def __init__(self, channels: int, eps: float = 1e-5):
        super().__init__()
        self.gamma = nn.Parameter(torch.ones(channels))
        self.beta = nn.Parameter(torch.zeros(channels))
        self.eps = eps

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = x.transpose(1, -1)
        x = F.layer_norm(x, (x.size(-1),), self.gamma, self.beta, self.eps)
        return x.transpose(1, -1)


def fused_add_tanh_sigmoid_multiply(a: torch.Tensor, b: torch.Tensor,
                                    n_channels: int) -> torch.Tensor:
    # Plain eager code on purpose: ``torch.jit.script`` is deprecated in
    # torch 2.x and every spawned DataLoader worker re-ran the decorator at
    # import, printing one FutureWarning per worker. The fusion gain was
    # negligible; torch.compile (train.compile) covers it when wanted.
    x = a + b
    t = torch.tanh(x[:, :n_channels])
    s = torch.sigmoid(x[:, n_channels:])
    return t * s


class WN(nn.Module):
    """Non-causal WaveNet: gated dilated convs, skip connections, optional
    global (speaker) conditioning via a 1x1 conv on ``g``."""

    def __init__(self, hidden_channels: int, kernel_size: int,
                 dilation_rate: int, n_layers: int, gin_channels: int = 0,
                 p_dropout: float = 0.0):
        super().__init__()
        self.hidden_channels = hidden_channels
        self.n_layers = n_layers
        self.in_layers = nn.ModuleList()
        self.res_skip_layers = nn.ModuleList()
        self.drop = nn.Dropout(p_dropout)
        if gin_channels:
            self.cond_layer = weight_norm(
                nn.Conv1d(gin_channels, 2 * hidden_channels * n_layers, 1))
        else:
            self.cond_layer = None
        for i in range(n_layers):
            dilation = dilation_rate ** i
            pad = (kernel_size * dilation - dilation) // 2
            self.in_layers.append(weight_norm(nn.Conv1d(
                hidden_channels, 2 * hidden_channels, kernel_size,
                dilation=dilation, padding=pad)))
            res_skip = 2 * hidden_channels if i < n_layers - 1 else hidden_channels
            self.res_skip_layers.append(
                weight_norm(nn.Conv1d(hidden_channels, res_skip, 1)))

    def forward(self, x, x_mask, g=None):
        output = torch.zeros_like(x)
        if g is not None and self.cond_layer is not None:
            g = self.cond_layer(g)
        for i in range(self.n_layers):
            x_in = self.in_layers[i](x)
            if g is not None:
                off = i * 2 * self.hidden_channels
                g_l = g[:, off: off + 2 * self.hidden_channels]
            else:
                g_l = torch.zeros_like(x_in)
            acts = fused_add_tanh_sigmoid_multiply(x_in, g_l,
                                                   self.hidden_channels)
            acts = self.drop(acts)
            res_skip = self.res_skip_layers[i](acts)
            if i < self.n_layers - 1:
                x = (x + res_skip[:, : self.hidden_channels]) * x_mask
                output = output + res_skip[:, self.hidden_channels:]
            else:
                output = output + res_skip
        return output * x_mask


class ResBlock1(nn.Module):
    """HiFi-GAN residual block: two dilated conv stacks per dilation."""

    def __init__(self, channels: int, kernel_size: int = 3,
                 dilations=(1, 3, 5)):
        super().__init__()
        self.convs1 = nn.ModuleList([weight_norm(nn.Conv1d(
            channels, channels, kernel_size, dilation=d,
            padding=get_padding(kernel_size, d))) for d in dilations])
        self.convs2 = nn.ModuleList([weight_norm(nn.Conv1d(
            channels, channels, kernel_size, dilation=1,
            padding=get_padding(kernel_size, 1))) for _ in dilations])
        for m in list(self.convs1) + list(self.convs2):
            init_weights(m)

    def forward(self, x, x_mask=None):
        for c1, c2 in zip(self.convs1, self.convs2):
            xt = F.leaky_relu(x, LRELU_SLOPE)
            if x_mask is not None:
                xt = xt * x_mask
            xt = c1(xt)
            xt = F.leaky_relu(xt, LRELU_SLOPE)
            if x_mask is not None:
                xt = xt * x_mask
            xt = c2(xt)
            x = xt + x
        if x_mask is not None:
            x = x * x_mask
        return x

    def remove_weight_norm(self):
        for m in list(self.convs1) + list(self.convs2):
            remove_parametrizations(m, "weight")
