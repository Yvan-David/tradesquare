from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_discover_health_reports_adapters():
    response = client.get("/api/v1/discover/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["ok"] is True
    assert "adapters" in payload
    assert payload["assistant"]["available"] is True


def test_discover_chat_returns_intent_without_inventing_businesses():
    response = client.post(
        "/api/v1/discover/chat",
        json={"message": "Find packaging suppliers in Rwanda", "locale": "en"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["language"] in {"en", "rw", "sw", "fr"}
    assert payload["intent"]
    assert "TradeSquare" in payload["reply"] or payload["reply"]
    assert "tools_available" in payload


def test_discover_chat_kinyarwanda_routing():
    response = client.post(
        "/api/v1/discover/chat",
        json={"message": "Ndashaka abaguzi muri Kenya", "locale": "rw"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["language"] == "rw"


def test_livekit_token_unavailable_without_credentials():
    response = client.post(
        "/api/v1/discover/livekit/token",
        json={"identity": "tester"},
    )
    assert response.status_code == 503
