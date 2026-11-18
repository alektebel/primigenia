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
