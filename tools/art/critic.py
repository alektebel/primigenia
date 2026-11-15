#!/usr/bin/env python3
"""Art critic: send a render (PNG) and a rubric to a vision model, print the critique.

Used by the art agents (G66) so that models that cannot see images still get
visual feedback on their renders. OpenAI-compatible chat endpoints only.

    python3 tools/art/critic.py IMAGE.png --rubric RUBRIC.md [--context "what it should show"]
        [--provider cohere|nvidia] [--model NAME]

Keys come from the environment: gemini_api (Gemini free tier, Flash models only),
COHERE_API_KEY (Cohere trial: 1,000 calls/month, non-commercial) or NVIDIA_KEY. Standard library only.
"""
import argparse
import base64
import json
import os
import sys
import urllib.request

PROVIDERS = {
    "cohere": ("https://api.cohere.ai/compatibility/v1/chat/completions", "COHERE_API_KEY", "command-a-vision-07-2025"),
    "nvidia": ("https://integrate.api.nvidia.com/v1/chat/completions", "NVIDIA_KEY", "nvidia/nemotron-3.5-super-vl-120b-a12b"),
    # Free tier only (owner rule): Flash models. Native API; key in $gemini_api.
    "gemini": ("https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent", "gemini_api", "gemini-3.8-flash"),
}

PROMPT = """You are a strict art director for a stylised 3D nature game (toon-shaded world, BotW-like,
physically lit creatures). Critique this render against the rubric below. Be concrete and visual:
name what you see, where in the frame, and what is wrong. Then give the 3 most important changes,
each one specific enough to implement in code (colour values, sizes, counts, positions).
End with a score from 0 to 10 for each rubric item and an overall score.

What the render should show: {context}

Rubric:
{rubric}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--rubric", required=True)
    ap.add_argument("--context", default="see rubric")
    ap.add_argument("--provider", default="nvidia", choices=sorted(PROVIDERS))
    ap.add_argument("--model")
    a = ap.parse_args()
    url, keyvar, default_model = PROVIDERS[a.provider]
    key = os.environ.get(keyvar)
    if not key:
        sys.exit(f"{keyvar} is not set")
    with open(a.image, "rb") as f:
        img = base64.b64encode(f.read()).decode()
    with open(a.rubric, encoding="utf-8") as f:
        rubric = f.read()
    if a.provider == "gemini":
        model = a.model or default_model
        body = {"contents": [{"parts": [
            {"text": PROMPT.format(context=a.context, rubric=rubric)},
            {"inline_data": {"mime_type": "image/png", "data": img}}]}]}
        req = urllib.request.Request(url.format(model=model), json.dumps(body).encode(), {
            "x-goog-api-key": key, "Content-Type": "application/json", "User-Agent": "cpore-art-critic"})
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                out = json.load(r)
        except urllib.error.HTTPError as e:
            sys.exit(f"HTTP {e.code}: {e.read()[:500].decode(errors='replace')}")
        print("".join(p.get("text", "") for p in out["candidates"][0]["content"]["parts"]))
        return
    body = {
        "model": a.model or default_model,
        "max_tokens": 1500,
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": PROMPT.format(context=a.context, rubric=rubric)},
            {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img}"}},
        ]}],
    }
    req = urllib.request.Request(url, json.dumps(body).encode(), {
        "Authorization": f"Bearer {key}", "Content-Type": "application/json", "User-Agent": "cpore-art-critic"})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            out = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read()[:500].decode(errors='replace')}")
    msg = out["choices"][0]["message"]
    print(msg.get("content") or msg.get("reasoning_content") or json.dumps(out)[:1500])


if __name__ == "__main__":
    main()
