"""``altatts package`` -- turn a trained model folder into a deployable API.

    altatts package --model runs/kin_v2 --out deploy/altatts-api [--gpu] [--port 8081]
    cd deploy/altatts-api && docker compose up -d        # the API is live

Writes a self-contained folder:

    deploy/altatts-api/
        model/            config.json tokenizer.json speakers.json voices.json
                          model.pt [lexicon.json] -- inference files only
        Dockerfile        CPU image by default (--gpu: CUDA image)
        docker-compose.yml  port mapping, health check, restart policy,
                          voices.json kept writable for enrollment
        .env              ALTATTS_PORT / ALTATTS_DEFAULT_VOICE / ALTATTS_DEVICE
        README.md         curl + Python examples for this deployment
        client_example.py tiny stdlib client

``--wheel dist/altatts-2.0.0-py3-none-any.whl`` installs a local build
inside the image (before the package is on PyPI). Without Docker:
``pip install altatts && altatts serve --model model --port 8081`` in that
folder does the same.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
from typing import List, Optional

_INFERENCE_FILES = ("config.json", "tokenizer.json", "speakers.json", "voices.json",
                    "model.pt", "lexicon.json", "training_summary.json",
                    "privacy_report.json")


def _dockerfile(gpu: bool, port: int, altatts_version: str, wheel: str = "") -> str:
    if gpu:
        base = "nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04"
        py = ("RUN apt-get update && apt-get install -y --no-install-recommends "
              "python3 python3-pip python3-venv ffmpeg libsndfile1 curl "
              "&& rm -rf /var/lib/apt/lists/* && python3 -m venv /venv\n"
              "ENV PATH=/venv/bin:$PATH\n"
              "RUN pip install --no-cache-dir torch torchaudio "
              "--index-url https://download.pytorch.org/whl/cu126\n")
    else:
        base = "python:3.12-slim"
        py = ("RUN apt-get update && apt-get install -y --no-install-recommends "
              "ffmpeg libsndfile1 curl && rm -rf /var/lib/apt/lists/*\n"
              "RUN pip install --no-cache-dir torch torchaudio "
              "--index-url https://download.pytorch.org/whl/cpu\n")
    install = (f'COPY {wheel} /tmp/{wheel}\nRUN pip install --no-cache-dir "/tmp/{wheel}[av]"\n'
               if wheel else f'RUN pip install --no-cache-dir "altatts[av]>={altatts_version}"\n')
    return f"""# ALTATTS serving image ({'GPU' if gpu else 'CPU'}). Built by `altatts package`.
FROM {base}
{py}{install}
WORKDIR /app
COPY model /app/model
ENV ALTATTS_MODEL=/app/model ALTATTS_PORT={port} ALTATTS_HOST=0.0.0.0 ALTATTS_NO_CLEAR=1
EXPOSE {port}
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s \\
    CMD curl -sf http://localhost:{port}/health || exit 1
CMD ["altatts-serve", "--model", "/app/model"]
"""


def _compose(gpu: bool, port: int) -> str:
    gpu_block = ("""    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
""" if gpu else "")
    return f"""# `docker compose up -d` serves the model; `docker compose logs -f` to watch.
services:
  altatts:
    build: .
    image: altatts-api:latest
    ports:
      - "${{ALTATTS_PORT:-{port}}}:{port}"
    env_file: .env
    volumes:
      # voices.json stays on the host so enrolled voices survive restarts
      - ./model/voices.json:/app/model/voices.json
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:{port}/health"]
      interval: 30s
      timeout: 10s
      start_period: 90s
    restart: unless-stopped
{gpu_block}"""


def _readme(port: int, voices: List[str], caps: dict) -> str:
    v = voices[0] if voices else "female"
    emo = (caps.get("emotions") or ["neutral"])[0]
    return f"""# ALTATTS API deployment

Generation: {caps.get('generation', 'ALTATTS 2')} | languages: {', '.join(caps.get('languages', []))} |
voice cloning: {caps.get('voice_cloning')} | emotions: {', '.join(caps.get('emotions') or []) or 'no'}

## Run

```bash
docker compose up -d            # build + start; http://<host>:{port}
docker compose logs -f          # watch; "[serve] ..." = ready
curl -s localhost:{port}/health
```

Without Docker: `pip install "altatts[av]"` then `altatts serve --model model --port {port}`.

## Use

```bash
# quick test -> WAV
curl -s "localhost:{port}/tts?text=Muraho%20neza&voice={v}" -o hello.wav

# full request -> 8 kHz mu-law for telephony
curl -s localhost:{port}/tts -H 'Content-Type: application/json' -d '{{
  "text": "Murakaza neza. [pause:0.4] Twishimiye kubafasha!",
  "voice": "{v}", "emotion": "{emo}", "intensity": 0.6,
  "sample_rate": 8000, "format": "mulaw", "seed": 7 }}' -o prompt.ulaw

# streaming (first bytes after the first sentence) -> raw 16-bit PCM
curl -sN localhost:{port}/tts/stream -H 'Content-Type: application/json' \\
  -d '{{"text": "Muraho. Amakuru yawe? Turabafasha.", "voice": "{v}", "sample_rate": 16000}}' > out.pcm

# enroll an agent voice from clips (no training), then use it
python - <<'PY'
from altatts.client import TTSClient
api = TTSClient("http://localhost:{port}")
print(api.enroll("agent_claire", ["claire1.wav", "claire2.wav"], gender="female"))
api.save("Murakoze guhamagara.", "claire.wav", voice="agent_claire")
PY
```

WebSocket live streaming: connect to `ws://<host>:{port}/ws`, send
`{{"text": "...", "voice": "{v}", "format": "pcm16", "sample_rate": 16000}}`,
receive binary audio chunks per phrase, then `{{"type": "done"}}`. For LLM
token streams send `{{"reset": {{...}}}}`, then `{{"feed": "token"}}` repeatedly,
then `{{"flush": true}}`.

Voices available: {', '.join(voices[:12])}{' ...' if len(voices) > 12 else ''}
"""


_CLIENT_EXAMPLE = '''"""Minimal client for this deployment (standard library only)."""
import sys
from altatts.client import TTSClient

api = TTSClient(sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:%d")
print(api.health())
api.save("Muraho neza. Murakoze guhamagara.", "hello.wav", voice="%s")
print("wrote hello.wav")
'''


def package(model_dir: str, out_dir: str, gpu: bool = False, port: int = 8081,
            default_voice: str = "female", verbose: bool = True,
            wheel: str = "") -> str:
    from . import __version__
    model_dir = os.path.abspath(model_dir)
    for f in ("config.json", "tokenizer.json", "speakers.json", "model.pt"):
        if not os.path.isfile(os.path.join(model_dir, f)):
            raise FileNotFoundError(f"{f} missing in {model_dir}")
    os.makedirs(os.path.join(out_dir, "model"), exist_ok=True)
    copied = []
    for f in _INFERENCE_FILES:
        src = os.path.join(model_dir, f)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(out_dir, "model", f))
            copied.append(f)
    voices_path = os.path.join(out_dir, "model", "voices.json")
    if not os.path.isfile(voices_path):
        with open(voices_path, "w", encoding="utf-8") as fh:
            json.dump({"version": 2, "aliases": {}, "voices": {}, "meta": {}}, fh)
    caps, voices = {}, []
    try:
        from .inference.synthesizer import Synthesizer
        tts = Synthesizer.from_pretrained(model_dir, device="cpu")
        caps = tts.capabilities()
        caps["generation"] = tts.cfg.generation
        voices = list(tts.voices())
    except Exception as exc:                                 # noqa: BLE001
        if verbose:
            print(f"[package] model not loaded for the README ({exc}); continuing")
    wheel_name = ""
    if wheel:
        if not os.path.isfile(wheel):
            raise FileNotFoundError(f"wheel not found: {wheel}")
        wheel_name = os.path.basename(wheel)
        shutil.copy2(wheel, os.path.join(out_dir, wheel_name))
    with open(os.path.join(out_dir, "Dockerfile"), "w") as fh:
        fh.write(_dockerfile(gpu, port, __version__, wheel_name))
    with open(os.path.join(out_dir, "docker-compose.yml"), "w") as fh:
        fh.write(_compose(gpu, port))
    with open(os.path.join(out_dir, ".env"), "w") as fh:
        fh.write(f"ALTATTS_PORT={port}\nALTATTS_DEFAULT_VOICE={default_voice}\n"
                 f"ALTATTS_DEVICE={'auto' if gpu else 'cpu'}\n")
    with open(os.path.join(out_dir, "README.md"), "w", encoding="utf-8") as fh:
        fh.write(_readme(port, voices, caps))
    with open(os.path.join(out_dir, "client_example.py"), "w") as fh:
        fh.write(_CLIENT_EXAMPLE % (port, voices[0] if voices else "female"))
    if verbose:
        size = sum(os.path.getsize(os.path.join(out_dir, "model", f)) for f in copied) / 2**20
        print(f"[package] {len(copied)} model files ({size:.0f} MB) + Dockerfile "
              f"({'GPU' if gpu else 'CPU'}), docker-compose.yml, .env, README.md -> {out_dir}")
        print(f"[package] deploy:  cd {out_dir} && docker compose up -d   "
              f"# then: curl -s localhost:{port}/health")
    return out_dir


def main(argv: Optional[List[str]] = None) -> int:
    from .utils import quiet_warnings
    quiet_warnings()
    p = argparse.ArgumentParser(prog="altatts package",
                                description="Package a model folder as a deployable "
                                            "Docker API (altatts serve inside)")
    p.add_argument("--model", required=True)
    p.add_argument("--out", required=True, help="Deployment folder to create")
    p.add_argument("--gpu", action="store_true", help="CUDA image instead of CPU")
    p.add_argument("--port", type=int, default=8081)
    p.add_argument("--default-voice", default="female")
    p.add_argument("--wheel", default="",
                   help="Install altatts from this local wheel inside the image "
                        "(python -m build --wheel) instead of from PyPI")
    args = p.parse_args(argv)
    package(args.model, args.out, gpu=args.gpu, port=args.port,
            default_voice=args.default_voice, wheel=args.wheel)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
