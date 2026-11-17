"""Minimal OpenAI-compatible client (urllib only) with retries, a concurrency cap and usage log."""
from __future__ import annotations

import json
import os
import threading
import time
import urllib.error
import urllib.request

BASE = os.environ.get("NAN_BASE_URL", "https://api.nan.builders/v1")
MAX_CONCURRENT = 4          # qwen allows 5; stay under
_sem = threading.BoundedSemaphore(MAX_CONCURRENT)


class LLMError(Exception):
    pass


def chat(messages, model="qwen3.6", max_tokens=200, temperature=0.7, retries=5, timeout=120):
    """Returns (text, usage dict, latency seconds). Raises LLMError after retries."""
    key = os.environ.get("NAN_API_KEY")
    if not key:
        raise LLMError("NAN_API_KEY not set")
    body = {"model": model, "messages": messages, "max_tokens": max_tokens,
            "temperature": temperature, "chat_template_kwargs": {"enable_thinking": False}}
    last = None
    for attempt in range(retries):
        req = urllib.request.Request(
            BASE + "/chat/completions", json.dumps(body).encode(),
            {"Content-Type": "application/json", "Authorization": "Bearer " + key,
             "User-Agent": "opencode"})
        try:
            with _sem:
                t0 = time.time()
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    d = json.load(r)
                dt = time.time() - t0
            msg = d["choices"][0]["message"]
            text = msg.get("content") or ""
            return text, d.get("usage", {}), dt
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}"
            if e.code not in (408, 409, 425, 429, 500, 502, 503, 504):
                raise LLMError(last) from e
        except Exception as e:  # noqa: BLE001
            last = f"{type(e).__name__}: {e}"
        time.sleep(min(30, 2 ** attempt + 0.5 * attempt))
    raise LLMError(f"gave up after {retries} tries: {last}")
