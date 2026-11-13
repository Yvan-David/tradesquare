"""Audio helpers for ALTA live transcription (16 kHz mono)."""

from __future__ import annotations

import array
import struct
from typing import Iterable


# ALTA live docs: mono 16 kHz. Default frames are float32 LE (~50 ms = 3200 bytes).
# Optional start.audio.encoding = pcm_s16le uses 1600 bytes / 50 ms.
TARGET_SR = 16000
FRAME_MS = 50
SAMPLES_PER_FRAME = TARGET_SR * FRAME_MS // 1000  # 800
BYTES_F32_FRAME = SAMPLES_PER_FRAME * 4  # 3200 (default)
BYTES_S16_FRAME = SAMPLES_PER_FRAME * 2  # 1600 (pcm_s16le)
MAX_FRAME_BYTES = 4194304


def pcm_s16le_frames(pcm_s16le: bytes, frame_bytes: int = BYTES_S16_FRAME) -> Iterable[bytes]:
    for i in range(0, len(pcm_s16le), frame_bytes):
        chunk = pcm_s16le[i : i + frame_bytes]
        if chunk:
            yield chunk


def float32_le_to_pcm_s16le(pcm_f32le: bytes) -> bytes:
    count = len(pcm_f32le) // 4
    floats = struct.unpack("<" + "f" * count, pcm_f32le[: count * 4])
    out = array.array("h")
    for sample in floats:
        clipped = max(-1.0, min(1.0, float(sample)))
        out.append(int(clipped * 32767.0))
    return out.tobytes()


def validate_live_audio_hint(
    *,
    sample_rate: int | None,
    channels: int | None,
    encoding: str,
) -> list[str]:
    """Return warnings — never silently assume LiveKit track format matches ALTA."""
    warnings: list[str] = []
    if sample_rate is not None and sample_rate != TARGET_SR:
        warnings.append(
            f"sample_rate={sample_rate} must be resampled to {TARGET_SR} Hz before ALTA."
        )
    if channels is not None and channels != 1:
        warnings.append(f"channels={channels}; ALTA expects mono — downmix required.")
    if encoding not in {"pcm_s16le", "pcm_f32le", "float32"}:
        warnings.append(
            f"encoding={encoding!r} is not an ALTA-native PCM type; convert before send."
        )
    return warnings
