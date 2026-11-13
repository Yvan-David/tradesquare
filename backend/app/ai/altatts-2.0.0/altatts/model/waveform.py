"""
Waveform side of the network.

``Generator``  a HiFi-GAN generator that decodes the latent z directly to the
waveform: 1x transposed-conv upsampling stages (whose product must equal the
STFT hop, so one latent frame becomes exactly one hop of samples) interleaved
with multi-receptive-field (MRF) residual blocks, plus global speaker
conditioning added after the input conv. Because it consumes the *latent*
rather than a mel spectrogram, decoder and acoustic model are trained jointly
end-to-end -- the property that gives VITS its ground-truth-level naturalness
(no train/inference mel mismatch, no vocoder fine-tuning step).

``MultiPeriodDiscriminator``  the adversarial ensemble from HiFi-GAN/VITS:
period discriminators (2, 3, 5, 7, 11) that fold the waveform into 2-D and
catch periodic artifacts, plus one scale discriminator on the raw waveform.
Feature maps are returned for the feature-matching loss.
"""
from __future__ import annotations

from typing import List, Tuple

import torch
from torch import nn
from torch.nn import functional as F
from torch.nn.utils.parametrizations import spectral_norm, weight_norm
from torch.nn.utils.parametrize import remove_parametrizations

from .modules import LRELU_SLOPE, ResBlock1, get_padding, init_weights


class Generator(nn.Module):
    def __init__(self, initial_channel: int, resblock_kernel_sizes,
                 resblock_dilation_sizes, upsample_rates,
                 upsample_initial_channel, upsample_kernel_sizes,
                 gin_channels: int = 0):
        super().__init__()
        self.num_kernels = len(resblock_kernel_sizes)
        self.num_upsamples = len(upsample_rates)
        self.conv_pre = nn.Conv1d(initial_channel, upsample_initial_channel,
                                  7, 1, padding=3)
        self.ups = nn.ModuleList()
        for i, (u, k) in enumerate(zip(upsample_rates, upsample_kernel_sizes)):
            self.ups.append(weight_norm(nn.ConvTranspose1d(
                upsample_initial_channel // (2 ** i),
                upsample_initial_channel // (2 ** (i + 1)),
                k, u, padding=(k - u) // 2)))
        self.resblocks = nn.ModuleList()
        for i in range(len(self.ups)):
            ch = upsample_initial_channel // (2 ** (i + 1))
            for k, d in zip(resblock_kernel_sizes, resblock_dilation_sizes):
                self.resblocks.append(ResBlock1(ch, k, d))
        self.conv_post = nn.Conv1d(ch, 1, 7, 1, padding=3, bias=False)
        self.ups.apply(init_weights)
        if gin_channels:
            self.cond = nn.Conv1d(gin_channels, upsample_initial_channel, 1)
        else:
            self.cond = None

    def forward(self, x: torch.Tensor, g: torch.Tensor = None) -> torch.Tensor:
        x = self.conv_pre(x)
        if g is not None and self.cond is not None:
            x = x + self.cond(g)
        for i in range(self.num_upsamples):
            x = F.leaky_relu(x, LRELU_SLOPE)
            x = self.ups[i](x)
            xs = None
            for j in range(self.num_kernels):
                r = self.resblocks[i * self.num_kernels + j](x)
                xs = r if xs is None else xs + r
            x = xs / self.num_kernels
        x = F.leaky_relu(x)
        return torch.tanh(self.conv_post(x))

    def remove_weight_norm(self):
        for up in self.ups:
            remove_parametrizations(up, "weight")
        for rb in self.resblocks:
            rb.remove_weight_norm()


class DiscriminatorP(nn.Module):
    def __init__(self, period: int, kernel_size: int = 5, stride: int = 3,
                 use_spectral_norm: bool = False):
        super().__init__()
        self.period = period
        norm_f = spectral_norm if use_spectral_norm else weight_norm
        chs = [(1, 32), (32, 128), (128, 512), (512, 1024)]
        self.convs = nn.ModuleList([norm_f(nn.Conv2d(
            i, o, (kernel_size, 1), (stride, 1),
            padding=(get_padding(kernel_size, 1), 0))) for i, o in chs])
        self.convs.append(norm_f(nn.Conv2d(1024, 1024, (kernel_size, 1), 1,
                                           padding=(get_padding(kernel_size, 1), 0))))
        self.conv_post = norm_f(nn.Conv2d(1024, 1, (3, 1), 1, padding=(1, 0)))

    def forward(self, x):
        fmap = []
        b, c, t = x.shape
        if t % self.period:
            pad = self.period - (t % self.period)
            x = F.pad(x, (0, pad), "reflect")
            t = t + pad
        x = x.view(b, c, t // self.period, self.period)
        for conv in self.convs:
            x = F.leaky_relu(conv(x), LRELU_SLOPE)
            fmap.append(x)
        x = self.conv_post(x)
        fmap.append(x)
        return torch.flatten(x, 1, -1), fmap


class DiscriminatorS(nn.Module):
    def __init__(self, use_spectral_norm: bool = False):
        super().__init__()
        norm_f = spectral_norm if use_spectral_norm else weight_norm
        self.convs = nn.ModuleList([
            norm_f(nn.Conv1d(1, 16, 15, 1, padding=7)),
            norm_f(nn.Conv1d(16, 64, 41, 4, groups=4, padding=20)),
            norm_f(nn.Conv1d(64, 256, 41, 4, groups=16, padding=20)),
            norm_f(nn.Conv1d(256, 1024, 41, 4, groups=64, padding=20)),
            norm_f(nn.Conv1d(1024, 1024, 41, 4, groups=256, padding=20)),
            norm_f(nn.Conv1d(1024, 1024, 5, 1, padding=2)),
        ])
        self.conv_post = norm_f(nn.Conv1d(1024, 1, 3, 1, padding=1))

    def forward(self, x):
        fmap = []
        for conv in self.convs:
            x = F.leaky_relu(conv(x), LRELU_SLOPE)
            fmap.append(x)
        x = self.conv_post(x)
        fmap.append(x)
        return torch.flatten(x, 1, -1), fmap


class MultiPeriodDiscriminator(nn.Module):
    """One scale discriminator + period discriminators (2, 3, 5, 7, 11).

    The scale discriminator uses weight norm like the original VITS/HiFi-GAN
    code: with spectral norm its first outputs reach ~1e19 and the LSGAN
    loss overflows for the first steps (a latent 0.1 bug surfaced by the
    non-finite-loss guard)."""

    def __init__(self, periods=(2, 3, 5, 7, 11), use_spectral_norm: bool = False):
        super().__init__()
        self.discriminators = nn.ModuleList(
            [DiscriminatorS(use_spectral_norm=use_spectral_norm)] +
            [DiscriminatorP(p) for p in periods])

    def forward(self, y: torch.Tensor, y_hat: torch.Tensor
                ) -> Tuple[List, List, List, List]:
        d_rs, d_gs, f_rs, f_gs = [], [], [], []
        for d in self.discriminators:
            dr, fr = d(y)
            dg, fg = d(y_hat)
            d_rs.append(dr)
            d_gs.append(dg)
            f_rs.append(fr)
            f_gs.append(fg)
        return d_rs, d_gs, f_rs, f_gs
