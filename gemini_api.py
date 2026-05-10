import json
import re
from typing import Dict, Optional

import httpx

from config import settings


class GeminiNotConfiguredError(RuntimeError):
    pass


def _client() -> httpx.Client:
    if not settings.gemini_api_key:
        raise GeminiNotConfiguredError("GEMINI_API_KEY is missing")
    return httpx.Client(base_url=settings.gemini_base_url.rstrip("/"), timeout=60.0)


def generate_text(system: str, user: str, generation_config: Optional[Dict] = None) -> str:
    with _client() as c:
        payload = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": user}]}],
        }
        if generation_config:
            payload["generationConfig"] = generation_config

        r = c.post(
            f"/models/{settings.gemini_model}:generateContent",
            params={"key": settings.gemini_api_key},
            json=payload,
        )
        r.raise_for_status()
        data = r.json()
        return data["candidates"][0]["content"]["parts"][0]["text"] if data.get("candidates") else ""


def generate_json(system: str, user: str) -> dict:
    try:
        text = generate_text(
            system=system,
            user=user,
            generation_config={"responseMimeType": "application/json", "temperature": 0.2},
        ).strip()
    except httpx.HTTPStatusError as e:
        if e.response is not None and e.response.status_code == 400:
            text = generate_text(system=system, user=user).strip()
        else:
            raise
    m = re.search(r"\{[\s\S]*\}", text)
    if not m:
        raise ValueError("Model did not return JSON object")
    return json.loads(m.group(0))

