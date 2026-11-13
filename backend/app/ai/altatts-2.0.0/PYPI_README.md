# ALTATTS

**Natural, expressive, multilingual text-to-speech with zero-shot voice cloning. Built for Kinyarwanda; speaks English, French and Swahili too; ready for call centers; one command to serve as an API.**

ALTATTS is the speaking half of the ALTA stack: [ALTASR](https://pypi.org/project/altasr/) listens, ALTATTS talks.

| capability | how |
|---|---|
| Natural prosody | **MeanFlow latent prior** (Geng, Deng, Bai, Kolter & He, 2025): the whole utterance is generated jointly in 1–4 steps |
| Word-exact speech | deterministic durations + monotonic alignment: no skipped or repeated words |
| Emotion and intensity | `emotion="happy", intensity=0.7` or inline `[calm]`, `[excited:0.8]` |
| Human behaviour | exact `[pause:0.5]`, natural `[pause]`, `[laugh]`, `[breath]`, `[sigh]`, hesitations |
| Voice cloning | enroll a speaker from a few seconds of audio, use it immediately, no training |
| Privacy | 12 anonymized **production voices** (French, English, Bantu groups: 2 F + 2 M each) that match no training speaker |
| Code-switching | Kinyarwanda, English, French, Swahili in one model, word-level language detection, per-language number reading |
| Telephony | 8 kHz G.711 μ-law / A-law, 20 ms frames, Twilio messages, phrase streaming |
| Serving | `altatts serve` (REST + WebSocket, standard library only) and `altatts package` (Docker folder, `docker compose up`) |
| Anywhere | CPU, one GPU, all GPUs, several machines; `altatts doctor --fix` repairs PyTorch/CUDA/audio installs |

Every ALTATTS 0.1 interface still works and 0.1 checkpoints load unchanged.

---

## 1. Install and check

```bash
pip install "altatts[av]"        # av = mp3/webm/opus decoding; "altatts[all]" for everything
altatts doctor                   # Python / torch / CUDA / audio deps -> PASS/WARN/FAIL + fixes
altatts doctor --fix             # repair what is safe (matched torch for your driver, missing deps)
```

A plain `pip install torch` pulls the newest CUDA build (cu130 today), which
does not run on older drivers (a 570.x driver supports CUDA ≤ 12.8).
`altatts doctor --fix` cross-checks the driver's ceiling, the GPU's
compute-capability floor and the wheels actually published for your Python
and CPU architecture, prints the choice, installs the newest torch the
machine can run (exact pins, right index), re-verifies CUDA and rolls back
on failure. `--fix --dry-run` shows the cross-check without changing
anything; `--index-url cu126` forces an index. The manual equivalent:

```bash
pip install --force-reinstall "torch==2.14.1+cu126" torchaudio --index-url https://download.pytorch.org/whl/cu126
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

## 2. Which model do I have? ("generation")

A model folder's `config.json` carries `"model": {"version": N}`. This is only a **generation number**, never something you set by hand:

| generation | what it means | cloning / emotions / MeanFlow |
|---|---|---|
| **ALTATTS 2** (`version: 2`) | trained with altatts ≥ 2.0 | yes |
| **ALTATTS 0.1 (legacy)** (no `version` key) | trained with altatts 0.1, plain VITS | no, but every 0.1 call still works |

```python
tts.capabilities()["generation"]     # 'ALTATTS 2' or 'ALTATTS 0.1 (legacy VITS)'
```

Upgrade a 0.1 model by fine-tuning: `altatts-train --init-from runs/old_model --preset base ...` (all VITS weights are reused).

## 3. Synthesize

```python
from altatts import Synthesizer

tts = Synthesizer.from_pretrained("runs/kin_v2")
wav, sr = tts.tts("Muraho! Amakuru yawe?", voice="female")        # the 0.1 call
tts.tts_to_file("Murakaza neza.", "hello.wav", voice="male", sample_rate=8000)
print(tts.voices())            # production voices, enrolled voices, aliases
print(tts.capabilities())      # generation, emotions, languages, cloning, pause token ...
```

### Every control, and the value that works best

| parameter | values | best practice |
|---|---|---|
| `voice` | `female`, `male`, `bantu_female_1`, `french_male_2`, `english_female_1`, `fr_female`, `kin_male`, an enrolled name, a training speaker, **or a path to a reference clip** | pick the group that matches the sentence language; `female`/`male` are the primary-language voices |
| `emotion` | `neutral happy sad angry fearful surprised disgusted calm excited` | `calm` for service lines, `happy` for greetings; only emotions seen in training have an effect (`capabilities()["emotions_seen_in_training"]`) |
| `intensity` | 0–1 | 0.3 subtle, **0.6 natural**, 1.0 strong |
| `speed` | 0.5–2 | **1.0**; 0.95 for instructions/health lines, 1.05–1.1 for busy IVR menus |
| `noise_scale` | 0–1 | **0.667** (standard); 0.5 for maximally consistent prompts, 0.8 for lively narration |
| `steps` | 1–8 | **4** default; 1 = fastest (CPU/live), 8 = maximum naturalness for pre-rendered media |
| `cfg_scale` | 1–2 | **1.0**; 1.3–1.8 amplifies a cloned identity or an emotion |
| `seed` | int | set it for reproducible prompts (same text → same audio) |
| `sample_rate` | 8000 … 48000 | 8000 telephony, 16000 ASR/voice bots, 22050 native, 48000 media |
| `language` | `rw en fr sw` (`kin eng fra swa` accepted) | set it for a monolingual non-primary sentence; mixed text is detected word by word; force spans with `<en>…</en>` |
| `pause_scale` | float | multiplies every `[pause:x]` |
| `reference_audio` (+ `reference_sr` for arrays) | path, array, `(array, sr)` or a list of clips | one-off cloning from a clip; 10–30 s of clean speech works best |
| `speaker_embedding` | vector from `tts.embed_speaker(...)` | fastest repeated cloning (embed once, reuse) |
| `prior` | `meanflow` / `flow` | `flow` = the 0.1 sampler, only for A/B comparisons |

### Scenarios with their best configurations

```python
# A. Call-center / IVR prompts (pre-rendered, 8 kHz, identical every time)
wav, sr = tts.tts("Murakaza neza kuri banki yacu. [pause:0.4] Kanda rimwe ku konti yawe.",
                  voice="bantu_female_1", emotion="calm", intensity=0.5,
                  speed=0.97, noise_scale=0.5, steps=8, seed=1, sample_rate=8000)
ulaw = tts.mulaw_bytes("Murakoze guhamagara.", voice="female", emotion="calm", seed=1)

# B. Live voice agent (lowest latency; stream phrase by phrase, see §5)
wav, sr = tts.tts("Yego, ndabikora nonaha.", voice="female", steps=2, sample_rate=16000)

# C. Media / audiobook narration (maximum naturalness)
wav, sr = tts.tts("Umwana yarahagurutse, [breath] areba hirya no hino, [pause:0.8] "
                  "maze aratangira kwiruka.", voice="bantu_male_2", emotion="excited",
                  intensity=0.6, noise_scale=0.8, steps=8, sample_rate=48000)

# D. Emotion sweep (faint -> ecstatic) on the same sentence
for inten in (0.2, 0.5, 0.8, 1.0):
    wav, sr = tts.tts("Twishimiye cyane kubabona!", voice="female",
                      emotion="happy", intensity=inten, cfg_scale=1.3, seed=3)

# E. Code-switching and numbers (read in each sentence's language)
wav, sr = tts.tts("Konti yawe ifite FRW 2,500. <en>Your balance is 2,500 francs.</en> "
                  "Votre solde est de 2500 FRW. Salio lako ni FRW 2500.",
                  voice="bantu_female_2", steps=4)
wav, sr = tts.tts("Bonjour, votre dossier est prêt.", voice="french_female_1", language="fr")
wav, sr = tts.tts("Habari, akaunti yako iko tayari.", voice="bantu_male_1", language="sw")

# F. Human behaviour tags
wav, sr = tts.tts("Hmm [hesitation] ndabona. [pause:0.6] [laugh] Nibyo rwose! [breath] Reka nkwereke.",
                  voice="male", emotion="happy", intensity=0.5)

# G. Cloning: one-off, by path, enrolled
wav, sr = tts.tts("Muraho neza.", reference_audio=["agent_1.wav", "agent_2.wav"], cfg_scale=1.5)
wav, sr = tts.tts("Muraho neza.", voice="agent_1.wav")
tts.enroll_speaker("agent_claire", ["claire_1.wav", "claire_2.wav"], gender="female")
wav, sr = tts.tts("Murakoze guhamagara.", voice="agent_claire", emotion="calm", intensity=0.4)

# H. Fastest CPU synthesis
wav, sr = tts.tts("Muraho neza.", voice="female", steps=1)

# I. Explain how a text will be read (QA before shipping prompts)
print(tts.analyze("Konti 0788123456 ifite FRW 2,500. <en>Thank you.</en>")["plan"])
```

Command line equivalents: `altatts synthesize --model runs/kin_v2 --text "..." --voice female --emotion calm --intensity 0.5 --steps 8 --seed 1 --sample-rate 8000 --out p.wav`, `--list-voices`, `--capabilities`, `--explain`, `--reference clip.wav`.

## 4. Voices: production, enrolled, cloned

A trained ALTATTS 2 model ships **anonymized production voices**, grouped by language family, each a verified mixture of training speakers that matches none of them:

| group | languages | voices |
|---|---|---|
| `bantu` | Kinyarwanda, Swahili, code-switching | `bantu_female_1`, `bantu_female_2`, `bantu_male_1`, `bantu_male_2` |
| `french` | French | `french_female_1/2`, `french_male_1/2` |
| `english` | English | `english_female_1/2`, `english_male_1/2` |

Aliases: `female` / `male` (primary language group), `fr_female`, `fra_male`, `rw_female`, `kin_male`, `sw_female`, `en_male`, `bantu_female`, … A single-language model gets one group with three voices per gender (`female_young`, `female_adult`, `female_senior`, …). `privacy_report.json` records the similarity every voice achieved.

```bash
altatts voices list  --model runs/kin_v2
altatts-enroll --model runs/kin_v2 --name agent_claire --audio c1.wav c2.wav --gender female
altatts-enroll --model runs/kin_v2 --name agent_claire --audio c1.wav --text "Muraho neza." --adapt-steps 300
```

Enrollment tips: 10–30 s of clean speech, several clips, the same microphone as production; `cfg_scale` 1.3–1.8 strengthens the identity; `--adapt-steps` (few-shot) when the model saw few training speakers.

## 5. Live streaming

```python
from altatts import Synthesizer, StreamingSynthesizer

tts = Synthesizer.from_pretrained("runs/kin_v2")
stream = StreamingSynthesizer(tts, voice="female", sample_rate=8000,
                              emotion="calm", intensity=0.5, steps=2)    # live settings

# known text: audio starts after the FIRST sentence
for chunk in stream.stream("Muraho. [pause:0.3] Turabafasha gute uyu munsi?"):
    send_to_caller(chunk)                     # float32; exact pauses arrive as silent chunks

# LLM token stream: speak each sentence as soon as it completes
for token in llm_tokens:
    for chunk in stream.feed(token):
        send_to_caller(chunk)
for chunk in stream.flush():
    send_to_caller(chunk)
print(stream.first_chunk_latency_s)
stream.reset(voice="male", emotion="happy")
```

Best live settings: `steps=2` (GPU) or `steps=1` (CPU), `noise_scale=0.667`, `sample_rate=8000` for telephony / `16000` for voice bots, `min_chars=6` (default) so very short fragments wait for the next sentence. Pass `reference_audio=` once to the constructor to stream in a cloned voice. Telephony framing: `altatts.integrations.callcenter.streaming_telephony_frames`.

## 6. Serve it as an API and deploy with one command

```bash
altatts serve --model runs/kin_v2 --port 8081            # REST + WebSocket, no extra packages
```

| endpoint | purpose |
|---|---|
| `GET /health`, `/capabilities`, `/voices` | status, what the model can do, voice list |
| `GET /tts?text=…&voice=…` | quick test → WAV |
| `POST /tts` | JSON request → `wav` / `pcm16` / `mulaw` / `alaw` bytes, or `format: "json"` (base64) |
| `POST /tts/stream` | chunked audio, one chunk per phrase (first bytes after the first sentence) |
| `WS /ws` | live streaming: send `{"text": …}` or `{"reset": …}` + `{"feed": "token"}` … `{"flush": true}`; receive binary chunks |
| `POST /voices/enroll`, `DELETE /voices/<name>` | add / remove voices at runtime (`--no-enroll` to lock) |
| `POST /analyze` | normalization + synthesis plan for QA |

Request fields = the Python parameters (`text, voice, emotion, intensity, language, sample_rate, format, speed, noise_scale, steps, cfg_scale, seed, pause_scale, reference`).

```bash
curl -s localhost:8081/tts -H 'Content-Type: application/json' -d '{
  "text": "Murakaza neza. [pause:0.4] Twishimiye kubafasha!",
  "voice": "bantu_female_1", "emotion": "calm", "intensity": 0.5,
  "sample_rate": 8000, "format": "mulaw", "seed": 1 }' -o prompt.ulaw
curl -sN localhost:8081/tts/stream -H 'Content-Type: application/json' \
  -d '{"text": "Muraho. Amakuru yawe?", "voice": "female", "sample_rate": 16000}' > live.pcm
```

```python
from altatts.client import TTSClient                      # standard library client
api = TTSClient("http://tts.internal:8081")
wav, sr = api.tts("Muraho neza.", voice="female", emotion="calm")
for chunk in api.stream("Muraho. Amakuru?", sample_rate=8000, format="mulaw"):
    rtp_send(chunk)
api.enroll("agent_claire", ["c1.wav", "c2.wav"], gender="female")
```

**Deploy on a server** (model + Dockerfile + compose + README generated for you):

```bash
altatts package --model runs/kin_v2 --out deploy/altatts-api            # add --gpu for a CUDA image
scp -r deploy/altatts-api server:/srv/ && ssh server 'cd /srv/altatts-api && docker compose up -d'
curl -s server:8081/health
```

Enrolled voices persist (`voices.json` is mounted from the host). Put the service behind your reverse proxy / auth; run one instance per GPU or CPU socket and load-balance for throughput.

## 7. Call centers

```python
from altatts.integrations.callcenter import (telephony_frames, streaming_telephony_frames,
                                              twilio_media_messages, VoiceAgent,
                                              prerender_prompts, enroll_agent)
for frame in telephony_frames(tts, "Murakoze guhamagara.", voice="female", emotion="calm"):
    rtp_send(frame)                                        # 160-byte G.711 frames
agent = VoiceAgent(asr, tts, respond_fn=my_bot, voice="agent_eric", emotion="calm", steps=2)
prerender_prompts(tts, {"welcome": "Murakaza neza.", "menu": "Kanda rimwe ..."},
                  out_dir="ivr/", voice="bantu_female_1", emotion="calm", seed=1)
```

## 8. Train on your data

Any corpus shape works: plain ASR data, or data with speaker / gender / age / language / emotion / intensity / pause annotations, monolingual or code-switched, in any mix (details and every field in `docs/DATASET.md`).

```bash
altatts-prepare-data --metadata fr.jsonl en.jsonl rw.jsonl sw.jsonl cs.jsonl --audio-root /data \
    --out /data/tts/train.jsonl --languages rw en fr sw --auto-pauses punct --convert-audio flac
altatts-train --recipe multilingual_callcenter --gpus all \
    --train-metadata /data/tts/train_converted.jsonl --val-metadata /data/tts/val_converted.jsonl \
    --audio-root /data/tts/audio_flac --out runs/kin_v2
altatts-evaluate --model runs/kin_v2 --metadata test.jsonl --audio-root /data \
    --asr-model /path/altasr --target-wer 0.01 --robustness --clone
```

Training ends with the 12 production voices built and verified; `altatts recipes` lists the shipped configs; `--init-from` fine-tunes or upgrades an existing model; `--nodes` trains across machines. Every run writes `logs/train.log`, `metrics.jsonl`, `history.jsonl` and a live `status.json` (plus TensorBoard / W&B when installed), prints the validation error per corpus each epoch, and `--early-stop-patience N` stops when `val_mel_l1` stops improving; `altatts logs --run runs/x` summarises a run.

## 9. Troubleshooting

- Anything environment-related: `altatts doctor` → `altatts doctor --fix`.
- `voice cloning needs an ALTATTS 2 model`: a 0.1 folder; upgrade with `--init-from`.
- Emotion has no audible effect: not in the training labels; label a subset and fine-tune; raise `intensity`/`cfg_scale`.
- A production voice is flagged in `privacy_report.json`: rebuild with `altatts voices build --seed N` or add speakers of that gender/family.
- Slow on CPU: `steps=1`, `--preset small`, pre-render fixed prompts, or deploy the API on a GPU box.

Full manual: `docs/USAGE.md`. Dataset guide: `docs/DATASET.md`. Apache-2.0 · YaliLabs / ALTA Project
