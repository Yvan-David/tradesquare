"""
Audio layer: decoding, spectrograms, resampling, telephony output.

Decoding mirrors ALTASR's robustness policy: try soundfile, then torchaudio,
then PyAV, and raise ``AudioDecodeError`` carrying every backend's reason if
all fail (training substitutes a neighbour and warns, exactly like ALTASR).

Spectrograms
------------
The model consumes/produces audio at ONE native rate (``AudioConfig.sample_rate``,
default 22050). Two feature views are computed with torch (GPU-friendly, exact
across train/infer):

* ``spectrogram_torch``       -- linear magnitude STFT (posterior encoder input)
* ``mel_spectrogram_torch``   -- log-mel (reconstruction loss + evaluation)

The mel filterbank is Slaney-style (area-normalised triangles), matching the
librosa convention the TTS literature standardises on, implemented here in
numpy so librosa is not a dependency.

Sample-rate flexibility
-----------------------
``resample`` converts the synthesized waveform to any caller-requested rate
(8000 for telephony, 16000 to feed ALTASR, 44100/48000 for media). ``to_pcm16``
/ ``to_mulaw`` / ``to_alaw`` produce the wire formats used by call-center
stacks (Twilio media streams, Asterisk/FreeSWITCH, SIP trunks).
"""
from __future__ import annotations

import io
import math
import os
from typing import Dict, Tuple

import numpy as np

try:                      # torch is required for the model layers, but the
    import torch          # numpy helpers below stay importable without it.
except Exception:         # pragma: no cover
    torch = None


class AudioDecodeError(RuntimeError):
    """Raised when every decoding backend fails; carries per-backend reasons."""

    def __init__(self, path: str, reasons: Dict[str, str]):
        self.path, self.reasons = path, reasons
        detail = "; ".join(f"{k}: {v}" for k, v in reasons.items())
        super().__init__(f"could not decode {path!r} ({detail})")


# ---------------------------------------------------------------------------- #
#  Decoding (numpy in, mono float32 out)
# ---------------------------------------------------------------------------- #
def load_audio(path: str, target_sr: int) -> np.ndarray:
    """Decode any common audio file to mono float32 at ``target_sr``."""
    reasons: Dict[str, str] = {}

    try:
        import soundfile as sf
        wav, sr = sf.read(path, dtype="float32", always_2d=True)
        wav = wav.mean(axis=1)
        return _resample_np(wav, sr, target_sr)
    except Exception as e:                                    # noqa: BLE001
        reasons["soundfile"] = str(e)

    if torch is not None:
        try:
            import torchaudio
            wav, sr = torchaudio.load(path)
            wav = wav.mean(dim=0).numpy().astype(np.float32)
            return _resample_np(wav, sr, target_sr)
        except Exception as e:                                # noqa: BLE001
            reasons["torchaudio"] = str(e)

    try:
        import av  # PyAV: pip install "altatts[av]"
        with av.open(path) as container:
            stream = container.streams.audio[0]
            resampler = av.AudioResampler(format="fltp", layout="mono",
                                          rate=target_sr)
            chunks = []
            for frame in container.decode(stream):
                for rf in resampler.resample(frame):
                    chunks.append(rf.to_ndarray().reshape(-1))
        if chunks:
            return np.concatenate(chunks).astype(np.float32)
        reasons["av"] = "no audio frames"
    except Exception as e:                                    # noqa: BLE001
        reasons["av"] = str(e)

    # Final fallback: the ffmpeg binary itself. Decodes anything ffmpeg can
    # (webm/opus/m4a/aac/extension-less files) with zero Python deps.
    if _ffmpeg_bin():
        try:
            import subprocess
            proc = subprocess.run(
                [_ffmpeg_bin(), "-v", "error", "-i", path,
                 "-f", "f32le", "-acodec", "pcm_f32le",
                 "-ac", "1", "-ar", str(target_sr), "pipe:1"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
            if proc.returncode == 0 and proc.stdout:
                return np.frombuffer(proc.stdout, dtype=np.float32).copy()
            reasons["ffmpeg"] = (proc.stderr.decode("utf-8", "replace")
                                 .strip()[:200] or "no output")
        except Exception as e:                                # noqa: BLE001
            reasons["ffmpeg"] = str(e)
    else:
        reasons["ffmpeg"] = "binary not found on PATH"

    reasons["hint"] = ("install a decoder for this format: pip install av "
                       "(recommended, handles webm/opus/m4a/mp3), or "
                       "apt-get install ffmpeg, or pip install torchcodec")
    raise AudioDecodeError(path, reasons)


_FFMPEG_BIN = None


def _ffmpeg_bin():
    global _FFMPEG_BIN
    if _FFMPEG_BIN is None:
        import shutil
        _FFMPEG_BIN = shutil.which("ffmpeg") or ""
    return _FFMPEG_BIN


def _resample_np(wav: np.ndarray, sr: int, target_sr: int) -> np.ndarray:
    if sr == target_sr:
        return np.ascontiguousarray(wav, dtype=np.float32)
    if torch is not None:
        import torchaudio.functional as AF
        t = torch.from_numpy(np.ascontiguousarray(wav, dtype=np.float32))
        return AF.resample(t, sr, target_sr).numpy()
    # numpy fallback: polyphase-free linear interpolation (metrics-grade only)
    n_out = int(round(len(wav) * target_sr / sr))
    x_old = np.linspace(0.0, 1.0, num=len(wav), endpoint=False)
    x_new = np.linspace(0.0, 1.0, num=n_out, endpoint=False)
    return np.interp(x_new, x_old, wav).astype(np.float32)


def trim_silence(wav: np.ndarray, sr: int, top_db: float = 35.0,
                 frame_ms: float = 25.0, pad_ms: float = 60.0) -> np.ndarray:
    """Energy-based leading/trailing silence trim with a small kept pad."""
    frame = max(1, int(sr * frame_ms / 1000))
    if len(wav) < 2 * frame:
        return wav
    n = len(wav) // frame
    rms = np.sqrt(np.mean(wav[: n * frame].reshape(n, frame) ** 2, axis=1) + 1e-12)
    thresh = rms.max() * (10.0 ** (-top_db / 20.0))
    keep = np.where(rms > thresh)[0]
    if len(keep) == 0:
        return wav
    pad = int(sr * pad_ms / 1000)
    start = max(0, keep[0] * frame - pad)
    end = min(len(wav), (keep[-1] + 1) * frame + pad)
    return wav[start:end]


def peak_normalize(wav: np.ndarray, peak: float = 0.95) -> np.ndarray:
    m = float(np.max(np.abs(wav)) + 1e-9)
    return (wav * (peak / m)).astype(np.float32) if m > 0 else wav


# ---------------------------------------------------------------------------- #
#  Mel filterbank (Slaney / librosa convention), numpy
# ---------------------------------------------------------------------------- #
def _hz_to_mel(f):
    f = np.asanyarray(f, dtype=np.float64)
    mel = 3.0 * f / 200.0
    log_step = math.log(6.4) / 27.0
    above = f >= 1000.0
    mel = np.where(above, 15.0 + np.log(np.maximum(f, 1e-10) / 1000.0) / log_step, mel)
    return mel


def _mel_to_hz(m):
    m = np.asanyarray(m, dtype=np.float64)
    f = 200.0 * m / 3.0
    log_step = math.log(6.4) / 27.0
    above = m >= 15.0
    return np.where(above, 1000.0 * np.exp(log_step * (m - 15.0)), f)


def mel_filterbank(sr: int, n_fft: int, n_mels: int,
                   fmin: float = 0.0, fmax: float = 0.0) -> np.ndarray:
    """(n_mels, n_fft//2+1) Slaney-normalised triangular filterbank."""
    fmax = fmax or sr / 2.0
    fft_freqs = np.linspace(0.0, sr / 2.0, n_fft // 2 + 1)
    mel_pts = np.linspace(_hz_to_mel(fmin), _hz_to_mel(fmax), n_mels + 2)
    hz_pts = _mel_to_hz(mel_pts)
    fb = np.zeros((n_mels, len(fft_freqs)), dtype=np.float64)
    fdiff = np.diff(hz_pts)
    ramps = hz_pts.reshape(-1, 1) - fft_freqs.reshape(1, -1)
    for i in range(n_mels):
        lower = -ramps[i] / fdiff[i]
        upper = ramps[i + 2] / fdiff[i + 1]
        fb[i] = np.maximum(0.0, np.minimum(lower, upper))
    enorm = 2.0 / (hz_pts[2: n_mels + 2] - hz_pts[:n_mels])
    fb *= enorm[:, None]
    return fb.astype(np.float32)


# ---------------------------------------------------------------------------- #
#  Torch spectrograms (train / inference exactness)
# ---------------------------------------------------------------------------- #
_hann_cache: Dict[Tuple, "torch.Tensor"] = {}
_mel_cache: Dict[Tuple, "torch.Tensor"] = {}


def spectrogram_torch(y: "torch.Tensor", n_fft: int, hop_length: int,
                      win_length: int) -> "torch.Tensor":
    """Linear magnitude spectrogram, (B, n_fft//2+1, T). y: (B, samples)."""
    key = (win_length, y.device, y.dtype)
    win = _hann_cache.get(key)
    if win is None:
        win = torch.hann_window(win_length, device=y.device, dtype=y.dtype)
        _hann_cache[key] = win
    pad = (n_fft - hop_length) // 2
    y = torch.nn.functional.pad(y.unsqueeze(1), (pad, pad), mode="reflect").squeeze(1)
    spec = torch.stft(y, n_fft, hop_length=hop_length, win_length=win_length,
                      window=win, center=False, pad_mode="reflect",
                      normalized=False, onesided=True, return_complex=True)
    return torch.sqrt(spec.real.pow(2) + spec.imag.pow(2) + 1e-6)


def spec_to_mel_torch(spec: "torch.Tensor", sr: int, n_fft: int, n_mels: int,
                      fmin: float, fmax: float) -> "torch.Tensor":
    key = (sr, n_fft, n_mels, fmin, fmax, spec.device, spec.dtype)
    fb = _mel_cache.get(key)
    if fb is None:
        fb = torch.from_numpy(mel_filterbank(sr, n_fft, n_mels, fmin, fmax))
        fb = fb.to(device=spec.device, dtype=spec.dtype)
        _mel_cache[key] = fb
    mel = torch.matmul(fb, spec)
    return torch.log(torch.clamp(mel, min=1e-5))


def mel_spectrogram_torch(y: "torch.Tensor", sr: int, n_fft: int,
                          hop_length: int, win_length: int, n_mels: int,
                          fmin: float = 0.0, fmax: float = 0.0) -> "torch.Tensor":
    spec = spectrogram_torch(y, n_fft, hop_length, win_length)
    return spec_to_mel_torch(spec, sr, n_fft, n_mels, fmin, fmax)


# ---------------------------------------------------------------------------- #
#  Output-rate conversion & telephony wire formats
# ---------------------------------------------------------------------------- #
def resample(wav: np.ndarray, sr: int, target_sr: int) -> np.ndarray:
    """High-quality resampling of a synthesized waveform to any rate."""
    return _resample_np(wav, sr, target_sr)


def to_pcm16(wav: np.ndarray) -> bytes:
    wav = np.clip(wav, -1.0, 1.0)
    return (wav * 32767.0).astype("<i2").tobytes()


def to_mulaw(wav: np.ndarray) -> bytes:
    """G.711 mu-law bytes (8-bit) -- pair with an 8000 Hz waveform."""
    mu = 255.0
    wav = np.clip(wav, -1.0, 1.0)
    mag = np.log1p(mu * np.abs(wav)) / np.log1p(mu)
    comp = np.sign(wav) * mag
    return ((comp + 1.0) / 2.0 * mu + 0.5).astype(np.uint8).tobytes()


def to_alaw(wav: np.ndarray) -> bytes:
    """G.711 A-law bytes (8-bit) -- pair with an 8000 Hz waveform."""
    A = 87.6
    wav = np.clip(wav, -1.0, 1.0)
    ax = np.abs(wav)
    small = ax < (1.0 / A)
    comp = np.where(small, A * ax / (1.0 + math.log(A)),
                    (1.0 + np.log(np.maximum(A * ax, 1e-12))) / (1.0 + math.log(A)))
    y = np.sign(wav) * comp
    pcm = (np.clip(y, -1.0, 1.0) * 32767.0).astype(np.int16)
    out = np.empty(len(pcm), dtype=np.uint8)
    for i, s in enumerate(pcm):                 # scalar loop: clarity > speed
        sign = 0x80 if s >= 0 else 0
        s = min(abs(int(s)), 32767) >> 3        # 13-bit magnitude
        if s >= 32:
            exp = int(math.floor(math.log2(s))) - 4
            mant = (s >> exp) & 0x0F
            byte = (exp << 4) | mant
        else:
            byte = s >> 1
        out[i] = (byte ^ 0x55) | sign
    return out.tobytes()


def _wav_pcm16_bytes(wav: np.ndarray, sr: int) -> bytes:
    """RIFF/WAV via the stdlib (16-bit PCM) -- no soundfile needed."""
    import wave
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(to_pcm16(wav))
    return buf.getvalue()


def save_wav(path: str, wav: np.ndarray, sr: int) -> None:
    parent = os.path.dirname(os.path.abspath(path))
    os.makedirs(parent, exist_ok=True)
    try:
        import soundfile as sf
        sf.write(path, np.clip(wav, -1.0, 1.0), sr)
    except ImportError:
        with open(path, "wb") as f:
            f.write(_wav_pcm16_bytes(wav, sr))


def wav_bytes(wav: np.ndarray, sr: int) -> bytes:
    """In-memory RIFF/WAV (16-bit PCM) -- convenient for web/IVR responses."""
    try:
        import soundfile as sf
        buf = io.BytesIO()
        sf.write(buf, np.clip(wav, -1.0, 1.0), sr, format="WAV",
                 subtype="PCM_16")
        return buf.getvalue()
    except ImportError:
        return _wav_pcm16_bytes(wav, sr)
