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
    "friend": "Your goal: befriend the creatures instead of fighting them. Learn what each species likes (try sing, dance, charm, pose and gifts and read known_likes), hit the beat, "
              "bond three of one species, observe creatures to learn how they move, and eat carcasses when hungry.",
    "newcomer": "You have never seen this game and nobody explained its goal. Try things to learn what "
                "is going on. In every reply add a NOTE: line saying what you do not understand or "
                "what information you wish you had.",
}

SYSTEM = """You control one creature in a valley (metres; 10 ticks per second, each of your turns lasts about 2 seconds). Each turn you get a JSON observation (schema world-2) and answer with ONE command.
Commands (one per turn; the last accepted order keeps running until you give a new one):
  go X Z            walk to coordinates (routes around cliffs and water; "unreachable" if there is no way)
  heading DEG       walk in a direction (degrees: 0 = +z, 90 = +x, clockwise seen from above)
  approach #ID      walk toward creature ID
  attack #ID MOVE   attack creature ID with a move from attack_moves (its name, any case, or its index number); an unknown move gives last_error unknown_move, a move outside your loadout not_equipped, one still recharging on_cooldown
  loadout SLOT MOVE put a known move (name, or its index number; "none" empties the slot) in attack slot SLOT 1-4; only near the nest and never during a fight, listed in legal_verbs as "loadout" when allowed. Errors: not_at_nest, in_fight, not_known, unknown_move, invalid slot
  befriend #ID SKILL perform a social skill on creature ID: sing (range 8 m, likes vary by species), dance (5 m), charm (4 m), pose (10 m); you walk into range first. Skill details are in social.skills. Errors: refuses (it is hostile, aggressive and not yet calmed, or in a bad mood), staggered, no_stamina, in_fight (nobody in a fight can be befriended), unknown_skill_or_item
  gift #ID ITEM     give plant, fruit, meat or bone from social.inventory (range 2.5 m). A fitting gift (carnivores like meat and bone, herbivores plant and fruit; meat to a herbivore is an insult) raises trust, and a liked gift calms an aggressive creature for a while. Errors: no_item
  observe #ID       stand still unseen within 40 m of a creature (or its carcass): every 50 ticks a clue of that species' chain is revealed (social.observe); three clues complete the chain and teach you a move (see known_moves). You are seen if the creature is hostile, a timid one is closer than half its sight, or you move
  intimidate #ID    a display contest at up to 12 m: success makes the creature leave (no trust change, no DNA, no kill); then a cooldown
  eat #ID           eat a carcass (id with type carcass, meat > 0) within reach: a bite every 10 ticks raises your food meter; the first bite of a carcass pays DNA; any other order stops it. Errors: cannot_digest, full
  flee              run away from the nearest creature (error no_threat if none is within 30 m)
  go_nest           return to the nest (safe place)
  wait              stand still
Only verbs in legal_verbs are available. Observation fields:
  world: bound (you can walk within +-bound on x and z), units, nest {{x,z}}, tick_hz
  own: x, z, hp, stamina (and their maxima), speed, facing (unit vector)
  last_error: result of your last command ("ok" or why it was rejected); it stays until your next command
  blocked: null, or {{reason: cliff|water|edge|obstacle|creature|unreachable, x, z}} when you were stopped during the last tick
  events: what happened since your last turn: hit {{by,target,move,damage}}, kill, death, respawn, order_rejected, path_found, arrived, fled, path_failed (ids: 0 = you, 1.. = creatures); a kill, death or fled event also ends your standing order
  loadout: {{slots: your 4 attack slots in order (a move name or null), signature_slot (1-4 or null), can_edit (true at the nest outside a fight), nest_radius_m}}; guard and dodge are always available and never in a slot
  known_moves: the attack moves you may put in a slot
  attack_moves: your known attack moves, each {{index, id (same as index), name, role (basic|engage|poke|control|defence|signature), stamina_cost, range_m (reach from your centre to the target's surface), windup_ticks, active_ticks, recover_ticks, cooldown_ticks (recharge time after each use), cooldown_left (ticks until it can start again, 0 = ready), equipped (in a slot: only equipped moves can be used), slot (1-4 or null), usable (equipped, ready, enough stamina and free to act now), target_in_range (nearest valid target is within range_m, or null if none)}}; use name or index in "attack #ID MOVE"
  social: dna_total (only rises) and dna_balance, food {{meter,max,diet}}, inventory of gifts, progress {{resolved,total}} species (each species is resolved by allying 3 of its members through befriending, or dominating it by killing 3; the first to complete closes the other), species list, observe chains (revealed clues), skills, beat_ticks (12) and rhythm_window (2), action (what you are performing)
  creatures in nearby also carry: temper (timid|territorial|aggressive), diet, relationship (stranger|neutral|trusted|ally), trust 0-100 (60 bonds the creature; the bond stays even if trust fades), trust_band, mood and mood_n, beat_in (ticks until its next beat: a sing or dance whose active frame lands within 2 ticks of the beat pays x1.5), hostile, calm, refuses_social, known_likes and known_dislikes (only what you tried). Repeating the same skill on the same creature within 300 ticks pays 50% then 25%; a different skill within 20 ticks of the last stacks a combo (x1.5 then x2.0, total timing and combo capped at x2.0). Attacking a creature lowers its herd's trust and breaks its bond. Events: skill, gift, bond_made, bond_broken, species_resolved, dna, observe, chain_complete, intimidate, social_cancelled, eat
  nearby: creatures and carcasses (id, species, distance, bearing in degrees relative to your facing, positive = clockwise/right, hp, hp_max, state roam|alert|fighting|carcass|dead, in_fight, attackable = in reach of at least one of your attack moves right now), the nest, rocks and trees within 40 m
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
        if re.match(r"^(go|heading|approach|attack|loadout|flee|go_nest|wait|befriend|gift|observe|intimidate|eat)\b", line, re.I):
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
        moves = [m["name"] for m in o["attack_moves"] if m["equipped"]] or ["bite"]
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
        if p == "friend":
            tgt = min(live, key=lambda n: n["distance"], default=None)
            if tgt is None:
                return f"heading {self.rng.uniform(0, 360):.0f}", None
            skills = [k["name"] for k in o["social"]["skills"]]
            cmd = [f"befriend #{tgt['id']} {skills[self.i % len(skills)]}", f"observe #{tgt['id']}", f"gift #{tgt['id']} fruit"][self.i % 3]
            return cmd, None
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
             "loadout": lambda: f"loadout {r.choice([1, 2, 3, 4, 4, 5, 0, -1])} {r.choice(moves + ['none'])}",
             "befriend": lambda: f"befriend #{r.choice(ids)} {r.choice(['sing', 'dance', 'charm', 'pose', 'yodel', '9'])}",
             "gift": lambda: f"gift #{r.choice(ids)} {r.choice(['plant', 'fruit', 'meat', 'bone', 'rock'])}",
             "observe": lambda: f"observe #{r.choice(ids)}",
             "intimidate": lambda: f"intimidate #{r.choice(ids)}",
             "eat": lambda: f"eat #{r.choice(ids)}",
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
