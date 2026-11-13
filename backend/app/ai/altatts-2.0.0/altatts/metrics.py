"""
TTS evaluation metrics -- the global standards, self-contained in numpy.

The TTS literature and challenges (Blizzard, VoiceMOS, ITU-T P.800/P.808)
evaluate along four axes. ALTATTS implements the standard objective proxy for
each; the subjective gold standard (MOS) is documented in docs/USAGE.md with
the protocol to run it, and ``predicted_mos`` gives an automatic neural
estimate when torchaudio's SQUIM model is available.

1. Spectral accuracy  -> **MCD** (Mel-Cepstral Distortion, dB), computed on
   DTW-aligned mel-cepstra (13 coefficients, c0 excluded). Lower is better;
   strong neural TTS lands in the 4-7 dB range against held-out ground truth.

       MCD = (10 / ln 10) * sqrt(2 * sum_k (c_k^ref - c_k^syn)^2)

2. Prosody accuracy   -> **F0 RMSE** (Hz, voiced frames, DTW-aligned) and the
   **V/UV error rate** (fraction of frames where voicing decisions disagree).

3. Intelligibility    -> **CER/WER of an ASR round trip**: synthesize the test
   sentences, transcribe them with ALTASR, score against the input text. This
   is exactly the protocol used for low-resource TTS in the literature, and it
   reuses your own best-in-class Kinyarwanda ASR as the judge.

4. Naturalness        -> **MOS** (human, 1-5, ITU-T P.800 ACR) and
   **predicted MOS** (SQUIM subjective / UTMOS-style neural estimator).

Plus deployment metrics: **RTF** (synthesis seconds / audio seconds; < 1 is
faster than real time; call centers want << 0.5) and **first-chunk latency**
for streaming.

Corpus conventions match ALTASR's metrics module: corpus rates aggregate
numerators and denominators over all utterances, never averaging
per-utterance rates.
"""
from __future__ import annotations

import math
import time
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np

from .audio import mel_filterbank


# ---------------------------------------------------------------------------- #
#  numpy STFT + mel cepstra
# ---------------------------------------------------------------------------- #
def _stft_mag(wav: np.ndarray, n_fft: int = 1024, hop: int = 256) -> np.ndarray:
    if len(wav) < n_fft:
        wav = np.pad(wav, (0, n_fft - len(wav)))
    pad = n_fft // 2
    wav = np.pad(wav, (pad, pad), mode="reflect")
    n_frames = 1 + (len(wav) - n_fft) // hop
    idx = np.arange(n_fft)[None, :] + hop * np.arange(n_frames)[:, None]
    frames = wav[idx] * np.hanning(n_fft)[None, :]
    return np.abs(np.fft.rfft(frames, axis=1))          # (T, n_fft//2+1)


def mel_cepstra(wav: np.ndarray, sr: int, n_mfc: int = 13, n_mels: int = 40,
                n_fft: int = 1024, hop: int = 256) -> np.ndarray:
    """(T, n_mfc) mel-cepstral coefficients c1..c13 (c0/energy excluded)."""
    mag = _stft_mag(wav, n_fft, hop)
    fb = mel_filterbank(sr, n_fft, n_mels)               # (n_mels, F)
    logmel = np.log(np.maximum(mag @ fb.T, 1e-8))        # (T, n_mels)
    # DCT-II, orthonormal
    n = n_mels
    k = np.arange(n_mfc + 1)[:, None]
    basis = np.cos(np.pi * k * (2 * np.arange(n)[None, :] + 1) / (2 * n))
    basis *= math.sqrt(2.0 / n)
    basis[0] /= math.sqrt(2.0)
    cep = logmel @ basis.T                               # (T, n_mfc+1)
    return cep[:, 1:]                                    # drop c0


# ---------------------------------------------------------------------------- #
#  DTW
# ---------------------------------------------------------------------------- #
def dtw_path(a: np.ndarray, b: np.ndarray) -> List[Tuple[int, int]]:
    """Standard DTW on Euclidean frame distances; returns the aligned pairs."""
    Ta, Tb = len(a), len(b)
    dist = np.sqrt(((a[:, None, :] - b[None, :, :]) ** 2).sum(-1) + 1e-12)
    acc = np.full((Ta + 1, Tb + 1), np.inf)
    acc[0, 0] = 0.0
    for i in range(1, Ta + 1):
        for j in range(1, Tb + 1):
            acc[i, j] = dist[i - 1, j - 1] + min(acc[i - 1, j],
                                                 acc[i, j - 1],
                                                 acc[i - 1, j - 1])
    path, i, j = [], Ta, Tb
    while i > 0 and j > 0:
        path.append((i - 1, j - 1))
        step = int(np.argmin((acc[i - 1, j - 1], acc[i - 1, j], acc[i, j - 1])))
        if step == 0:
            i, j = i - 1, j - 1
        elif step == 1:
            i -= 1
        else:
            j -= 1
    return path[::-1]


# ---------------------------------------------------------------------------- #
#  MCD
# ---------------------------------------------------------------------------- #
_MCD_CONST = 10.0 / math.log(10.0) * math.sqrt(2.0)


def mcd(ref_wav: np.ndarray, syn_wav: np.ndarray, sr: int) -> float:
    """Mel-Cepstral Distortion in dB (DTW-aligned, c1..c13). Lower = better."""
    c_ref = mel_cepstra(ref_wav, sr)
    c_syn = mel_cepstra(syn_wav, sr)
    if len(c_ref) == 0 or len(c_syn) == 0:
        return float("nan")
    path = dtw_path(c_ref, c_syn)
    d = [np.sqrt(((c_ref[i] - c_syn[j]) ** 2).sum()) for i, j in path]
    return float(_MCD_CONST * np.mean(d))


# ---------------------------------------------------------------------------- #
#  F0 (autocorrelation) + prosody metrics
# ---------------------------------------------------------------------------- #
def estimate_f0(wav: np.ndarray, sr: int, fmin: float = 65.0,
                fmax: float = 400.0, frame_ms: float = 40.0,
                hop_ms: float = 10.0, voicing_thresh: float = 0.30
                ) -> np.ndarray:
    """Frame-wise F0 in Hz via normalised autocorrelation; 0 = unvoiced."""
    frame = int(sr * frame_ms / 1000)
    hop = int(sr * hop_ms / 1000)
    lag_min = max(2, int(sr / fmax))
    lag_max = min(frame - 1, int(sr / fmin))
    if len(wav) < frame or lag_max <= lag_min:
        return np.zeros(0, dtype=np.float32)
    n = 1 + (len(wav) - frame) // hop
    energy_gate = 0.02 * np.sqrt(np.mean(wav ** 2) + 1e-12)
    f0 = np.zeros(n, dtype=np.float32)
    for t in range(n):
        seg = wav[t * hop: t * hop + frame]
        seg = seg - seg.mean()
        rms = np.sqrt(np.mean(seg ** 2) + 1e-12)
        if rms < energy_gate:
            continue
        ac = np.correlate(seg, seg, mode="full")[frame - 1:]
        if ac[0] <= 0:
            continue
        ac = ac / ac[0]
        lag = lag_min + int(np.argmax(ac[lag_min: lag_max + 1]))
        if ac[lag] >= voicing_thresh:
            f0[t] = sr / lag
    return f0


def f0_metrics(ref_wav: np.ndarray, syn_wav: np.ndarray, sr: int
               ) -> Dict[str, float]:
    """F0 RMSE (Hz, voiced&voiced, DTW-aligned) and V/UV error rate."""
    f_ref = estimate_f0(ref_wav, sr)
    f_syn = estimate_f0(syn_wav, sr)
    if len(f_ref) == 0 or len(f_syn) == 0:
        return {"f0_rmse_hz": float("nan"), "vuv_error": float("nan")}
    path = dtw_path(f_ref[:, None], f_syn[:, None])
    both, sq, vuv_err = 0, 0.0, 0
    for i, j in path:
        rv, sv = f_ref[i] > 0, f_syn[j] > 0
        vuv_err += int(rv != sv)
        if rv and sv:
            both += 1
            sq += (f_ref[i] - f_syn[j]) ** 2
    return {"f0_rmse_hz": float(math.sqrt(sq / both)) if both else float("nan"),
            "vuv_error": vuv_err / max(1, len(path))}


def median_f0(wav: np.ndarray, sr: int) -> float:
    f0 = estimate_f0(wav, sr)
    voiced = f0[f0 > 0]
    return float(np.median(voiced)) if len(voiced) else float("nan")


# Typical adult ranges: male median F0 ~85-155 Hz, female ~165-255 Hz.
GENDER_F0_THRESHOLD = 160.0


def gender_from_f0(wav: np.ndarray, sr: int,
                   threshold: float = GENDER_F0_THRESHOLD) -> Optional[str]:
    m = median_f0(wav, sr)
    if math.isnan(m):
        return None
    return "female" if m >= threshold else "male"


# ---------------------------------------------------------------------------- #
#  Intelligibility (ASR round trip) -- WER/CER shared with ALTASR conventions
# ---------------------------------------------------------------------------- #
def edit_distance(ref: Sequence, hyp: Sequence) -> int:
    if not ref:
        return len(hyp)
    if not hyp:
        return len(ref)
    prev = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, start=1):
        cur = [i] + [0] * len(hyp)
        for j, h in enumerate(hyp, start=1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (r != h))
        prev = cur
    return prev[-1]


def wer(ref: str, hyp: str) -> float:
    r, h = ref.split(), hyp.split()
    return edit_distance(r, h) / max(1, len(r))


def cer(ref: str, hyp: str) -> float:
    r, h = list(ref.replace(" ", "")), list(hyp.replace(" ", ""))
    return edit_distance(r, h) / max(1, len(r))


def corpus_wer_cer(refs: Sequence[str], hyps: Sequence[str]
                   ) -> Tuple[float, float]:
    """Corpus-level rates: summed edits / summed reference lengths."""
    wd = wn = cd = cn = 0
    for r, h in zip(refs, hyps):
        wd += edit_distance(r.split(), h.split())
        wn += max(1, len(r.split()))
        cd += edit_distance(list(r.replace(" ", "")), list(h.replace(" ", "")))
        cn += max(1, len(r.replace(" ", "")))
    return wd / max(1, wn), cd / max(1, cn)


# ---------------------------------------------------------------------------- #
#  Predicted MOS (optional neural estimator)
# ---------------------------------------------------------------------------- #
_squim_model = None


def predicted_mos(syn_wav: np.ndarray, sr: int,
                  reference_wav: Optional[np.ndarray] = None,
                  reference_sr: int = 0) -> Optional[float]:
    """Neural MOS estimate via torchaudio SQUIM (subjective); None if the
    model is unavailable (it downloads weights on first use).

    ``reference_wav`` is a *non-matching reference*: any clean real speech
    clip (e.g. a ground-truth utterance from your corpus). Estimates
    correlate with -- but do not replace -- human MOS (see docs/USAGE.md for
    the P.800 protocol).
    """
    global _squim_model
    try:
        import torch
        import torchaudio
        from torchaudio.pipelines import SQUIM_SUBJECTIVE
        from .audio import resample as _rs
        if _squim_model is None:
            _squim_model = SQUIM_SUBJECTIVE.get_model()
        s = torch.from_numpy(_rs(syn_wav, sr, 16_000)).unsqueeze(0)
        if reference_wav is None:
            reference_wav, reference_sr = syn_wav, sr
        r = torch.from_numpy(_rs(reference_wav, reference_sr, 16_000)).unsqueeze(0)
        with torch.no_grad():
            return float(_squim_model(s, r).item())
    except Exception:                                        # noqa: BLE001
        return None


# ---------------------------------------------------------------------------- #
#  RTF
# ---------------------------------------------------------------------------- #
class Stopwatch:
    def __enter__(self):
        self.t0 = time.perf_counter()
        return self

    def __exit__(self, *a):
        self.seconds = time.perf_counter() - self.t0


def rtf(processing_seconds: float, audio_seconds: float) -> float:
    return processing_seconds / max(1e-9, audio_seconds)


# ---------------------------------------------------------------------------- #
#  Corpus aggregation
# ---------------------------------------------------------------------------- #
def corpus_tts_metrics(pairs: Sequence[Dict]) -> Dict[str, float]:
    """Aggregate per-utterance metric dicts (NaNs skipped) into corpus means,
    plus corpus WER/CER when 'ref_text'/'hyp_text' are present."""
    out: Dict[str, float] = {}
    keys = ("mcd_db", "f0_rmse_hz", "vuv_error", "pmos", "rtf",
            "gender_match")
    for k in keys:
        vals = [p[k] for p in pairs if k in p and p[k] is not None
                and not (isinstance(p[k], float) and math.isnan(p[k]))]
        if vals:
            out[k] = float(np.mean(vals))
    refs = [p["ref_text"] for p in pairs if "ref_text" in p and "hyp_text" in p]
    hyps = [p["hyp_text"] for p in pairs if "ref_text" in p and "hyp_text" in p]
    if refs:
        w, c = corpus_wer_cer(refs, hyps)
        out["asr_wer"], out["asr_cer"] = w, c
    out["n_utterances"] = len(pairs)
    return out
