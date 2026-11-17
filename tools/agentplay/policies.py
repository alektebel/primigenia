"""Policies: scripted/random (no LLM) and the LLM agent with a Q12-style small prompt."""
from __future__ import annotations

import json
import random
import zlib
import re

from llm import chat, LLMError

PERSONAS = {
    "fighter": "Your goal: defeat the creature named Garfio (id #1) in combat, then survive. "
               "Fights hurt: watch your hp, retreat to the nest if you are losing.",
    "explorer": "Your goal: cover as much new ground as possible and find interesting things "
                "(creatures, rocks, trees, water, the nest). Avoid fights, keep moving to new places.",
    "survivor": "Your goal: stay alive as long as possible. Avoid danger. The nest is your safe place. "
                "Never die.",
    "chaos": "Your goal: stress-test the game interface. Try odd and edge-case commands: invalid ids, "
             "huge numbers, negative numbers, misspelled verbs, spam the same verb, mix valid and "
             "invalid commands. Vary what you try each turn. Never stop trying.",
    "newcomer": "You have never seen this game and nobody explained its goal. Try things to learn what "
                "is going on. In every reply add a NOTE: line saying what you do not understand or "
                "what information you wish you had.",
}

SYSTEM = """You control one creature in a valley (metres; 10 ticks per second, each of your turns lasts about 2 seconds). Each turn you get a JSON observation (schema world-2) and answer with ONE command.
Commands (one per turn; the last accepted order keeps running until you give a new one):
  go X Z            walk to coordinates (routes around cliffs and water; "unreachable" if there is no way)
  heading DEG       walk in a direction (degrees: 0 = +z, 90 = +x, clockwise seen from above)
  approach #ID      walk toward creature ID
  attack #ID MOVE   attack creature ID with a move from attack_moves (name or number)
  flee              run away from the nearest creature (error no_threat if none is within 30 m)
  go_nest           return to the nest (safe place)
  wait              stand still
Only verbs in legal_verbs are available. Observation fields:
  world: bound (you can walk within +-bound on x and z), units, nest {{x,z}}, tick_hz
  own: x, z, hp, stamina (and their maxima), speed, facing (unit vector)
  last_error: result of your last command ("ok" or why it was rejected); it stays until your next command
  blocked: null, or {{reason: cliff|water|edge|obstacle|creature|unreachable, x, z}} when you were stopped during the last tick
  events: what happened since your last turn: hit {{by,target,move,damage}}, kill, death, respawn, order_rejected, path_found, arrived, fled, path_failed (ids: 0 = you, 1.. = creatures); a kill, death or fled event also ends your standing order
  nearby: creatures and carcasses (id, species, distance, bearing in degrees relative to your facing, positive = clockwise/right, hp, hp_max, state roam|alert|fighting|carcass|dead, in_fight), the nest, rocks and trees within 40 m
Reply format:
ACTION: <one command>
NOTE: <optional short memory for yourself, max 200 chars>
{persona}"""

FIGHT_ORDER = ["bite", "charge", "spit", "tail_strike"]


def parse_reply(text: str):
    """Returns (command or None, note or None, how). Robust to JSON, prose and code fences."""
    if not text or not text.strip():
        return None, None, "empty"
    note = None
    m = re.search(r"NOTE:\s*(.+)", text)
    if m:
        note = m.group(1).strip()[:200]
    t = text.strip().strip("`")
    # JSON form
    jm = re.search(r"\{.*\}", text, re.S)
    if jm:
        try:
            j = json.loads(jm.group(0))
            if isinstance(j, dict):
                note = note or (str(j.get("note"))[:200] if j.get("note") else None)
                a = j.get("action") or j.get("command") or j.get("verb")
                if isinstance(a, dict):
                    a = a.get("command") or a.get("verb")
                if isinstance(a, str):
                    args = j.get("args") or j.get("target") or ""
                    return _clean((a + " " + str(args)).strip() if args and args not in a else a), note, "json"
        except ValueError:
            pass
    m = re.search(r"ACTION:\s*`?([^\n`]+)", text, re.I)
    if m:
        return _clean(m.group(1)), note, "action"
    for line in t.splitlines():
        line = line.strip().strip("`").strip()
        if re.match(r"^(go|heading|approach|attack|flee|go_nest|wait)\b", line, re.I):
            return _clean(line), note, "line"
    return None, note, "unparsed"


def _clean(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip().strip("`'\".")).strip()


class ScriptedPolicy:
    def __init__(self, persona, seed):
        self.persona = persona
        self.rng = random.Random(seed * 7919 + zlib.crc32(persona.encode()) % 1000)   # not hash(): str hashes change per process
        self.i = 0
        self.dir = self.rng.uniform(0, 360)

    def act(self, obs, history):
        self.i += 1
        o = obs
        live = [n for n in o["nearby"] if n["type"] == "creature"]
        moves = [m["name"] for m in o["attack_moves"]] or ["bite"]
        p = self.persona
        if p == "fighter":
            tgt = next((n for n in live if n["id"] == 1), None)
            if o["own"]["hp"] < 25:
                return "go_nest", None
            if tgt:
                if tgt["distance"] > 3:
                    return "approach #1", None
                return f"attack #1 {moves[self.i % len(moves)]}", None
            return "approach #1", None
        if p == "explorer":
            if self.i % 4 == 1:
                self.dir = self.rng.uniform(0, 360)
            return f"heading {self.dir:.0f}", None
        if p == "survivor":
            return ("go_nest" if self.i % 5 == 1 else "wait"), None
        if p == "newcomer":
            return self.rng.choice(["wait", "heading 90", "approach #1", "go_nest", "flee"]), "scripted newcomer has no questions"
        return RandomPolicy(self.rng).act(obs, history)


class RandomPolicy:
    def __init__(self, rng):
        self.rng = rng if isinstance(rng, random.Random) else random.Random(rng)

    def act(self, obs, history):
        r = self.rng
        legal = obs["legal_verbs"]
        v = r.choice(legal + ["bogus", "attack", "approach"])
        ids = [n["id"] for n in obs["nearby"]] + [0, -1, 99, 24, 25, 99999999999]
        moves = [m["name"] for m in obs["attack_moves"]] + ["nope", "9", "-1", "99"]
        c = {"go": lambda: f"go {r.uniform(-400, 400):.1f} {r.choice([r.uniform(-400, 400), 1e30, -5000]):.1f}",
             "heading": lambda: f"heading {r.choice([r.uniform(-720, 720), 1e9, 'nan'])}",
             "approach": lambda: f"approach #{r.choice(ids)}",
             "attack": lambda: f"attack #{r.choice(ids)} {r.choice(moves)}",
             "bogus": lambda: r.choice(["", "dance", "go", "attack #1", "heading", "go 1", "wait now", "ATTACK #1 bite", "go_nest please"]),
             }.get(v, lambda: v)()
        return c, None


class LLMPolicy:
    def __init__(self, persona, model, seed, temperature=0.7):
        self.persona = persona
        self.model = model
        self.temperature = temperature
        self.notes = ""
        self.usage = {"prompt": 0, "completion": 0, "calls": 0, "latency": 0.0}
        self.system = SYSTEM.format(persona=PERSONAS[persona])
        self.last_prompt_chars = 0
        self.last_reply = ""
        self.errors = []

    def act(self, obs, history):
        hist = "\n".join(f"t{h['turn']}: {h['cmd'] or '(none)'} -> {h['error']}, moved {h['moved']}, hp {h['hp']:.0f}"
                         for h in history[-20:])
        user = (f"NOTES: {self.notes or '(none)'}\nRECENT TURNS:\n{hist or '(none)'}\n"
                f"OBSERVATION:\n{json.dumps(obs, separators=(',', ':'))}\nYour command?")
        msgs = [{"role": "system", "content": self.system}, {"role": "user", "content": user}]
        self.last_prompt_chars = len(self.system) + len(user)
        try:
            text, usage, dt = chat(msgs, model=self.model, temperature=self.temperature)
        except LLMError as e:
            self.errors.append(str(e))
            self.last_reply = f"<LLM error: {e}>"
            return None, None
        self.usage["prompt"] += usage.get("prompt_tokens", 0)
        self.usage["completion"] += usage.get("completion_tokens", 0)
        self.usage["calls"] += 1
        self.usage["latency"] += dt
        self.last_reply = text
        cmd, note, how = parse_reply(text)
        if note:
            self.notes = (self.notes + " | " + note)[-600:]
        self.last_parse = how
        return cmd, note

    def usability_question(self, stats):
        q = (f"The session is over ({stats}). Looking back at the observations and commands you were given: "
             "list up to 5 things that were confusing, missing or misleading (e.g. missing information, unclear "
             "units, errors you could not understand, results you could not tell). One per line starting with '- '. "
             "Be concrete and short.")
        msgs = [{"role": "system", "content": self.system},
                {"role": "user", "content": f"NOTES: {self.notes or '(none)'}\n{q}"}]
        try:
            text, usage, _ = chat(msgs, model=self.model, max_tokens=350, temperature=0.3)
        except LLMError as e:
            return [], f"error: {e}"
        self.usage["prompt"] += usage.get("prompt_tokens", 0)
        self.usage["completion"] += usage.get("completion_tokens", 0)
        self.usage["calls"] += 1
        lines = [l.strip().lstrip("-*0123456789. ").strip() for l in text.splitlines() if l.strip()]
        return [l for l in lines if len(l) > 8][:6], text
