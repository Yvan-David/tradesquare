"""
Text encoder: a transformer over characters with *windowed relative-position*
self-attention (the VITS/Glow-TTS encoder), plus -- in ALTATTS 2 -- a
per-character **language embedding**.

Relative positions: character pronunciation depends on a small neighbourhood
(digraphs ``ny``/``cy``/``sh``, prenasalised stops, the syllable frame), not
on absolute sentence position, so each head learns embeddings for offsets
within ``rel_window`` characters of the query.

Language ids: in code-switched text the same letters sound different in
Kinyarwanda, English, French and Swahili. A learned embedding per language
is added to the character embedding (zero-initialised, so a model that only
ever sees one language is unaffected). This is the lightweight approach used
by multilingual VITS variants and MMS-style systems; adding a language later
is a vocabulary change in the config, not an architecture change.

Output: hidden states ``h`` (B, H, T_text), the prior statistics
``m_p, logs_p`` (mean / log-std of the latent prior per character), and the
padding mask.
"""
from __future__ import annotations

import math
from typing import Optional

import torch
from torch import nn
from torch.nn import functional as F

from .modules import LayerNorm, sequence_mask


class RelativeMultiHeadAttention(nn.Module):
    def __init__(self, channels: int, n_heads: int, window: int = 4,
                 p_dropout: float = 0.0):
        super().__init__()
        assert channels % n_heads == 0
        self.n_heads = n_heads
        self.k_channels = channels // n_heads
        self.window = window
        self.conv_q = nn.Conv1d(channels, channels, 1)
        self.conv_k = nn.Conv1d(channels, channels, 1)
        self.conv_v = nn.Conv1d(channels, channels, 1)
        self.conv_o = nn.Conv1d(channels, channels, 1)
        self.drop = nn.Dropout(p_dropout)
        rel_std = self.k_channels ** -0.5
        self.emb_rel_k = nn.Parameter(
            torch.randn(1, 2 * window + 1, self.k_channels) * rel_std)
        self.emb_rel_v = nn.Parameter(
            torch.randn(1, 2 * window + 1, self.k_channels) * rel_std)
        nn.init.xavier_uniform_(self.conv_q.weight)
        nn.init.xavier_uniform_(self.conv_k.weight)
        nn.init.xavier_uniform_(self.conv_v.weight)

    # -- relative-position plumbing (Glow-TTS style) -------------------------- #
    def _get_rel_embeddings(self, emb: torch.Tensor, length: int) -> torch.Tensor:
        pad = max(length - (self.window + 1), 0)
        start = max((self.window + 1) - length, 0)
        emb = F.pad(emb, (0, 0, pad, pad))
        return emb[:, start: start + 2 * length - 1]

    @staticmethod
    def _rel_to_abs(x: torch.Tensor) -> torch.Tensor:
        """(B, H, L, 2L-1) -> (B, H, L, L)."""
        b, h, l, _ = x.shape
        x = F.pad(x, (0, 1))
        x = x.view(b, h, l * 2 * l)
        x = F.pad(x, (0, l - 1))
        return x.view(b, h, l + 1, 2 * l - 1)[:, :, :l, l - 1:]

    @staticmethod
    def _abs_to_rel(x: torch.Tensor) -> torch.Tensor:
        """(B, H, L, L) -> (B, H, L, 2L-1)."""
        b, h, l, _ = x.shape
        x = F.pad(x, (0, l - 1))
        x = x.view(b, h, l * (2 * l - 1))
        x = F.pad(x, (l, 0))
        return x.view(b, h, l, 2 * l)[:, :, :, 1:]

    def forward(self, x: torch.Tensor, attn_mask: torch.Tensor) -> torch.Tensor:
        b, d, t = x.shape
        q = self.conv_q(x).view(b, self.n_heads, self.k_channels, t).transpose(2, 3)
        k = self.conv_k(x).view(b, self.n_heads, self.k_channels, t).transpose(2, 3)
        v = self.conv_v(x).view(b, self.n_heads, self.k_channels, t).transpose(2, 3)

        scores = torch.matmul(q / math.sqrt(self.k_channels), k.transpose(-2, -1))
        rel_k = self._get_rel_embeddings(self.emb_rel_k, t)          # (1, 2t-1, dk)
        rel_logits = torch.matmul(q / math.sqrt(self.k_channels),
                                  rel_k.unsqueeze(0).transpose(-2, -1))
        scores = scores + self._rel_to_abs(rel_logits)

        scores = scores.masked_fill(attn_mask == 0, -1e4)
        p_attn = self.drop(F.softmax(scores, dim=-1))
        out = torch.matmul(p_attn, v)
        rel_w = self._abs_to_rel(p_attn)                             # (B,H,L,2L-1)
        rel_v = self._get_rel_embeddings(self.emb_rel_v, t)          # (1, 2t-1, dk)
        out = out + torch.matmul(rel_w, rel_v.unsqueeze(0))
        out = out.transpose(2, 3).contiguous().view(b, d, t)
        return self.conv_o(out)


class FFN(nn.Module):
    def __init__(self, channels: int, filter_channels: int,
                 kernel_size: int, p_dropout: float = 0.0):
        super().__init__()
        self.conv1 = nn.Conv1d(channels, filter_channels, kernel_size,
                               padding=kernel_size // 2)
        self.conv2 = nn.Conv1d(filter_channels, channels, kernel_size,
                               padding=kernel_size // 2)
        self.drop = nn.Dropout(p_dropout)

    def forward(self, x, x_mask):
        x = self.conv1(x * x_mask)
        x = self.drop(torch.relu(x))
        return self.conv2(x * x_mask) * x_mask


class TransformerEncoder(nn.Module):
    def __init__(self, hidden_channels: int, filter_channels: int,
                 n_heads: int, n_layers: int, kernel_size: int,
                 p_dropout: float, window: int):
        super().__init__()
        self.attn = nn.ModuleList()
        self.norm1 = nn.ModuleList()
        self.ffn = nn.ModuleList()
        self.norm2 = nn.ModuleList()
        self.drop = nn.Dropout(p_dropout)
        for _ in range(n_layers):
            self.attn.append(RelativeMultiHeadAttention(
                hidden_channels, n_heads, window, p_dropout))
            self.norm1.append(LayerNorm(hidden_channels))
            self.ffn.append(FFN(hidden_channels, filter_channels,
                                kernel_size, p_dropout))
            self.norm2.append(LayerNorm(hidden_channels))

    def forward(self, x, x_mask):
        attn_mask = x_mask.unsqueeze(2) * x_mask.unsqueeze(-1)
        x = x * x_mask
        for attn, n1, ffn, n2 in zip(self.attn, self.norm1,
                                     self.ffn, self.norm2):
            y = self.drop(attn(x, attn_mask))
            x = n1(x + y)
            y = self.drop(ffn(x, x_mask))
            x = n2(x + y)
        return x * x_mask


class TextEncoder(nn.Module):
    def __init__(self, n_vocab: int, out_channels: int, hidden_channels: int,
                 filter_channels: int, n_heads: int, n_layers: int,
                 kernel_size: int, p_dropout: float, window: int = 4,
                 n_languages: int = 0):
        super().__init__()
        self.hidden_channels = hidden_channels
        self.emb = nn.Embedding(n_vocab, hidden_channels)
        nn.init.normal_(self.emb.weight, 0.0, hidden_channels ** -0.5)
        self.emb_lang: Optional[nn.Embedding] = None
        if n_languages > 0:
            self.emb_lang = nn.Embedding(n_languages, hidden_channels)
            nn.init.zeros_(self.emb_lang.weight)
        self.encoder = TransformerEncoder(hidden_channels, filter_channels,
                                          n_heads, n_layers, kernel_size,
                                          p_dropout, window)
        self.proj = nn.Conv1d(hidden_channels, out_channels * 2, 1)

    def forward(self, x: torch.Tensor, x_lengths: torch.Tensor,
                lang: Optional[torch.Tensor] = None):
        x = self.emb(x) * math.sqrt(self.hidden_channels)   # (B, T, H)
        if self.emb_lang is not None and lang is not None:
            x = x + self.emb_lang(lang.clamp(0, self.emb_lang.num_embeddings - 1))
        x = x.transpose(1, 2)                               # (B, H, T)
        x_mask = sequence_mask(x_lengths, x.size(2)).unsqueeze(1).to(x.dtype)
        x = self.encoder(x, x_mask)
        stats = self.proj(x) * x_mask
        m, logs = torch.split(stats, stats.size(1) // 2, dim=1)
        return x, m, logs, x_mask
