import json
import re
from typing import Dict, Optional

import httpx
from openai import OpenAI

from config import settings


class GeminiNotConfiguredError(RuntimeError):
    pass


def _client() -> httpx.Client:
    if not settings.gemini_api_key:
        raise GeminiNotConfiguredError("GEMINI_API_KEY is missing")
    return httpx.Client(
        base_url=settings.gemini_base_url.rstrip("/"),
        timeout=float(settings.llm_timeout_seconds),
    )


def _openai_client() -> OpenAI:
    if not settings.openai_api_key:
        raise GeminiNotConfiguredError("OPENAI_API_KEY is missing for text-generation fallback")
    return OpenAI(
        api_key=settings.openai_api_key,
        base_url=settings.openai_base_url.rstrip("/"),
        timeout=float(settings.llm_timeout_seconds),
    )


def _openai_generate_text(
    system: str,
    user: str,
    generation_config: Optional[Dict] = None,
) -> str:
    client = _openai_client()
    request_kwargs = {}
    temperature = None
    if generation_config:
        temperature = generation_config.get("temperature")
        if generation_config.get("responseMimeType") == "application/json":
            request_kwargs["response_format"] = {"type": "json_object"}

    response = client.chat.completions.create(
        model=settings.openai_text_model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=temperature,
        **request_kwargs,
    )
    return response.choices[0].message.content or ""


def generate_text(system: str, user: str, generation_config: Optional[Dict] = None) -> str:
    try:
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
    except GeminiNotConfiguredError:
        return _openai_generate_text(system=system, user=user, generation_config=generation_config)
    except httpx.HTTPStatusError as error:
        if error.response is not None and error.response.status_code in {429, 500, 502, 503, 504}:
            return _openai_generate_text(system=system, user=user, generation_config=generation_config)
        raise
    except httpx.HTTPError:
        return _openai_generate_text(system=system, user=user, generation_config=generation_config)


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

