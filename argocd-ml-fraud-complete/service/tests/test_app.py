from fastapi.testclient import TestClient

from app import app


client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "model_version" in body


def test_predict_returns_model_version_and_prediction():
    payload = {
        "amount": 1200.0,
        "merchant_category": "travel",
        "hour_of_day": 3,
        "country": "US",
        "is_international": True,
        "device_risk_score": 0.82,
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["prediction"] in {"fraud", "legit"}
    assert "model_version" in body


def test_metrics_endpoint_is_available():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert (
        "fraud_prediction_latency_seconds" in response.text
        or "fraud_predictions_total" in response.text
    )
