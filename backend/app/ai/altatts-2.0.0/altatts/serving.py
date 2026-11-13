#!/usr/bin/env python3
"""
``altatts serve`` / ``altatts-serve`` -- the model as an HTTP + WebSocket
API. Standard library only (same approach as ``altasr-serve``): nothing to
install beyond ALTATTS, works behind any reverse proxy, one command.

    altatts serve --model runs/kin_v2 --port 8081          # or ALTATTS_MODEL=...

REST
    GET  /health                 liveness, device, generation, voice count
    GET  /capabilities           what this model can do (emotions, languages, cloning...)
    GET  /voices                 voices.json listing (defaults + enrolled + aliases)
    GET  /tts?text=...&voice=..  quick test -> audio/wav
    POST /tts                    JSON TTSRequest -> audio bytes (wav | pcm16 | mulaw | alaw)
                                 or JSON with base64 audio (format "json")
    POST /tts/stream             JSON TTSRequest -> chunked audio, one chunk per
                                 phrase (pcm16 | mulaw | alaw); first bytes arrive
                                 after the first sentence
    POST /analyze                JSON {text, language} -> normalization + plan
    POST /voices/enroll          JSON {name, gender?, audio: [base64 wav/mp3/...]}
                                 or raw audio bytes with ?name=...  -> enrolled voice
    DELETE /voices/<name>        remove an enrolled voice

WebSocket  GET /ws   (RFC 6455, no extensions)
    client -> TEXT {"text": "...", "voice": "female", "format": "pcm16",
                    "sample_rate": 16000, "emotion": "calm", ...}
           -> server BINARY audio chunks (one per phrase, exact pauses as
              silence) then TEXT {"type": "done", "seconds": 2.4}
    incremental (LLM token streams):
    client -> TEXT {"reset": {...same fields...}}      configure a session
    client -> TEXT {"feed": "Muraho ne"} ...          text as it arrives
    client -> TEXT {"flush": true}                     speak the remainder
    server -> BINARY chunks whenever a sentence completes, TEXT {"type":"done"}
    ping/pong and close frames handled.

TTSRequest fields (all optional except text): text, voice, emotion,
intensity, language, sample_rate, format, speed, noise_scale, steps,
cfg_scale, seed, pause_scale, prior, reference (base64 audio for one-off
cloning), speaker_embedding (list of floats).

Concurrency: requests are served by threads; model calls are serialised
with a lock (a GPU runs one synthesis at a time anyway). Run one server
per GPU / CPU socket and put a load balancer in front for more throughput.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import os
import struct
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Dict, Tuple

import numpy as np

_WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
_CONTENT_TYPES = {"wav": "audio/wav", "pcm16": "audio/L16",
                  "mulaw": "audio/basic", "alaw": "audio/PCMA",
                  "json": "application/json; charset=utf-8"}
_TTS_KEYS = ("voice", "emotion", "intensity", "language", "sample_rate", "speed",
             "noise_scale", "steps", "cfg_scale", "seed", "pause_scale", "prior")


# --------------------------------------------------------------------------- #
#  websocket helpers (server side)
# --------------------------------------------------------------------------- #
def ws_accept_key(client_key: str) -> str:
    digest = hashlib.sha1((client_key + _WS_GUID).encode()).digest()
    return base64.b64encode(digest).decode()


def ws_read_frame(rfile) -> Tuple[int, bytes]:
    """-> (opcode, payload) or (8, b'') on close/EOF."""
    head = rfile.read(2)
    if len(head) < 2:
        return 8, b""
    b1, b2 = head
    opcode = b1 & 0x0F
    masked = b2 & 0x80
    length = b2 & 0x7F
    if length == 126:
        length = struct.unpack(">H", rfile.read(2))[0]
    elif length == 127:
        length = struct.unpack(">Q", rfile.read(8))[0]
    mask = rfile.read(4) if masked else b"\x00" * 4
    data = rfile.read(length)
    if masked:
        data = bytes(c ^ mask[i % 4] for i, c in enumerate(data))
    return opcode, data


def ws_send_frame(wfile, payload: bytes, opcode: int = 1) -> None:
    n = len(payload)
    if n < 126:
        head = struct.pack(">BB", 0x80 | opcode, n)
    elif n < 1 << 16:
        head = struct.pack(">BBH", 0x80 | opcode, 126, n)
    else:
        head = struct.pack(">BBQ", 0x80 | opcode, 127, n)
    wfile.write(head + payload)
    wfile.flush()


# --------------------------------------------------------------------------- #
#  encoding helpers
# --------------------------------------------------------------------------- #
def encode_audio(wav: np.ndarray, sr: int, fmt: str) -> bytes:
    from .audio import to_alaw, to_mulaw, to_pcm16, wav_bytes
    if fmt == "wav":
        return wav_bytes(wav, sr)
    if fmt == "pcm16":
        return to_pcm16(wav)
    if fmt == "mulaw":
        return to_mulaw(wav)
    if fmt == "alaw":
        return to_alaw(wav)
    raise ValueError(f"format must be wav | pcm16 | mulaw | alaw | json, got {fmt!r}")


def _decode_audio_b64(items, synth) -> list:
    """base64 strings (any container) -> list of (array, sr) at the model rate."""
    from .audio import load_audio
    import tempfile
    out = []
    for b64 in items if isinstance(items, list) else [items]:
        raw = base64.b64decode(b64)
        with tempfile.NamedTemporaryFile(suffix=".audio", delete=False) as fh:
            fh.write(raw)
            path = fh.name
        try:
            out.append((load_audio(path, synth.native_sr), synth.native_sr))
        finally:
            try:
                os.unlink(path)
            except OSError:
                pass
    return out


class TTSService:
    """Thread-safe facade over a Synthesizer used by the handlers."""

    def __init__(self, model_dir: str, device: str = "auto",
                 default_voice: str = "female", allow_enroll: bool = True):
        from .inference.synthesizer import Synthesizer
        self.tts = Synthesizer.from_pretrained(model_dir, device=device)
        self.model_dir = model_dir
        self.default_voice = default_voice
        self.allow_enroll = allow_enroll
        self.lock = threading.Lock()
        self.started = time.time()
        self.n_requests = 0
        self.seconds_synthesized = 0.0

    def kwargs(self, req: Dict) -> Dict:
        kw = {k: req[k] for k in _TTS_KEYS if req.get(k) is not None}
        kw.setdefault("voice", self.default_voice)
        if req.get("speaker_embedding") is not None:
            kw["speaker_embedding"] = np.asarray(req["speaker_embedding"], dtype=np.float32)
        if req.get("reference"):
            clips = _decode_audio_b64(req["reference"], self.tts)
            with self.lock:
                kw["speaker_embedding"] = self.tts.embed_speaker(clips)
        return kw

    def synthesize(self, req: Dict) -> Tuple[np.ndarray, int]:
        kw = self.kwargs(req)
        with self.lock:
            wav, sr = self.tts.tts(req["text"], **kw)
            self.n_requests += 1
            self.seconds_synthesized += len(wav) / sr
        return wav, sr

    def stream(self, req: Dict):
        from .inference.streaming import StreamingSynthesizer
        kw = self.kwargs(req)
        voice = kw.pop("voice")
        sample_rate = kw.pop("sample_rate", None)
        speed = kw.pop("speed", 1.0)
        noise = kw.pop("noise_scale", 0.667)
        st = StreamingSynthesizer(self.tts, voice=voice, sample_rate=sample_rate,
                                  speed=speed, noise_scale=noise, **kw)
        return st

    def health(self) -> Dict:
        caps = self.tts.capabilities()
        return {"status": "ok", "generation": self.tts.cfg.generation,
                "device": str(self.tts.device), "model": os.path.abspath(self.model_dir),
                "voices": len(self.tts.voices()), "languages": caps["languages"],
                "voice_cloning": caps["voice_cloning"],
                "emotions": bool(caps["emotions"]),
                "uptime_s": round(time.time() - self.started, 1),
                "requests": self.n_requests,
                "seconds_synthesized": round(self.seconds_synthesized, 1)}


# --------------------------------------------------------------------------- #
#  handler
# --------------------------------------------------------------------------- #
class AltattsHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "altatts-serve"
    svc: TTSService = None                  # set by serve()
    quiet = True

    def log_message(self, fmt, *args):
        if not self.quiet:
            super().log_message(fmt, *args)

    # -- helpers ------------------------------------------------------------ #
    def _json(self, code: int, obj) -> None:
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _bytes(self, code: int, body: bytes, ctype: str, sr: int) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Sample-Rate", str(sr))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _body_json(self) -> Dict:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b""
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def _error(self, code: int, exc) -> None:
        self._json(code, {"error": f"{type(exc).__name__}: {exc}"})

    # -- routes ------------------------------------------------------------- #
    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        url = urllib.parse.urlsplit(self.path)
        path = url.path.rstrip("/") or "/"
        if path == "/health":
            self._json(200, self.svc.health())
        elif path == "/capabilities":
            self._json(200, self.svc.tts.capabilities())
        elif path == "/voices":
            self._json(200, self.svc.tts.voices())
        elif path == "/ws":
            self._websocket()
        elif path == "/tts":
            q = {k: v[0] for k, v in urllib.parse.parse_qs(url.query).items()}
            if "text" not in q:
                self._json(400, {"error": "missing ?text="})
                return
            for k in ("sample_rate", "steps", "seed"):
                if k in q:
                    q[k] = int(q[k])
            for k in ("speed", "noise_scale", "intensity", "cfg_scale", "pause_scale"):
                if k in q:
                    q[k] = float(q[k])
            try:
                wav, sr = self.svc.synthesize(q)
                fmt = q.get("format", "wav")
                self._bytes(200, encode_audio(wav, sr, fmt), _CONTENT_TYPES[fmt], sr)
            except Exception as exc:                        # noqa: BLE001
                self._error(422, exc)
        elif path in ("", "/"):
            self._json(200, {"service": "altatts", "docs": __doc__.strip().splitlines()[0],
                             "endpoints": ["/health", "/capabilities", "/voices",
                                           "/tts", "/tts/stream", "/analyze",
                                           "/voices/enroll", "/ws"]})
        else:
            self._json(404, {"error": f"unknown path {path}"})

    def do_POST(self):
        path = urllib.parse.urlsplit(self.path).path.rstrip("/")
        try:
            if path == "/tts":
                req = self._body_json()
                if not req.get("text"):
                    self._json(400, {"error": "JSON body needs 'text'"})
                    return
                fmt = req.get("format", "wav")
                wav, sr = self.svc.synthesize(req)
                if fmt == "json":
                    self._json(200, {"sample_rate": sr, "seconds": round(len(wav) / sr, 3),
                                     "format": "wav",
                                     "audio_base64": base64.b64encode(
                                         encode_audio(wav, sr, "wav")).decode()})
                else:
                    self._bytes(200, encode_audio(wav, sr, fmt), _CONTENT_TYPES[fmt], sr)
            elif path == "/tts/stream":
                req = self._body_json()
                if not req.get("text"):
                    self._json(400, {"error": "JSON body needs 'text'"})
                    return
                fmt = req.get("format", "pcm16")
                if fmt not in ("pcm16", "mulaw", "alaw"):
                    self._json(400, {"error": "stream format must be pcm16 | mulaw | alaw"})
                    return
                st = self.svc.stream(req)
                self.send_response(200)
                self.send_header("Content-Type", _CONTENT_TYPES[fmt])
                self.send_header("Transfer-Encoding", "chunked")
                self.send_header("X-Sample-Rate", str(st.sample_rate))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                with self.svc.lock:
                    for chunk in st.stream(req["text"]):
                        payload = encode_audio(chunk, st.sample_rate, fmt)
                        if payload:
                            self.wfile.write(f"{len(payload):x}\r\n".encode() + payload + b"\r\n")
                            self.wfile.flush()
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()
            elif path == "/analyze":
                req = self._body_json()
                with self.svc.lock:
                    out = self.svc.tts.analyze(req.get("text", ""), req.get("language"))
                self._json(200, out)
            elif path == "/voices/enroll":
                if not self.svc.allow_enroll:
                    self._json(403, {"error": "enrollment disabled (--no-enroll)"})
                    return
                ctype = self.headers.get("Content-Type", "")
                if ctype.startswith("application/json"):
                    req = self._body_json()
                    name = req.get("name")
                    clips = _decode_audio_b64(req.get("audio", []), self.svc.tts)
                    gender = req.get("gender")
                else:                                       # raw audio bytes
                    q = {k: v[0] for k, v in urllib.parse.parse_qs(
                        urllib.parse.urlsplit(self.path).query).items()}
                    name, gender = q.get("name"), q.get("gender")
                    length = int(self.headers.get("Content-Length", 0))
                    clips = _decode_audio_b64([base64.b64encode(self.rfile.read(length)).decode()],
                                              self.svc.tts)
                if not name or not clips:
                    self._json(400, {"error": "need a voice name and at least one clip"})
                    return
                with self.svc.lock:
                    info = self.svc.tts.enroll_speaker(name, clips, gender=gender, save=True)
                self._json(200, {"name": name, **info})
            else:
                self._json(404, {"error": f"unknown path {path}"})
        except Exception as exc:                            # noqa: BLE001
            self._error(422, exc)

    def do_DELETE(self):
        path = urllib.parse.urlsplit(self.path).path.rstrip("/")
        if path.startswith("/voices/"):
            if not self.svc.allow_enroll:
                self._json(403, {"error": "voice management disabled (--no-enroll)"})
                return
            name = urllib.parse.unquote(path[len("/voices/"):])
            with self.svc.lock:
                ok = self.svc.tts.remove_speaker(name, save=True)
            self._json(200 if ok else 404, {"removed": ok, "name": name})
        else:
            self._json(404, {"error": f"unknown path {path}"})

    # -- websocket ---------------------------------------------------------- #
    def _websocket(self) -> None:
        key = self.headers.get("Sec-WebSocket-Key")
        if self.headers.get("Upgrade", "").lower() != "websocket" or not key:
            self._json(400, {"error": "/ws is a WebSocket endpoint"})
            return
        self.send_response(101, "Switching Protocols")
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", ws_accept_key(key))
        self.end_headers()
        self.close_connection = True

        session = None
        fmt = "pcm16"

        def send_chunks(chunks) -> float:
            total = 0.0
            for chunk in chunks:
                total += len(chunk) / session.sample_rate
                payload = encode_audio(chunk, session.sample_rate, fmt)
                if payload:
                    ws_send_frame(self.wfile, payload, opcode=2)
            return total

        def done(seconds: float) -> None:
            ws_send_frame(self.wfile, json.dumps(
                {"type": "done", "seconds": round(seconds, 3),
                 "sample_rate": session.sample_rate, "format": fmt}).encode())

        while True:
            opcode, data = ws_read_frame(self.rfile)
            if opcode == 8:
                break
            if opcode == 9:
                ws_send_frame(self.wfile, data, opcode=10)
                continue
            if opcode != 1:
                continue
            try:
                msg = json.loads(data.decode() or "{}")
            except ValueError:
                ws_send_frame(self.wfile, json.dumps({"type": "error", "error": "bad json"}).encode())
                continue
            try:
                if "reset" in msg or "text" in msg:
                    cfg = msg.get("reset") if "reset" in msg else msg
                    cfg = dict(cfg or {})
                    fmt = cfg.pop("format", fmt)
                    if fmt not in ("pcm16", "mulaw", "alaw"):
                        raise ValueError("format must be pcm16 | mulaw | alaw")
                    text = cfg.pop("text", None)
                    session = self.svc.stream(dict(cfg, text=""))
                    if text:
                        with self.svc.lock:
                            secs = send_chunks(session.stream(text))
                        done(secs)
                    else:
                        ws_send_frame(self.wfile, json.dumps(
                            {"type": "ready", "sample_rate": session.sample_rate,
                             "format": fmt}).encode())
                elif "feed" in msg:
                    if session is None:
                        session = self.svc.stream({"text": ""})
                    with self.svc.lock:
                        send_chunks(session.feed(str(msg["feed"])))
                elif msg.get("flush"):
                    if session is not None:
                        with self.svc.lock:
                            secs = send_chunks(session.flush())
                        done(secs)
                elif msg.get("close"):
                    ws_send_frame(self.wfile, b"", opcode=8)
                    break
            except Exception as exc:                        # noqa: BLE001
                ws_send_frame(self.wfile, json.dumps(
                    {"type": "error", "error": f"{type(exc).__name__}: {exc}"}).encode())


# --------------------------------------------------------------------------- #
def serve(model_dir: str, host: str = "0.0.0.0", port: int = 8081,
          device: str = "auto", default_voice: str = "female",
          allow_enroll: bool = True, quiet: bool = True) -> ThreadingHTTPServer:
    """Build the server (caller runs serve_forever; tests use the handle)."""
    AltattsHandler.svc = TTSService(model_dir, device=device,
                                    default_voice=default_voice,
                                    allow_enroll=allow_enroll)
    AltattsHandler.quiet = quiet
    httpd = ThreadingHTTPServer((host, port), AltattsHandler)
    httpd.daemon_threads = True
    return httpd


def main(argv=None) -> int:
    from .utils import quiet_warnings
    quiet_warnings()
    p = argparse.ArgumentParser(
        prog="altatts serve",
        description="Serve an ALTATTS model over HTTP (REST, chunked streaming) "
                    "and WebSocket (live streaming). Standard library only.")
    p.add_argument("--model", default=os.environ.get("ALTATTS_MODEL"),
                   help="Model folder (or set ALTATTS_MODEL)")
    p.add_argument("--host", default=os.environ.get("ALTATTS_HOST", "0.0.0.0"))
    p.add_argument("--port", type=int, default=int(os.environ.get("ALTATTS_PORT", "8081")))
    p.add_argument("--device", default=os.environ.get("ALTATTS_DEVICE", "auto"))
    p.add_argument("--default-voice", default=os.environ.get("ALTATTS_DEFAULT_VOICE", "female"))
    p.add_argument("--no-enroll", action="store_true",
                   help="Disable /voices/enroll and DELETE /voices (read-only voice bank)")
    p.add_argument("--verbose", action="store_true", help="Log every request line")
    args = p.parse_args(argv)
    if not args.model:
        p.error("no model: pass --model or set ALTATTS_MODEL")
    httpd = serve(args.model, args.host, args.port, args.device, args.default_voice,
                  allow_enroll=not args.no_enroll, quiet=not args.verbose)
    h = AltattsHandler.svc.health()
    print(f"[serve] {h['generation']} on {h['device']} | {h['voices']} voices | "
          f"languages {h['languages']} | cloning={h['voice_cloning']} "
          f"emotions={h['emotions']}")
    print(f"[serve] http://{args.host}:{args.port}/tts  (POST JSON or GET ?text=)  "
          f"| stream: /tts/stream, ws://{args.host}:{args.port}/ws  | Ctrl-C to stop")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
