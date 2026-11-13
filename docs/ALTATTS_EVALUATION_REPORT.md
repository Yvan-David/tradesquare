# ALTATTS 2.1.0 evaluation for TradeSquare live calls

**Date:** 2026-11-13  
**Package:** [`altatts==2.1.0`](https://pypi.org/project/altatts/)  
**Recommendation: investigate further — do not integrate into production calls yet.**

This report records what was inspected and what could **not** be measured. No audio quality, voice-similarity, or latency numbers are invented.

---

## 1. Package inspection (before production install)

| Item | Finding |
|------|---------|
| License | **Apache-2.0** (`pyproject.toml` / PyPI METADATA) |
| Python | `>=3.9` |
| Core deps | `torch>=2.3`, `torchaudio>=2.3`, `numpy`, `soundfile`, `tqdm` |
| Optional | `av`, `altasr`, `onnx`, `transformers`, `numba`, … |
| Wheel size | ~259 KB (code only) |
| Model weights in PyPI | **None** |
| GitHub homepage | `https://github.com/yalilabs/altatts` → **404** at evaluation time |
| Upstream tests in sdist | Present under `tests/` (config, text frontend, doctor, serving with synthetic model dirs, etc.). **No shipped public `kin_v2` checkpoint**; cloning/serving tests expect a local `model_dir`. |
| Model loading | `Synthesizer.from_pretrained(folder)` loads a training output folder: `config.json`, `tokenizer.json`, `speakers.json`, `voices.json`, `model.pt` (or `best.pt` / `checkpoint.pt`) |

Inspected artifacts were downloaded to `C:\tradesquare-eval\` (outside the app runtime) for source review.

### Voice cloning API (code-level)

ALTATTS 2 synthesizer supports:

- `reference_audio=` (path / array / list of clips)
- `speaker_embedding=` from `tts.embed_speaker(...)`
- `tts.clone(text, reference_audio=...)`
- `enroll_speaker(name, clips)`

`capabilities()["voice_cloning"]` is true only when the checkpoint is generation **ALTATTS 2** (`model.version == 2`). Legacy 0.1 VITS folders do not clone.

### Streaming API (code-level)

`StreamingSynthesizer` is **phrase/sentence-level**: each chunk is a full non-autoregressive forward pass after a sentence boundary. It is **not** sample-by-sample or true low-level audio frame streaming. Docs recommend `steps=1` (CPU) or `steps=2` (GPU live).

### Languages (docs + text frontend)

Documented: Kinyarwanda (`rw`), Kiswahili (`sw`), English (`en`), French (`fr`), with code-switching helpers. This is API/docs coverage, not a measured quality claim.

---

## 2. Model weights and hardware

| Question | Answer |
|----------|--------|
| Are weights available on PyPI? | **No** |
| Public `runs/kin_v2` download found? | **No** (docs treat it as a local train output) |
| Hosted alternative | [Alta Console synthesis](https://alta.yalilabs.com/developers/synthesis) is a **hosted** API (`alta-tts`). TradeSquare policy: do **not** adopt paid/hosted APIs without approval. Their published latency figures are **vendor claims**, not TradeSquare measurements. |
| How to obtain weights | Train with `altatts-train` / recipe `multilingual_callcenter`, or obtain a licensed checkpoint from YaliLabs / ALTA and set `ALTATTS_MODEL_PATH` |

### Hardware (from package docs + architecture — not local timed runs)

- **CPU:** supported; docs recommend `steps=1` for live use (slower / less natural than GPU).
- **GPU (CUDA):** preferred for `steps=2–4` live synthesis; `altatts doctor --fix` aligns torch wheels to the driver.
- **RAM/VRAM:** not quantified in the package metadata; expect several GB for PyTorch + model (exact size depends on the checkpoint). Measure after you have `model.pt`.
- **Disk:** torch + torchaudio wheels alone are multi‑GB; keep evaluation venv on a drive with free space (this machine’s D: was ~0.5 GB free during eval).

---

## 3. Audio evaluation status (required tests)

Consenting reference speakers and a real checkpoint were **not** available in this environment.

| Required test | Status |
|---------------|--------|
| RW synthesis alone | **BLOCKED** — no checkpoint |
| SW synthesis alone | **BLOCKED** — no checkpoint |
| RW reference → SW speech (voice preserve) | **BLOCKED** — no checkpoint / no consenting RW WAV |
| SW reference → RW speech (voice preserve) | **BLOCKED** — no checkpoint / no consenting SW WAV |
| Voice similarity (embedding + human A/B) | **NOT MEASURED** |
| Pronunciation / intelligibility | **NOT MEASURED** |
| First-audio latency | **NOT MEASURED** |
| Total generation time | **NOT MEASURED** |
| `StreamingSynthesizer` `steps=1` | **NOT MEASURED** |
| `StreamingSynthesizer` `steps=2` | **NOT MEASURED** |

**Voice preservation is not claimed.**

---

## 4. What was added to TradeSquare (safe, non-production)

| Piece | Role |
|-------|------|
| `backend/app/ai/altatts_adapter.py` | Separate adapter status/capabilities probe. Does **not** replace KinyaFlex / device TTS. |
| `backend/scripts/eval_altatts_calls.py` | Offline harness; writes `artifacts/altatts_eval/report.json` when inputs exist. |
| Env vars | `ALTATTS_MODEL_PATH`, `ALTATTS_REF_RW_WAV`, `ALTATTS_REF_SW_WAV`, `ALTATTS_DEVICE`, `ENABLE_ALTATTS_CALLS` |
| Production calls | **Not wired.** `ENABLE_ALTATTS_CALLS` must stay off until the harness passes and humans review cloning audio. |

LiveKit / FastAPI call media plane remains unchanged by this evaluation.

---

## 5. Installation instructions (evaluation venv only)

Use a **separate** venv (preferably on a disk with several free GB). Do not fold this into production until approved.

```bash
# Windows example on C:
python -m venv C:\tradesquare-eval\altatts-venv
C:\tradesquare-eval\altatts-venv\Scripts\activate

# Prefer CPU wheels first if no CUDA; or run: altatts doctor --fix
pip install "altatts==2.1.0" soundfile

# After you have a real ALTATTS 2 checkpoint + consenting refs:
set ALTATTS_MODEL_PATH=C:\path\to\kin_v2
set ALTATTS_REF_RW_WAV=C:\path\to\consenting_rw.wav
set ALTATTS_REF_SW_WAV=C:\path\to\consenting_sw.wav
set ALTATTS_DEVICE=cpu

cd d:\tradesquare\backend
python scripts\eval_altatts_calls.py
```

Expected checkpoint layout:

```
kin_v2/
  config.json
  tokenizer.json
  speakers.json
  voices.json
  model.pt
```

Confirm cloning: `tts.capabilities()["generation"] == "ALTATTS 2"` and `voice_cloning is True`.

---

## 6. Limitations

1. Open-source package ≠ runnable voice system without a trained/licensed checkpoint.  
2. Streaming is phrase-level, not continuous frame streaming.  
3. Embedding cosine ≠ perceptual voice identity; human A/B (and preferably speaker-verification MOS) required.  
4. Intelligibility needs ALTASR / native-speaker review for RW and SW.  
5. Hosted Alta Console is a different product surface; treating it as free local ALTATTS weights would be incorrect.  
6. GitHub source tree was unreachable (404); rely on PyPI sdist for code review until the repo is public again.

---

## 7. Hosted Alta Console follow-up (API key provided)

A gitignored `ALTA_API_KEY` was configured locally and evaluated with
`backend/scripts/eval_alta_console_tts.py` against `https://alta.yalilabs.com/v1`.

**Security:** The key was pasted in chat — **rotate it** in the Alta console after this session.

| Check | Result (measured this run) |
|-------|----------------------------|
| Auth | OK (`speech:synthesize` in scopes) |
| Model | `alta-tts-multilingual-v2` |
| RW one-shot (`keza`) | service **171.9 ms**, client ~3.5 s, audio **4.55 s** |
| SW one-shot (`keza`) | service **197.3 ms**, client ~4.0 s, audio **4.35 s** |
| SW one-shot (`ganza`) | service **132.6 ms**, client ~4.0 s, audio **3.88 s** |
| Stream RW first audio | service **40.2 ms**; client first byte ~3.1 s (network/TTFB) |
| Stream SW first audio | service **39.9 ms**; client first byte ~2.8 s |
| Voice cloning / preservation | **Not run** — no consenting reference WAVs; **not claimed** |
| Production LiveKit wiring | **Off** (`ENABLE_ALTA_CONSOLE_TTS=0`) |

WAVs: `backend/artifacts/alta_console_eval/`. Pronunciation/intelligibility still need human or ASR review.

Hosted Console ≠ local `altatts` PyPI weights. Prefer Console for call TTS only after product approval of the hosted dependency.

## 8. Recommendation

**Investigate further** (local package still blocked on weights).

**Hosted Alta Console:** promising for RW/SW synthesis latency on the service side; **not production-wired**. Next: human listen to the WAVs, then optional cloning with consenting refs, then decide whether to enable `ENABLE_ALTA_CONSOLE_TTS` behind the call translation worker.

Until then, keep Discover/device TTS and existing call translation adapters as they are.
