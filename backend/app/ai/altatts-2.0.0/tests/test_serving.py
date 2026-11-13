"""The HTTP/WebSocket API on an (untrained) tiny v2 model folder."""
import base64
import json
import os
import socket
import struct
import threading
import urllib.request

import numpy as np
import pytest

torch = pytest.importorskip("torch")

from altatts.config import preset                                  # noqa: E402
from altatts.model import build_model                              # noqa: E402
from altatts.text import build_tokenizer                           # noqa: E402
from altatts.training.data import SpeakerRegistry                  # noqa: E402
from altatts.audio import save_wav                                 # noqa: E402


@pytest.fixture(scope="module")
def model_dir(tmp_path_factory):
    d = tmp_path_factory.mktemp("model")
    cfg = preset("small")
    cfg.model.hidden_channels = 32
    cfg.model.filter_channels = 64
    cfg.model.n_layers = 1
    cfg.model.n_heads = 2
    cfg.model.posterior_layers = 2
    cfg.model.flow_layers = 1
    cfg.model.upsample_initial_channel = 64
    cfg.prior.hidden = 32
    cfg.prior.n_layers = 1
    cfg.prior.n_heads = 2
    cfg.prior.steps = 1
    cfg.text.languages = ["rw", "en"]
    cfg.validate()
    tok = build_tokenizer(["muraho neza amakuru yawe hello"], languages=cfg.text.languages)
    cfg.save(str(d / "config.json"))
    tok.save(str(d / "tokenizer.json"))
    SpeakerRegistry({"s0": {"id": 0, "gender": "female", "n_clips": 1},
                     "s1": {"id": 1, "gender": "male", "n_clips": 1}}).save(str(d / "speakers.json"))
    m = build_model(cfg, len(tok))
    torch.save(m.inference_state_dict(), str(d / "model.pt"))
    sr = 22050
    t = np.arange(int(2.0 * sr)) / sr
    save_wav(str(d / "ref.wav"), (0.3 * np.sin(2 * np.pi * 200 * t)).astype(np.float32), sr)
    return str(d)


@pytest.fixture(scope="module")
def server(model_dir):
    from altatts.serving import serve
    httpd = serve(model_dir, host="127.0.0.1", port=0, device="cpu", default_voice="female")
    th = threading.Thread(target=httpd.serve_forever, daemon=True)
    th.start()
    yield f"http://127.0.0.1:{httpd.server_address[1]}", httpd.server_address[1]
    httpd.shutdown()


def _get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.status, r.headers, r.read()


def _post(url, body, ctype="application/json"):
    data = json.dumps(body).encode() if ctype.startswith("application/json") else body
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", ctype)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.status, r.headers, r.read()


def test_health_capabilities_voices(server):
    base, _ = server
    code, _, body = _get(base + "/health")
    h = json.loads(body)
    assert code == 200 and h["status"] == "ok" and h["generation"] == "ALTATTS 2"
    assert json.loads(_get(base + "/capabilities")[2])["voice_cloning"] is True
    voices = json.loads(_get(base + "/voices")[2])
    assert "s0" in voices                      # no voices.json -> training speakers listed


def test_tts_get_and_post_formats(server):
    base, _ = server
    code, headers, body = _get(base + "/tts?text=muraho%20neza&voice=s0")
    assert code == 200 and body[:4] == b"RIFF" and headers["X-Sample-Rate"] == "22050"
    code, headers, body = _post(base + "/tts", {"text": "muraho neza.", "voice": "s1",
                                                "sample_rate": 8000, "format": "mulaw", "seed": 3})
    assert code == 200 and headers["Content-Type"] == "audio/basic" and len(body) > 500
    code, _, body = _post(base + "/tts", {"text": "muraho", "voice": "s0", "format": "json"})
    out = json.loads(body)
    assert base64.b64decode(out["audio_base64"])[:4] == b"RIFF" and out["sample_rate"] == 22050
    code, _, body = _post(base + "/analyze", {"text": "Muraho [pause:0.5] neza. [happy] hello"})
    assert any(isinstance(p, str) and p.startswith("silence") for p in json.loads(body)["plan"])


def test_tts_stream_chunked(server):
    base, _ = server
    code, headers, body = _post(base + "/tts/stream",
                                {"text": "muraho neza. amakuru yawe? [pause:0.2] yego.",
                                 "voice": "s0", "sample_rate": 16000, "format": "pcm16"})
    assert code == 200 and headers["X-Sample-Rate"] == "16000"
    assert len(body) > 16000 * 2 * 0.5         # at least half a second of PCM16


def test_enroll_and_clone_via_api(server, model_dir):
    base, _ = server
    with open(os.path.join(model_dir, "ref.wav"), "rb") as fh:
        clip = base64.b64encode(fh.read()).decode()
    code, _, body = _post(base + "/voices/enroll", {"name": "agent_x", "audio": [clip]})
    assert code == 200 and json.loads(body)["name"] == "agent_x"
    assert "agent_x" in json.loads(_get(base + "/voices")[2])
    code, _, body = _post(base + "/tts", {"text": "muraho", "voice": "agent_x", "format": "pcm16"})
    assert code == 200 and len(body) > 1000
    code, _, body = _post(base + "/tts", {"text": "muraho", "reference": clip, "format": "pcm16"})
    assert code == 200
    req = urllib.request.Request(base + "/voices/agent_x", method="DELETE")
    with urllib.request.urlopen(req) as r:
        assert json.loads(r.read())["removed"] is True


def test_errors(server):
    base, _ = server
    try:
        _post(base + "/tts", {"text": "x", "voice": "nobody"})
        assert False, "should fail"
    except urllib.error.HTTPError as e:
        assert e.code == 422 and "unknown voice" in e.read().decode()


def _ws_frame(payload: bytes, opcode=1) -> bytes:
    mask = b"\x12\x34\x56\x78"
    n = len(payload)
    if n < 126:
        head = struct.pack(">BB", 0x80 | opcode, 0x80 | n)
    else:
        head = struct.pack(">BBH", 0x80 | opcode, 0x80 | 126, n)
    return head + mask + bytes(c ^ mask[i % 4] for i, c in enumerate(payload))


def _ws_read(sock):
    head = sock.recv(2)
    b1, b2 = head
    length = b2 & 0x7F
    if length == 126:
        length = struct.unpack(">H", sock.recv(2))[0]
    elif length == 127:
        length = struct.unpack(">Q", sock.recv(8))[0]
    data = b""
    while len(data) < length:
        data += sock.recv(length - len(data))
    return b1 & 0x0F, data


def test_websocket_stream_and_feed(server):
    _, port = server
    s = socket.create_connection(("127.0.0.1", port), timeout=120)
    s.sendall(("GET /ws HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
               "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
    resp = b""
    while b"\r\n\r\n" not in resp:
        resp += s.recv(1024)
    assert resp.startswith(b"HTTP/1.1 101")
    s.sendall(_ws_frame(json.dumps({"text": "muraho neza. amakuru yawe?", "voice": "s0",
                                    "format": "pcm16", "sample_rate": 8000}).encode()))
    chunks, done = 0, None
    while done is None:
        op, data = _ws_read(s)
        if op == 2:
            chunks += 1
        elif op == 1:
            done = json.loads(data)
    assert chunks == 2 and done["type"] == "done" and done["sample_rate"] == 8000
    # incremental session
    s.sendall(_ws_frame(json.dumps({"reset": {"voice": "s1", "format": "mulaw", "sample_rate": 8000}}).encode()))
    op, data = _ws_read(s)
    assert json.loads(data)["type"] == "ready"
    s.sendall(_ws_frame(json.dumps({"feed": "muraho ne"}).encode()))
    s.sendall(_ws_frame(json.dumps({"feed": "za. ama"}).encode()))
    s.sendall(_ws_frame(json.dumps({"flush": True}).encode()))
    binary = 0
    while True:
        op, data = _ws_read(s)
        if op == 2:
            binary += 1
        elif op == 1 and json.loads(data).get("type") == "done":
            break
    assert binary >= 2
    s.sendall(_ws_frame(json.dumps({"close": True}).encode()))
    s.close()
