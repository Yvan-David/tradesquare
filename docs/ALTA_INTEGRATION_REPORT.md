# TradeSquare × ALTA integration — delivery report

**Date:** 2026-11-13  
**Status:** Foundation + translation routing + call orchestrator scaffolding delivered.  
**Not claimed complete:** end-to-end voice-preserving dual-participant LiveKit calls.

---

## 1. Files created

| Path | Role |
|------|------|
| `backend/app/ai/alta/config.py` | Env flags / timeouts |
| `backend/app/ai/alta/client.py` | Authenticated HTTP client (key server-side only) |
| `backend/app/ai/alta/capabilities.py` | Live capability probes + honest matrix |
| `backend/app/ai/alta/audio.py` | 16 kHz mono frame helpers + LiveKit format warnings |
| `backend/app/ai/alta/transcription.py` | File jobs + live WS helper / consent checks |
| `backend/app/ai/alta/translation.py` | Alta MT + Swahili external stub registry |
| `backend/app/ai/alta/tts.py` | TTS facade over existing Console adapter |
| `backend/app/ai/alta/cloning.py` | Consent-gated clone CRUD / speak |
| `backend/app/ai/alta/orchestrator.py` | Same-lang bypass + final-utterance pipeline |
| `backend/app/ai/alta/__init__.py` | Package exports |
| `backend/app/api/v1/alta.py` | REST + live transcription WS proxy |
| `backend/tests/test_alta_services.py` | Unit/API tests |
| `docs/ALTA_INTEGRATION_REPORT.md` | This report |

## 2. Files modified

| Path | Change |
|------|--------|
| `backend/app/main.py` | Mount `/api/v1/alta`, surface ALTA in `/api/v1/ai/status` |
| `backend/requirements.txt` | `websockets>=12.0` |
| `.env.example` | Full ALTA flag set |
| `frontend/.../call_models.dart` | Translation enable + real caption fields |
| `frontend/.../call_controls.dart` | AI on/off control; **removed fabricated captions** |
| `frontend/.../call_screen.dart` | Wire translation toggle |

Preserved: Discover adapters, local ALTATTS eval, LiveKit media stubs, messaging UI shell.

## 3. APIs integrated (documented)

| Capability | Endpoint(s) | Routed via |
|------------|-------------|------------|
| Status / health | `GET /v1/health`, models, languages, voices | `/api/v1/alta/status`, `/health` |
| Live STT | `WS /v1/transcription/live` (`altascribe.v2` + `bearer.<key>`) | `WS /api/v1/alta/transcription/live` |
| File STT | `POST/GET /v1/transcription/jobs` | `/api/v1/alta/transcription/jobs` |
| Translation | `POST /v1/translation/translate\|translate/batch\|detect`, `GET .../languages` | `/api/v1/alta/translation/*` |
| TTS | `POST /v1/synthesis/tts` (+ `readable`, default 22050 Hz) | `/api/v1/alta/tts/*` |
| Cloning | `/v1/cloning/voices` + `/speak` alias | `/api/v1/alta/cloning/*` |
| Call turn | Internal orchestrator | `POST /api/v1/alta/calls/turn` |

### Doc alignment (2026-11-13, pasted Developers docs)

- Gender enum: `female` \| `male` \| `other` \| `prefer_not_to_say` (removed `non_binary`)
- Live PCM default: float32 LE @ 16 kHz / 50 ms (3200 B); optional `pcm_s16le`
- Translation: `quality` default true; `source_hint`, `preserve_lines`, `on_unsupported`; batch route
- File STT: `quality` fast|accurate + optional profile fields
- TTS sample rate default **22050**; clone `/speak` exposed on our gateway

## 4. Actual language capabilities (per ALTA docs + our routing)

| Feature | Languages |
|---------|-----------|
| Live transcription v2 | **rw, en, fr** (not Swahili) |
| Live transcription v1 | **rw** only |
| Translation (ALTA) | **rw ↔ en ↔ fr** (six directions). **Swahili unsupported** |
| TTS / clone speak | **rw, sw, en, fr** (documented) |
| Swahili translation | **Unavailable** until a separate tested provider is configured |

## 5. Features tested successfully (automated)

- Consent/gender validation helpers  
- Audio format warning helpers (48 kHz / stereo / non-PCM)  
- Alta provider rejects SW pairs; registry routes SW → honest unavailable stub  
- Same-language orchestrator bypass  
- `/api/v1/alta/status` and `/languages` without inventing SW MT  
- Existing Alta Console TTS eval (prior session) with real key for RW/SW **synthesis** only  

## 6. Still needs credentials / external services / manual QA

- Enabling feature flags (`ALTA_ENABLED`, per-capability flags) after product/privacy review  
- Live WS smoke with real microphone PCM (16 kHz mono)  
- File transcription with consenting upload  
- Real `rw↔en` / `rw↔fr` translation calls with key  
- Voice cloning with **consenting** reference audio + human A/B  
- Dual-device LiveKit capture → proxy → translate → play without echo  

## 7. Missing Swahili translation dependency

**Unresolved.** `SwahiliTranslationProvider` returns unavailable. Do not copy SW text as “translated”. Options later: LibreTranslate/self-hosted SW models, or another approved MT API.

## 8. Cross-language voice preservation

**Not claimed.** Cloning APIs are wired with dual consent flags; no consenting enrollment + similarity evaluation was completed in this pass.

## 9. Measured end-to-end latency

| Path | Measurement |
|------|-------------|
| Hosted TTS one-shot (prior eval) | Service ~133–197 ms (RW/SW shipped voices) |
| Hosted TTS stream first audio (prior eval) | Service ~40 ms; client TTFB ~3 s |
| Full call STT→MT→TTS→playback E2E | **Not measured** (LiveKit audio injection not complete) |
| p50 / p95 call translation | **Not measured** |

## 10. Remaining production blockers

1. LiveKit real track I/O + resampling to 16 kHz mono before ALTA.  
2. Dual-party consent UX before forwarding call audio.  
3. Swahili MT provider.  
4. Feature flags default **off**; enable gradually.  
5. Rotate any API key that was pasted in chat.  
6. Human review of TTS/clone quality.  
7. Echo/feedback prevention tests on two real devices.  

---

## How to enable (staging only)

```bash
# .env (never commit)
ALTA_BASE_URL=https://alta.yalilabs.com/v1
ALTA_API_KEY=ak_...
ALTA_ENABLED=true
ALTA_TTS_ENABLED=true
ALTA_TRANSLATION_ENABLED=true
ALTA_LIVE_TRANSCRIPTION_ENABLED=true
# Keep false until LiveKit wiring + consent UX ship:
ALTA_CALL_TRANSLATION_ENABLED=false
ALTA_VOICE_CLONING_ENABLED=false
ALTA_LIVE_TRANSCRIPTION_PERSIST=false
```

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
# GET http://localhost:8000/api/v1/alta/status
```

Flutter continues to use `TRADESQUARE_API_BASE_URL`; the ALTA secret stays on FastAPI.
