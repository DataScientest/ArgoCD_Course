import os
import time
from typing import Literal

from dotenv import load_dotenv
from fastapi import FastAPI
from pydantic import BaseModel, Field
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.responses import Response

load_dotenv()

MODEL_VERSION = os.getenv("MODEL_VERSION", "v1")

REQUEST_COUNT = Counter(
    "ticket_priority_predictions_total",
    "Nombre total de predictions de priorite",
    ["model_version", "prediction"],
)
REQUEST_LATENCY = Histogram(
    "ticket_priority_latency_seconds",
    "Latence des predictions de priorite",
    ["model_version"],
)


class TicketRequest(BaseModel):
    message_length: int = Field(ge=1)
    customer_tier: str
    waiting_hours: int = Field(ge=0)
    sentiment_score: float = Field(ge=0, le=1)
    has_sla_breach: bool


class TicketResponse(BaseModel):
    priority_score: float
    prediction: Literal["high", "normal"]
    model_version: str


app = FastAPI(title="Support Priority Service", version=MODEL_VERSION)


def score_request(payload: TicketRequest) -> float:
    score = 0.05
    if payload.message_length > 300:
        score += 0.35
    if payload.has_sla_breach:
        score += 0.30
    if payload.sentiment_score < 0.3:
        score += 0.30
    if payload.waiting_hours > 12:
        score += 0.10
    if payload.customer_tier == "enterprise":
        score += 0.10
    if MODEL_VERSION == "v2":
        score += 0.05
    return max(0.0, min(score, 0.99))


@app.post("/predict", response_model=TicketResponse)
def predict(payload: TicketRequest):
    started_at = time.perf_counter()
    probability = score_request(payload)
    prediction = "high" if probability >= 0.5 else "normal"
    REQUEST_COUNT.labels(model_version=MODEL_VERSION, prediction=prediction).inc()
    REQUEST_LATENCY.labels(model_version=MODEL_VERSION).observe(time.perf_counter() - started_at)
    return TicketResponse(
        priority_score=round(probability, 4),
        prediction=prediction,
        model_version=MODEL_VERSION,
    )


@app.get("/health")
def health():
    return {"status": "ok", "model_version": MODEL_VERSION}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
