from fastapi.testclient import TestClient

from app import app


client = TestClient(app)


def test_health_returns_status_and_model_version():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "model_version" in body


def test_predict_returns_expected_shape():
    payload = {
        "message_length": 420,
        "customer_tier": "enterprise",
        "waiting_hours": 18,
        "sentiment_score": 0.15,
        "has_sla_breach": True,
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"priority_score", "prediction", "model_version"}


def test_metrics_endpoint_exposes_prometheus_text():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "ticket_priority_predictions_total" in response.text or "ticket_priority_latency_seconds" in response.text
