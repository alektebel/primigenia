"""Shared helpers for the lore tools (stdlib + jsonschema)."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dump(obj, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
        f.write("\n")


def creature_files(root):
    d = os.path.join(root, "lore", "creatures")
    return sorted(os.path.join(d, n) for n in os.listdir(d) if n.endswith(".json")) if os.path.isdir(d) else []


def slug(text):
    import re, unicodedata
    t = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", t).strip("_")


def flora_files(root):
    d = os.path.join(root, "lore", "flora")
    return sorted(os.path.join(d, n) for n in os.listdir(d) if n.endswith(".json")) if os.path.isdir(d) else []


# ---- A102.3: the council writes no game numbers. A skill keeps a name, a role and a plain behaviour description. ----
import re as _re
_NUM = r"\d+(?:[.,]\d+)?"
GAME_NUMBER = _re.compile(
    r"(?:[+\-−×x]\s*)?" + _NUM + r"\s*(?:%|per\s?cent\b|turns?\b|rounds?\b|seconds?\b|secs?\b|s\b|ms\b|minutes?\b|min\b|metres?\b|meters?\b|km\b|m\b|hp\b|dmg\b|damage\b)"
    r"|\b(?:for|every|within|after)\s+" + _NUM + r"\b|\b" + _NUM + r"\s*[×x]\s", _re.I)


_ANY_NUM = _re.compile(r"\b\d")


def has_game_numbers(text):
    """Units/percent/turns/seconds with digits, or any standalone number at all: a skill description needs none (A102.3)."""
    t = text or ""
    return bool(GAME_NUMBER.search(t) or _ANY_NUM.search(t))


_PHRASE = _re.compile(r"[,;]?\s*\(?\b(?:from|at|up to|over|within|for|lasting|of|by|after|every|about|around)\s+(?:about\s+|around\s+)?" + GAME_NUMBER.pattern + r"\)?", _re.I)


def behaviour_only(effect, fallback=""):
    """Drop every sentence/clause of a skill effect that carries a game number (digits with %, turns, s, m ...); keep the behaviour."""
    parts = _re.split(r"(?<=[.!?])\s+", _PHRASE.sub("", (effect or "").strip()))
    kept = []
    for p in parts:
        if not has_game_numbers(p): kept.append(p); continue
        cl = [c for c in _re.split(r"\s*[;]\s*|,\s+(?=(?:and|but|which|while|for|lasting|reducing|gaining|giving|dealing|increasing)\b)", p) if c and not has_game_numbers(c)]
        c2 = " ".join(cl).strip(" ,;")
        if len(c2.split()) >= 4: kept.append(c2[0].upper() + c2[1:] + ("" if c2[-1] in ".!?" else "."))
    out = " ".join(kept).strip()
    return out if len(out.split()) >= 4 else fallback
