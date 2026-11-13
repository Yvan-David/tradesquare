"""Call-center integration helpers.

Turns ALTATTS output into the wire formats used by telephony platforms
(Twilio Media Streams, Asterisk/FreeSWITCH, SIP trunks in finance / health /
government contact centers), and shows how ALTASR + ALTATTS combine into a
full Kinyarwanda voice-agent loop.

Wire basics
-----------
Telephony audio is 8000 Hz, G.711-encoded (mu-law in the Americas/Twilio,
A-law in Europe/Africa), sent as 20 ms frames = 160 bytes per frame.

    from altatts import Synthesizer
    from altatts.integrations.callcenter import telephony_frames

    tts = Synthesizer.from_pretrained("runs/kinyarwanda")
    for frame in telephony_frames(tts, "Murakoze guhamagara.", voice="female"):
        rtp_or_websocket_send(frame)          # 160-byte G.711 payloads
"""

from __future__ import annotations

import base64
import json
import time
from typing import Callable, Generator

import numpy as np

from ..audio import to_mulaw, to_alaw, resample
from ..inference.synthesizer import Synthesizer
from ..inference.streaming import StreamingSynthesizer

TELEPHONY_SR = 8000
FRAME_MS = 20
FRAME_BYTES = TELEPHONY_SR * FRAME_MS // 1000          # 160 bytes @ G.711


# --------------------------------------------------------------------------- #
#  Framing
# --------------------------------------------------------------------------- #
def _encode(wav_8k: np.ndarray, encoding: str) -> bytes:
    if encoding == "mulaw":
        return to_mulaw(wav_8k)
    if encoding == "alaw":
        return to_alaw(wav_8k)
    raise ValueError(f"encoding must be 'mulaw' or 'alaw', got {encoding!r}")


def telephony_frames(
    tts: Synthesizer,
    text: str,
    voice: str = "female",
    encoding: str = "mulaw",
    frame_ms: int = FRAME_MS,
    **tts_kwargs,
) -> Generator[bytes, None, None]:
    """Synthesize ``text`` and yield fixed-size G.711 frames (default 20 ms).

    The last frame is zero-padded to full size, as telephony stacks expect.
    """
    wav, _ = tts.tts(text, voice=voice, sample_rate=TELEPHONY_SR, **tts_kwargs)
    payload = _encode(wav, encoding)
    n = TELEPHONY_SR * frame_ms // 1000
    pad = b"\x00" * n
    for i in range(0, len(payload), n):
        frame = payload[i:i + n]
        if len(frame) < n:
            frame = frame + pad[: n - len(frame)]
        yield frame


def streaming_telephony_frames(
    stream: StreamingSynthesizer,
    text: str,
    encoding: str = "mulaw",
    frame_ms: int = FRAME_MS,
) -> Generator[bytes, None, None]:
    """Phrase-streaming variant: first frames go out while later phrases are
    still being synthesized (lowest perceived latency on live calls)."""
    if stream.sample_rate != TELEPHONY_SR:
        raise ValueError("StreamingSynthesizer must use sample_rate=8000 "
                         "for telephony framing.")
    n = TELEPHONY_SR * frame_ms // 1000
    carry = b""
    for chunk in stream.stream(text):
        payload = carry + _encode(chunk, encoding)
        cut = len(payload) - len(payload) % n
        for i in range(0, cut, n):
            yield payload[i:i + n]
        carry = payload[cut:]
    if carry:
        yield carry + b"\x00" * (n - len(carry))


# --------------------------------------------------------------------------- #
#  Twilio Media Streams
# --------------------------------------------------------------------------- #
def twilio_media_messages(
    tts: Synthesizer,
    text: str,
    stream_sid: str,
    voice: str = "female",
    **tts_kwargs,
) -> Generator[str, None, None]:
    """Yield JSON 'media' messages for a Twilio Media Streams websocket.

        async for msg in websocket:            # your Twilio WS handler
            ...
        for m in twilio_media_messages(tts, reply_text, stream_sid):
            await websocket.send(m)
    """
    for frame in telephony_frames(tts, text, voice=voice,
                                  encoding="mulaw", **tts_kwargs):
        yield json.dumps({
            "event": "media",
            "streamSid": stream_sid,
            "media": {"payload": base64.b64encode(frame).decode("ascii")},
        })


# --------------------------------------------------------------------------- #
#  Full voice-agent loop (ALTASR + your logic + ALTATTS)
# --------------------------------------------------------------------------- #
class VoiceAgent:
    """Minimal listen -> think -> speak loop for a Kinyarwanda voice bot.

    ``respond_fn`` maps the caller's transcribed text to the agent's reply
    (rule-based IVR logic, retrieval, or an LLM -- your choice).

        from altasr import Transcriber
        from altatts import Synthesizer
        from altatts.integrations.callcenter import VoiceAgent

        agent = VoiceAgent(
            Transcriber.from_pretrained("path/to/altasr"),
            Synthesizer.from_pretrained("runs/kinyarwanda"),
            respond_fn=my_bot_logic,
            voice="female",
        )
        reply_audio_8k = agent.turn(caller_audio_8k, sample_rate=8000)

    Barge-in: telephony platforms deliver caller audio continuously. To
    support interruptions, run ``transcriber`` on the incoming stream while
    playing frames, and stop sending TTS frames the moment voice activity /
    a partial transcript appears; then call ``turn`` with the new utterance.
    """

    def __init__(
        self,
        transcriber,
        synthesizer: Synthesizer,
        respond_fn: Callable[[str], str],
        voice: str = "female",
        asr_sample_rate: int = 16000,
        **tts_kwargs,
    ):
        self.asr = transcriber
        self.tts = synthesizer
        self.respond_fn = respond_fn
        self.voice = voice
        self.asr_sr = asr_sample_rate
        self.tts_kwargs = dict(tts_kwargs)     # emotion="calm", steps=2, ...
        self.history: list = []

    def turn(self, caller_wav: np.ndarray, sample_rate: int
             ) -> tuple[np.ndarray, int]:
        """One conversational turn: caller audio in -> reply audio out."""
        wav16 = (caller_wav if sample_rate == self.asr_sr
                 else resample(caller_wav, sample_rate, self.asr_sr))
        heard = self.asr.transcribe(wav16, sample_rate=self.asr_sr)
        if isinstance(heard, dict):
            heard = heard.get("text", "")
        reply = self.respond_fn(str(heard))
        self.history.append({"caller": str(heard), "agent": reply,
                             "time": time.time()})
        out, sr = self.tts.tts(reply, voice=self.voice,
                               sample_rate=sample_rate, **self.tts_kwargs)
        return out, sr


# --------------------------------------------------------------------------- #
#  Agent voices -- add a human agent's voice without training
# --------------------------------------------------------------------------- #
def enroll_agent(tts: Synthesizer, name: str, audio_clips, gender=None,
                 **meta) -> dict:
    """Enroll a call-center agent from a few recorded sentences (10-30 s
    total) so ``voice=name`` speaks with their voice from now on; persisted
    in the model folder's voices.json."""
    return tts.enroll_speaker(name, list(audio_clips), gender=gender, **meta)


# --------------------------------------------------------------------------- #
#  Prompt cache -- pre-render fixed IVR prompts (menus, disclaimers)
# --------------------------------------------------------------------------- #
def prerender_prompts(
    tts: Synthesizer,
    prompts,
    out_dir: str,
    voice: str = "female",
    sample_rate: int = TELEPHONY_SR,
    **tts_kwargs,
) -> dict:
    """Render (name, text) prompts to WAV files; returns {name: path}.

    Fixed prompts (greetings, legal disclaimers for finance/health lines,
    menu options) should be rendered once and streamed from disk -- zero
    latency and zero GPU load at call time.
    """
    import os

    os.makedirs(out_dir, exist_ok=True)
    table = {}
    items = prompts.items() if isinstance(prompts, dict) else prompts
    for name, text in items:
        path = os.path.join(out_dir, f"{name}.wav")
        tts.tts_to_file(text, path, voice=voice, sample_rate=sample_rate,
                        **tts_kwargs)
        table[name] = path
    return table
