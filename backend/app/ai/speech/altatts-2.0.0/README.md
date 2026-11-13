# ALTATTS — developer guide

Natural, expressive, multilingual text-to-speech with zero-shot voice
cloning, built for Kinyarwanda (plus English, French and Swahili
code-switching) and reusable for any language. This README explains how the
codebase is put together and why. User-facing instructions live in
`PYPI_README.md`; the complete manual in `docs/USAGE.md`; the dataset guide
in `docs/DATASET.md`.

## Architecture: VITS backbone + MeanFlow prior + style encoder

ALTATTS 2 keeps the single-stage **VITS** backbone (Kim, Kong & Son, 2021)
that made 0.1 robust and fast, and adds three things on top. Every addition
is a *module*, so a 0.1 checkpoint (`model.version` absent) builds the exact
legacy network and keeps working; a new model adds the modules.

```
 text (+language ids) ──► TextEncoder ──► prior stats (m_p, logs_p) ─┐
                                 │                                    │
                                 ▼  durations (MAS in training,       │ expanded to
                           DurationPredictor at inference)            │ frame rate
                                                                       ▼
 style g = speaker ⊕ emotion·intensity ──► MeanFlow prior (1-4 steps) ──► z ──► HiFi-GAN ──► waveform
            ▲                                       ▲ cond                     ▲ g
   speaker table | ReferenceEncoder(mel)      VITS flow + posterior (training / fallback)
```

### Why these choices

| need | choice | why |
|---|---|---|
| word-exact speech (call-center WER) | **deterministic duration predictor + monotonic alignment** (VITS/Glow-TTS) | cannot skip or repeat words like attention-based autoregressive TTS; alignment is learned from plain ASR data, no aligner |
| natural prosody | **MeanFlow latent prior** — Geng, Deng, Bai, Kolter & He, *Mean Flows for One-step Generative Modeling* (2025) | a joint generative prior over the whole utterance (like the flow-matching priors in Matcha-TTS / CosyVoice / F5-TTS) instead of frame-independent Gaussians, but with **1–4 sampling steps** thanks to the average-velocity objective, so inference stays a single fast pass |
| zero-shot cloning | **jointly trained reference encoder** (ECAPA-style, attentive statistics pooling) regressed onto the speaker table | enrolled voices land in the same embedding space the decoder knows; works from a few seconds of audio; few-shot refinement optimizes only the vector |
| emotions on mixed data | **emotion embedding × intensity** with an *unlabeled* slot | unlabeled corpora never disturb labelled categories; intensity is continuous |
| code-switching | **characters + per-character language ids** | one model, one vocabulary; the same letters sound different per language; adding a language is a config/registry change |
| pauses & human sounds | **learned special tokens** (`[pause]`, `[laugh]`, …) + **exact silences** planned outside the model | learned tokens for naturalness, exact timing for deterministic IVR prompts |
| privacy | **anonymized production voices** — a *voice plan* groups speakers by language family (french / english / bantu), mixes them in embedding space and verifies every voice with the speaker encoder (the VoicePrivacy-challenge approach) | callers never hear a training speaker unless that speaker is explicitly enrolled; 12 voices for a rw+en+fr+sw model |
| serving | **stdlib HTTP + WebSocket server** (`serving.py`), Docker packager (`deploy.py`) | same approach as `altasr-serve`: nothing to install, `docker compose up` |
| end-to-end waveform | **HiFi-GAN decoder trained jointly** | no mel-vocoder mismatch; telephony/media rates by resampling |

### Components (`altatts/model/`)

| file | component | role |
|---|---|---|
| `text_encoder.py` | transformer with windowed relative attention **+ language embedding** | characters → hidden sequence → prior stats *(m_p, logs_p)* |
| `latent.py` | posterior encoder (WaveNet on linear spectrograms), residual-coupling flow, duration predictor | VITS latent side |
| `monotonic_align.py` | MAS, vectorised numpy (optional numba JIT) | self-learned alignment, ~100× faster than the 0.1 scalar loop |
| `style.py` | `ReferenceEncoder`, `compose_style` | speaker vector (table or reference audio) ⊕ emotion·intensity, style dropout for CFG |
| `meanflow.py` | `LatentPrior` (DiT blocks: adaLN-Zero, RoPE attention, depthwise conv), `meanflow_loss`, `sample_latent` | the joint latent prior; JVP via `torch.func.jvp`, finite-difference fallback |
| `waveform.py` | HiFi-GAN generator, multi-period/scale discriminators | latents → waveform (×256), adversarial signal |
| `losses.py` | LSGAN, feature matching, KL | the VITS objective |
| `vits.py` | `SynthesizerTrn` | wiring; `forward` (training, returns the 7-tuple + `extras`) and `infer` (MeanFlow or flow path) |

Training objective:
`L_G = L_adv + 2·L_fm + 45·L_mel + L_dur + L_kl + c_mf·L_meanflow + c_spk·L_spk`.

MeanFlow details (`prior` config): logit-normal (t, r) sampling with
`meanflow_ratio` of samples having r ≠ t (0 → plain conditional flow
matching), target `u_tgt = v − (t − r)·d/dt u` with stop-gradient, adaptive
`1/(err²+c)^p` weighting, conditioning = aligned `(m_p, logs_p)` + style via
adaLN. Inference: `steps` Euler steps of the average velocity (1 is valid);
`noise_scale` maps to the initial-noise temperature (0.667 → 1.0, so the 0.1
parameter keeps its meaning).

### Text front end (`altatts/text.py`, `tags.py`, `languages/`)

Pipeline (identical at training and inference): parse control tags →
normalize each span in its sentence's language (NFC, quotes, numbers /
currency / percent verbalized by `languages/<code>.py`, lexicon
pronunciations, transliteration **only** for languages the model was not
trained on) → per-word language ids → character tokenizer with special
tokens and the VITS blank. `plan_chunks` turns user text into model calls
and exact silences, carrying the emotion state across sentences.

### Data (`altatts/training/data.py`, `prepare.py`)

Same metadata containers and aliases as ALTASR plus optional `age`,
`language`, `emotion`, `intensity`, `pauses`. `load_records` normalizes and
annotates; `TTSDataset` returns token ids, language ids, linear spectrogram,
waveform, speaker id, emotion id, intensity and a **reference spectrogram**
(a random 1–3 s crop of another clip of the same speaker) for the reference
encoder. `prepare.py` writes the canonical file, a coverage report with
recommendations, optional `[pause]` tags from silences at punctuation and
optional ASR transcript verification.

### Training (`trainer.py`, `train.py`, `launch.py`)

GAN trainer with bf16 autocast (fp16 + GradScaler on older GPUs), DDP with
every parameter used each step (no `find_unused_parameters`), bucketed
batches sharded per rank, resume/auto-resume, rolling mid-epoch checkpoints,
teacher-forced validation, sample synthesis, and `finalize()` → the
production voice builder (`anonymize.py`: `plan_voice_groups`,
`assign_speakers`, `build_default_voices`; the first two are pure functions
with unit tests). `launch.py` is ALTASR's three-tier launcher
(`--gpus`, `--nodes`/SLURM, external torchrun). Fine-tuning transfers every
matching tensor, text-embedding rows by symbol (vocabulary growth), and
speaker rows by name.

### Inference (`altatts/inference/`)

`Synthesizer` (0.1 API + keyword-only v2 controls), `StreamingSynthesizer`,
`checkpoint.py` (v1/v2 folders, `voices.json`), `voices.py` (`VoiceBank`),
`evaluate.py` (metrics, speaker similarity, WER gate, robustness set).
`speaker/enroll.py` embeds reference audio (windowed, averaged) and
optionally adapts the vector. `integrations/callcenter.py` is unchanged in
spirit with pass-through style kwargs and `enroll_agent`.

### Environment (`altatts/env/`)

`altatts doctor` — the ALTASR doctor for TTS: checks, compatibility verdict
over a data table (`compat_table.json`), safe `--fix` protocol with backup
and rollback, `--distributed` collective test, `--checkpoint` smoke.
`--fix` cross-checks the driver's CUDA ceiling, the GPU's compute-capability
floor and the wheels published on each PyTorch index (`wheels.py`), installs
the newest torch the machine can run with exact pins, and re-verifies CUDA
before accepting it.

## Repository layout

```
altatts/
    config.py               # dataclass tree (audio/text/model/style/prior/privacy/data/train)
    text.py tags.py         # front end: normalization, control tags, tokenizer, planner
    languages/              # rw / en / fr / sw specs (numbers, detection), registry
    lexicon.py              # user pronunciations, transliteration rules
    audio.py metrics.py     # decode, spectrograms, G.711; MCD, F0, WER/CER
    utils.py                # terminal, seeding, device, DDP helpers
    model/                  # the network (see table above)
    training/
        data.py prepare.py segment.py   # datasets, preparation, long-take splitting
        trainer.py train.py launch.py   # GAN trainer (early stopping, warmup), CLI, launcher
        logging.py                      # train.log / metrics.jsonl / status.json / TensorBoard, altatts logs
        anonymize.py                    # default-voice builder (privacy)
    speaker/                # enrollment (embed / adapt), altatts-enroll
    inference/              # Synthesizer, streaming, checkpoint I/O, voices, evaluate
    integrations/           # call-center glue
    env/                    # altatts doctor
    serving.py client.py    # HTTP/WebSocket API (stdlib) + client
    deploy.py               # altatts package (Docker deployment folder)
    datasets/               # multi-corpus pipeline: registry, adapters, combine, stats, cli
    recipes/                # ready configs shipped in the wheel (--recipe NAME)
    main_cli.py voices_cli.py benchmark.py export.py
configs/recipes/            # the same recipes, for --config from a checkout
notebooks/                  # 01_prepare_tts_data.ipynb (+ make_notebook.py generator)
docs/DATA_PIPELINE.md       # the combine pipeline, versioning, adding datasets
configs/                    # small/base/large preset dumps
docs/USAGE.md docs/DATASET.md
smoke_test.py tests/        # end-to-end check, pytest suite
```

Conventions shared with ALTASR: lazy torch imports at the package root,
checkpoint folders, identical metadata aliases and audio-path fallbacks,
bucketed batch sampling, robust decode chain (soundfile → torchaudio → av →
ffmpeg) with neighbour substitution for corrupt files, `runs/` for
experiments, terminal-clearing CLIs (`ALTATTS_NO_CLEAR=1` disables).

## Development

```bash
python -m venv .venv && . .venv/bin/activate
pip install -e ".[all,dev]"
altatts doctor                 # environment sanity
python -m pytest tests -q      # unit tests (~5 s with torch)
python smoke_test.py           # end-to-end: prepare → train → voices → clone → export (~3 min CPU)
python smoke_test.py --device cuda
```

Both legacy and v2 folders must keep loading: `tests/test_model.py`
asserts the v1 network has no v2 modules and `tests/test_config_and_data.py`
asserts a 0.1 config is detected as legacy.

## Presets

| preset | hidden | text enc | decoder ch. | prior (MeanFlow) | use |
|---|---|---|---|---|---|
| `small` | 192 | 6 layers | 256 | 4 × 192 | prototyping, CPU inference |
| `base`  | 192 | 6 layers | 512 | 6 × 256 | **recommended** |
| `large` | 256 | 6 layers, 4 heads, filter 1024, 6 flows | 512 | 8 × 384 | maximum quality, plentiful data |

## Extending

- **Language**: add `altatts/languages/<code>.py` with a `LanguageSpec`
  (number words, common words, orthography hints), register it in
  `languages/__init__.py`, train with `--languages … <code>`.
- **Tag**: add an alias in `tags.NONVERBAL_ALIASES` / `EMOTION_ALIASES`; new
  non-verbal kinds also go into `tags.NONVERBALS` (vocabulary).
- **Prior / style variants**: `PriorConfig` and `StyleConfig` are the only
  places the model reads hyper-parameters from; new modules attach in
  `SynthesizerTrn.__init__` under `if not self.legacy`.
- **Interfaces to keep**: `Synthesizer.tts(text, voice, sample_rate, speed,
  noise_scale)` positional order, `tts_to_file/tts_wav_bytes/pcm16_bytes/
  mulaw_bytes/alaw_bytes`, `voices()`, `StreamingSynthesizer.stream/feed/
  flush`, call-center helpers, checkpoint folder files, metadata aliases.

Apache-2.0 · YaliLabs / ALTA Project
