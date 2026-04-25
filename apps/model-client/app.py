#!/usr/bin/env python3
"""Minimal FastAPI proxy that exposes /health and /v1/predict and forwards to external MODEL_API_URL."""
import os
from fastapi import FastAPI, Request
import requests

app = FastAPI()

MODEL_API_URL = os.environ.get("MODEL_API_URL")
MODEL_API_KEY = os.environ.get("MODEL_API_KEY")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/v1/predict")
async def predict(req: Request):
    payload = await req.json()
    if not MODEL_API_URL:
        return {"error": "MODEL_API_URL not configured"}
    headers = {}
    if MODEL_API_KEY:
        headers["Authorization"] = f"Bearer {MODEL_API_KEY}"
    r = requests.post(MODEL_API_URL, json=payload, headers=headers, timeout=30)
    return r.json()

if __name__ == "__main__":
    import uvicorn
    host, port = os.environ.get("LISTEN", "127.0.0.1:31415").split(":")
    uvicorn.run("apps.model-client.app:app", host=host, port=int(port), log_level="info")
