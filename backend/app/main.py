from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.alta import router as alta_router
from app.api.v1.calls import router as calls_router
from app.api.v1.catalog import router as catalog_router
from app.api.v1.discover import router as discover_router
from app.ai.adapters import discover_ai_status
from app.ai.alta.config import load_alta_settings
from app.ai.alta.orchestrator import CallTranslationOrchestrator
from app.ai.call_translation import CallTranslationAdapter

app = FastAPI(title="TradeSquare API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(catalog_router)
app.include_router(discover_router)
app.include_router(calls_router)
app.include_router(alta_router)


@app.get("/health")
def health() -> dict:
    return {"ok": True, "service": "tradesquare-api"}


@app.get("/api/v1/ai/status")
def ai_status() -> dict:
    settings = load_alta_settings()
    status = discover_ai_status()
    status["calls"] = {
        "translation": CallTranslationAdapter().status(),
        "stt": CallTranslationAdapter().transcribe_chunk_status(),
        "orchestrator": CallTranslationOrchestrator().status(),
    }
    status["alta"] = {
        "configured": settings.configured,
        "enabled": settings.enabled,
        "flags": {
            "transcription": settings.transcription_enabled,
            "translation": settings.translation_enabled,
            "tts": settings.tts_enabled,
            "voice_cloning": settings.voice_cloning_enabled,
            "live_transcription": settings.live_transcription_enabled,
            "call_translation": settings.call_translation_enabled,
        },
        "status_route": "/api/v1/alta/status",
    }
    return status
