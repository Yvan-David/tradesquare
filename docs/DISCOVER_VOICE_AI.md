# TradeSquare Discover — Voice & Conversational AI

## Already implemented (working)

- Conversational Discover UI (unchanged layout in this upgrade)
- On-device STT via `speech_to_text`
- On-device TTS via `flutter_tts` with phrase chunking / speakable cleanup
- Multilingual routing: English, Kinyarwanda, Kiswahili, French
- Catalog search with progressive business cards
- Platform tools: Messages, My Business, Opportunities, Home, drafts
- Session follow-up / correction memory
- Cascading STT/TTS adapters with honest remote fallbacks
- FastAPI `/api/v1/discover/health|capabilities|chat|voice/providers|livekit/token`

## Successfully integrated in this pass

- Modular STT cascade (`remote NVIDIA worker` → device)
- Modular TTS cascade (`remote Kinya TTS worker` → device)
- Speech naturalness helpers (strip markdown/JSON, concise spoken replies, sentence chunks)
- Barge-in: interrupt cancels assistant turn + stops audio immediately
- Avoid speaking progress-only “thinking…” lines
- Shorter natural result summaries that cite real catalog reasons
- Local heuristic LLM adapter used by Discover chat endpoint
- LiveKit credential-aware token endpoint (optional dependency)

## Still requires credentials / model weights / infrastructure

| Capability | Requirement | Status |
|---|---|---|
| NVIDIA `stt_rw_conformer_ctc_large` | GPU + NeMo or Riva worker; `DISCOVER_STT_WORKER_URL` | Not loaded. HF card is file/chunk transcription (~18% WER on MCV-9). Streaming needs Riva/custom chunking. |
| C4IR `kinya-flex-tts` / Mbaza TTS | GPU/CPU worker, license review, native-speaker QA, `DISCOVER_TTS_WORKER_URL` | Not loaded. Do not claim natural Kinyarwanda voice quality yet. |
| LiveKit Agents full duplex | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `livekit` Python package, Flutter `livekit_client` | Token route ready when creds exist; room client not wired. |
| Remote generative LLM | Approved provider + `DISCOVER_LLM_URL` | Boundary only; local heuristic remains active. |

## How to run locally

### Flutter (default, no GPU)

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port=8080 --no-web-resources-cdn
```

Voice uses on-device STT/TTS automatically.

### FastAPI

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Check:

- `GET http://localhost:8000/api/v1/discover/capabilities`
- `POST http://localhost:8000/api/v1/discover/chat` with `{"message":"Find suppliers in Kenya"}`

### Optional LiveKit

1. Set `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` in `.env`
2. `pip install livekit`
3. `POST /api/v1/discover/livekit/token` with `{"identity":"demo-user"}`
4. Wire Flutter LiveKit room client (not enabled by default)

## Evaluation notes (no fabricated audio benchmarks)

- **NVIDIA STT**: documented as NeMo file transcription; ~120M params; reported test WER 18.22% on MCV-9. Not embedded in-app.
- **Device STT/TTS latency**: depends on OS/browser; expect first spoken reply after catalog match completes (typically hundreds of ms to a few seconds on web). Exact device timings vary; measure on target handsets before claiming production readiness.
- **Kinyarwanda TTS naturalness**: not certified with native speakers in this environment.

## Architecture

```
Discover UI
  ├─ Cascading STT adapter → device speech_to_text (fallback)
  ├─ Cascading TTS adapter → flutter_tts chunked speech (fallback)
  ├─ Conversation memory (follow-ups / corrections)
  ├─ Local assistant + catalog search (authoritative business results)
  └─ Optional FastAPI chat / LiveKit token / remote workers
```
