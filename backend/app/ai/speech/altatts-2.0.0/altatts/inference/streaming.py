"""Streaming synthesis for live conversations.

The model is non-autoregressive: each phrase is generated in a single fast
forward pass. For live use (IVR prompts, voice agents, LLM read-out) the
right granularity is the PHRASE -- incoming text is split on sentence
punctuation and audio is emitted chunk by chunk, so the caller hears the
first phrase while later ones are still being synthesized. Exact pauses
(``[pause:0.5]``) stream as zero chunks; emotion tags carry across chunks.

    from altatts import Synthesizer, StreamingSynthesizer

    tts = Synthesizer.from_pretrained("runs/kinyarwanda")
    stream = StreamingSynthesizer(tts, voice="female", sample_rate=8000,
                                  emotion="calm")

    for chunk in stream.stream("Muraho. Murakaza neza kuri serivisi yacu."):
        play_or_send(chunk)          # float32 numpy audio

    for token in llm_tokens:         # incremental text (LLM token stream)
        for chunk in stream.feed(token):
            play_or_send(chunk)
    for chunk in stream.flush():
        play_or_send(chunk)
"""

from __future__ import annotations

import time
from typing import Generator, Optional

import numpy as np

from ..text import Silence
from .synthesizer import Synthesizer


def _crossfade(a: np.ndarray, b: np.ndarray, n: int) -> np.ndarray:
    """Concatenate with a short linear crossfade to avoid clicks."""
    n = min(n, len(a), len(b))
    if n <= 0:
        return np.concatenate([a, b])
    fade = np.linspace(0.0, 1.0, n, dtype=np.float32)
    a = a.copy()
    a[-n:] = a[-n:] * (1.0 - fade) + b[:n] * fade
    return np.concatenate([a, b[n:]])


def _find_boundary(text: str) -> int:
    """Index just after the first sentence boundary that is NOT inside a
    control tag (so "[pause:0.5]" or "<en>...</en>" never get cut)."""
    depth = 0
    for i, ch in enumerate(text):
        if ch in "[<":
            depth += 1
        elif ch in "]>":
            depth = max(0, depth - 1)
        elif depth == 0 and ch in ".?!;":
            return i + 1
    return -1


class StreamingSynthesizer:
    """Phrase-level streaming wrapper around :class:`Synthesizer`."""

    def __init__(
        self,
        synthesizer: Synthesizer,
        voice: str = "female",
        sample_rate: Optional[int] = None,
        speed: float = 1.0,
        noise_scale: float = 0.667,
        min_chars: int = 6,
        **tts_kwargs,
    ):
        self.tts = synthesizer
        self.voice = voice
        self.sample_rate = sample_rate or synthesizer.native_sr
        self.speed = speed
        self.noise_scale = noise_scale
        self.min_chars = min_chars
        self.tts_kwargs = dict(tts_kwargs)      # emotion, reference_audio, ...
        self._buffer = ""
        self.first_chunk_latency_s: Optional[float] = None
        self._embedding = None
        # resolve a reference ONCE so every chunk shares the same identity
        ref = self.tts_kwargs.pop("reference_audio", None)
        if ref is not None:
            self._embedding = synthesizer.embed_speaker(
                ref, self.tts_kwargs.pop("reference_sr", None))

    # ------------------------------------------------------------------ #
    def _synth(self, phrase: str) -> np.ndarray:
        kw = dict(self.tts_kwargs)
        if self._embedding is not None:
            kw["speaker_embedding"] = self._embedding
        wav, _ = self.tts.tts(phrase, voice=self.voice, sample_rate=self.sample_rate,
                              speed=self.speed, noise_scale=self.noise_scale, **kw)
        return wav

    def stream(self, text: str) -> Generator[np.ndarray, None, None]:
        """Yield one audio chunk per phrase of ``text`` (exact pauses are
        yielded as silent chunks)."""
        t0 = time.perf_counter()
        first = True
        plan = self.tts._plan(text, self.tts_kwargs.get("language"),
                              self.tts_kwargs.get("emotion"),
                              self.tts_kwargs.get("intensity"))
        for item in plan:
            if isinstance(item, Silence):
                yield np.zeros(int(item.seconds * self.sample_rate), dtype=np.float32)
                continue
            phrase = item.text
            if not phrase.strip():
                continue
            kw_emo = {}
            if item.emotion is not None:
                kw_emo = {"emotion": item.emotion, "intensity": item.intensity}
            saved = dict(self.tts_kwargs)
            self.tts_kwargs.update(kw_emo)
            try:
                wav = self._synth(phrase)
            finally:
                self.tts_kwargs = saved
            if first:
                self.first_chunk_latency_s = time.perf_counter() - t0
                first = False
            yield wav

    # ------------------------------------------------------------------ #
    #  Incremental interface (feed text as it arrives, e.g. LLM tokens)
    # ------------------------------------------------------------------ #
    def feed(self, text: str) -> Generator[np.ndarray, None, None]:
        """Add text to the buffer; yield audio for every completed phrase."""
        self._buffer += text
        while True:
            end = _find_boundary(self._buffer)
            if end < 0:
                return
            phrase, self._buffer = self._buffer[:end], self._buffer[end:]
            phrase = phrase.strip()
            if len(phrase) >= self.min_chars:
                for chunk in self.stream(phrase):
                    yield chunk
            elif phrase:
                # Too short to sound natural alone; keep for the next phrase.
                self._buffer = phrase + " " + self._buffer
                return

    def flush(self) -> Generator[np.ndarray, None, None]:
        """Synthesize whatever text remains in the buffer."""
        rest = self._buffer.strip()
        self._buffer = ""
        if rest:
            for chunk in self.stream(rest):
                yield chunk

    def reset(self, **kwargs) -> None:
        self._buffer = ""
        self.first_chunk_latency_s = None
        for k in ("voice", "sample_rate", "speed", "noise_scale"):
            if k in kwargs:
                setattr(self, k, kwargs.pop(k))
        self.tts_kwargs.update(kwargs)


def stream_to_wav(stream: Generator[np.ndarray, None, None],
                  crossfade_ms: float = 8.0,
                  sample_rate: int = 22050) -> np.ndarray:
    """Collect a chunk stream into one waveform (mainly for testing)."""
    out: Optional[np.ndarray] = None
    n = int(crossfade_ms / 1000.0 * sample_rate)
    for chunk in stream:
        out = chunk if out is None else _crossfade(out, chunk, n)
    return out if out is not None else np.zeros(0, dtype=np.float32)
