"""
Tiny client for an ``altatts serve`` endpoint (standard library only).

    from altatts.client import TTSClient
    api = TTSClient("http://tts.internal:8081")
    wav, sr = api.tts("Muraho neza.", voice="female", emotion="calm")
    api.save("Murakoze.", "out.wav", voice="male", sample_rate=8000)
    for chunk in api.stream("Muraho. Amakuru?", format="pcm16", sample_rate=8000):
        play(chunk)                              # bytes, one phrase at a time
    api.enroll("agent_claire", ["c1.wav", "c2.wav"], gender="female")
    print(api.voices(), api.capabilities(), api.health())
"""
from __future__ import annotations

import base64
import io
import json
import urllib.request
from typing import Dict, Iterator, List, Optional, Tuple

import numpy as np


class TTSClient:
    def __init__(self, base_url: str = "http://127.0.0.1:8081", timeout: float = 120.0):
        self.base = base_url.rstrip("/")
        self.timeout = timeout

    # -- plumbing ----------------------------------------------------------- #
    def _request(self, method: str, path: str, body: Optional[Dict] = None,
                 raw: Optional[bytes] = None, ctype: str = "application/json"):
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        req = urllib.request.Request(self.base + path, data=data, method=method)
        if data is not None:
            req.add_header("Content-Type", ctype)
        return urllib.request.urlopen(req, timeout=self.timeout)

    def _json(self, method: str, path: str, body: Optional[Dict] = None) -> Dict:
        with self._request(method, path, body) as r:
            return json.loads(r.read().decode())

    # -- info --------------------------------------------------------------- #
    def health(self) -> Dict:
        return self._json("GET", "/health")

    def capabilities(self) -> Dict:
        return self._json("GET", "/capabilities")

    def voices(self) -> Dict:
        return self._json("GET", "/voices")

    def analyze(self, text: str, language: Optional[str] = None) -> Dict:
        return self._json("POST", "/analyze", {"text": text, "language": language})

    # -- synthesis ---------------------------------------------------------- #
    def tts_bytes(self, text: str, format: str = "wav", **kwargs) -> Tuple[bytes, int]:
        """-> (audio bytes in ``format``, sample_rate)."""
        body = {"text": text, "format": format, **kwargs}
        with self._request("POST", "/tts", body) as r:
            return r.read(), int(r.headers.get("X-Sample-Rate", "0") or 0)

    def tts(self, text: str, **kwargs) -> Tuple[np.ndarray, int]:
        """-> (float32 waveform, sample_rate) like ``Synthesizer.tts``."""
        data, sr = self.tts_bytes(text, format="pcm16", **kwargs)
        wav = np.frombuffer(data, dtype="<i2").astype(np.float32) / 32767.0
        return wav, sr

    def save(self, text: str, path: str, **kwargs) -> str:
        data, _ = self.tts_bytes(text, format="wav", **kwargs)
        with open(path, "wb") as fh:
            fh.write(data)
        return path

    def stream(self, text: str, format: str = "pcm16", **kwargs) -> Iterator[bytes]:
        """Yield audio chunks (one per phrase) as the server produces them."""
        body = {"text": text, "format": format, **kwargs}
        with self._request("POST", "/tts/stream", body) as r:
            while True:
                chunk = r.read(32768)
                if not chunk:
                    break
                yield chunk

    # -- voices ------------------------------------------------------------- #
    def enroll(self, name: str, audio_paths: List[str], gender: Optional[str] = None) -> Dict:
        clips = []
        for p in audio_paths:
            with open(p, "rb") as fh:
                clips.append(base64.b64encode(fh.read()).decode())
        return self._json("POST", "/voices/enroll",
                          {"name": name, "audio": clips, "gender": gender})

    def remove_voice(self, name: str) -> Dict:
        return self._json("DELETE", f"/voices/{name}")
