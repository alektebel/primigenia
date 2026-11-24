"""Voice -> opencode model map and the shared cooldown marker (used by council.py and autoloop.py)."""
import os, re, time

# advisors served by opencode free-tier models instead of qwen (model diversity).
# "senses" was glm-5.3-flash-free, permanently "Model unavailable" (A102.4); mimo-v2.6-flash-free answered a live test on 2026-11-24.
OC_MODEL = {"skeptic": "opencode/deepseek-v4.1-flash-free", "senses": "opencode/mimo-v2.6-flash-free"}


def down_file(runs_dir, model):
    return os.path.join(runs_dir, "oc_down_until_" + re.sub(r"\W+", "_", model))


def on_cooldown(runs_dir, voice):
    """True when the opencode model behind this voice is cooling down (its quota or availability failed recently)."""
    m = OC_MODEL.get(voice)
    if not m: return False
    p = down_file(runs_dir, m)
    try: return os.path.exists(p) and time.time() < float(open(p).read() or 0)
    except (OSError, ValueError): return False
