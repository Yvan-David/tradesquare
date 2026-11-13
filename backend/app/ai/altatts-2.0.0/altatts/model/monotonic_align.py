"""
Monotonic Alignment Search (MAS) -- Glow-TTS/VITS training alignment.

Given the frame-wise log-likelihood of each latent frame under each
character's prior Gaussian, MAS finds the monotonic, surjective alignment
that maximises total likelihood by dynamic programming:

    Q[j, t] = ll[j, t] + max(Q[j, t-1], Q[j-1, t-1])

then backtracks the argmax path. Because the model learns its own alignment,
NO forced aligner, phoneme durations, or external labels are ever needed --
an ASR corpus (audio + transcript) is sufficient.

Implementation: the recursion is vectorised over the text axis, so the
Python loop runs over mel frames only (~100x faster than the scalar
double loop and still zero build steps). When ``numba`` is installed the
scalar kernel is JIT-compiled instead (another ~10x; ``pip install numba``).
"""
from __future__ import annotations

import numpy as np
import torch

try:                                   # optional accelerator
    from numba import njit as _njit
except Exception:                      # pragma: no cover  # noqa: BLE001
    _njit = None


def _mas_numpy(ll: np.ndarray) -> np.ndarray:
    """ll: (T_text, T_mel) log-likelihoods -> hard path (T_text, T_mel)."""
    t_x, t_y = ll.shape
    neg = -np.inf
    q = np.full(t_x, neg, dtype=np.float64)
    q[0] = ll[0, 0]
    back = np.zeros((t_x, t_y), dtype=np.bool_)      # True = came from j-1
    diag = np.empty(t_x, dtype=np.float64)
    for t in range(1, t_y):
        diag[0] = neg
        diag[1:] = q[:-1]
        take = diag > q
        new = ll[:, t] + np.where(take, diag, q)
        j_lo = t_x - (t_y - t)                      # must still be reachable
        if j_lo > 0:
            new[:j_lo] = neg
        if t + 1 < t_x:
            new[t + 1:] = neg
        back[:, t] = take
        q = new
    path = np.zeros((t_x, t_y), dtype=np.float32)
    j = t_x - 1
    for t in range(t_y - 1, -1, -1):
        path[j, t] = 1.0
        if back[j, t] and j > 0:
            j -= 1
    return path


if _njit is not None:                  # pragma: no cover (depends on numba)
    @_njit(cache=True)
    def _mas_numba(ll):                # type: ignore[no-redef]
        t_x, t_y = ll.shape
        q = np.full((t_x, t_y), -np.inf)
        back = np.zeros((t_x, t_y), dtype=np.int8)
        q[0, 0] = ll[0, 0]
        for t in range(1, t_y):
            j_lo = max(0, t_x - (t_y - t))
            j_hi = min(t_x - 1, t)
            for j in range(j_lo, j_hi + 1):
                stay = q[j, t - 1]
                diag = q[j - 1, t - 1] if j > 0 else -np.inf
                if diag > stay:
                    q[j, t] = ll[j, t] + diag
                    back[j, t] = 1
                else:
                    q[j, t] = ll[j, t] + stay
        path = np.zeros((t_x, t_y), dtype=np.float32)
        j = t_x - 1
        for t in range(t_y - 1, -1, -1):
            path[j, t] = 1.0
            if back[j, t] == 1 and j > 0:
                j -= 1
        return path

    _mas_single = _mas_numba
else:
    _mas_single = _mas_numpy


def maximum_path(neg_cent: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    """Batched MAS.

    neg_cent: (B, T_mel, T_text) log-likelihood of each (frame, char) pair.
    mask:     (B, T_mel, T_text) validity mask.
    Returns the hard alignment path, same shape, on neg_cent's device.
    """
    device, dtype = neg_cent.device, neg_cent.dtype
    ll = neg_cent.detach().float().cpu().numpy().astype(np.float64)
    msk = mask.detach().cpu().numpy().astype(bool)
    out = np.zeros_like(ll, dtype=np.float32)
    for b in range(ll.shape[0]):
        t_y = int(msk[b].any(axis=1).sum())     # valid mel frames
        t_x = int(msk[b].any(axis=0).sum())     # valid text tokens
        if t_x and t_y:
            # _mas_single works in (T_text, T_mel) orientation
            out[b, :t_y, :t_x] = _mas_single(
                np.ascontiguousarray(ll[b, :t_y, :t_x].T)).T
    return torch.from_numpy(out).to(device=device, dtype=dtype)
