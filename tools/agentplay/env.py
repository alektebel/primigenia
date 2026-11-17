"""Episode wrapper around StageWorld: verb turns, invariant checks, replay determinism."""
from __future__ import annotations

import ctypes
import math
import os
import re
import sys
import traceback

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "bindings", "python"))
from cpore.world import StageWorld  # noqa: E402

BOUND = 330.0            # terrain spans +-320 (stage_world.c terrain sampling)
MAX_STEP = 3.0           # max plausible displacement per 10 Hz tick
KNOWN_VERBS = {"go", "heading", "flee", "go_nest", "wait", "approach", "attack"}
MOVE_VERBS = {"go", "heading", "flee", "go_nest", "approach"}
TOP_KEYS = ["schema", "tick", "clock", "own", "last_error", "nearby", "legal_verbs", "attack_moves", "summary"]
OWN_KEYS = ["id", "x", "z", "hp", "stamina", "hp_max", "stamina_max", "speed", "facing"]
NEAR_TYPES = {"creature", "carcass", "nest", "rock", "tree"}
KNOWN_ERRORS = {"ok", "invalid command or value", "invalid or unavailable target",
                "invalid or unavailable attack move"}
ERR_TEXT = {0: "ok", -1: "invalid command or value", -2: "invalid or unavailable target",
            -3: "invalid or unavailable attack move"}


def clone_world(w: StageWorld) -> StageWorld:
    c = object.__new__(StageWorld)
    c._lib = w._lib
    c._blob = (ctypes.c_byte * len(w._blob)).from_buffer_copy(bytes(w._blob))
    c._world = ctypes.cast(c._blob, ctypes.c_void_p)
    c._setup = w._setup
    c._seed = w._seed
    return c


def parse_verb(cmd: str) -> str:
    return cmd.split()[0] if cmd and cmd.split() else ""


class Episode:
    def __init__(self, seed: int, ticks_per_turn: int = 20):
        self.seed = seed
        self.tpt = ticks_per_turn
        self.w = StageWorld(seed=seed)
        self.ops: list[str | None] = []        # per-turn command (None = continue)
        self.tick_hashes: list[int] = []
        self.bugs: list[dict] = []
        self.turn = 0
        self.obs = self._observe("reset")
        self.nest = (float(self.w._setup.nest_x), float(self.w._setup.nest_z))
        self.order: tuple[str, str] | None = None
        self.deaths = 0
        self.wins: set[int] = set()
        self.cells: set[tuple[int, int]] = {self._cell(self.obs)}
        self.dist_travelled = 0.0
        self.still_turns = 0
        self.nest_visits = 0
        self.verb_stats: dict[str, dict] = {}
        self.seen_iface: set[str] = set()
        self.max_hp_dropped = 0.0

    # ---- bug recording -------------------------------------------------
    def bug(self, kind: str, detail: str, **ctx):
        key = (kind, detail[:60])
        if any((b["kind"], b["detail"][:60]) == key for b in self.bugs):
            return
        self.bugs.append({"kind": kind, "detail": detail, "turn": self.turn,
                          "tick": self.obs.get("tick") if isinstance(self.obs, dict) else None,
                          "seed": self.seed, "ticks_per_turn": self.tpt,
                          "repro": [[i, c] for i, c in enumerate(self.ops) if c is not None], **ctx})

    def _observe(self, where: str):
        try:
            return self.w.observe()
        except Exception as e:  # noqa: BLE001
            self.obs = getattr(self, "obs", {})
            self.bug("observe_exception", f"{type(e).__name__}: {e} ({where})")
            return getattr(self, "obs", {})

    @staticmethod
    def _cell(o):
        return (int(o["own"]["x"] // 20), int(o["own"]["z"] // 20))

    # ---- invariants ----------------------------------------------------
    def check_tick(self, p: dict, o: dict):
        def walk(v, path):
            if isinstance(v, float) and not math.isfinite(v):
                self.bug("nan_inf", f"non-finite value at {path}")
            elif isinstance(v, dict):
                for k, x in v.items():
                    walk(x, f"{path}.{k}")
            elif isinstance(v, list):
                for i, x in enumerate(v):
                    walk(x, f"{path}[{i}]")
        walk(o, "obs")
        if o.get("schema") != "world-1" or list(o.keys()) != TOP_KEYS:
            self.bug("schema_drift", f"top-level keys {list(o.keys())}")
        own = o["own"]
        if list(own.keys()) != OWN_KEYS:
            self.bug("schema_drift", f"own keys {list(own.keys())}")
        if o["tick"] != p["tick"] + 1:
            self.bug("tick_skew", f"tick {p['tick']} -> {o['tick']}")
        for k, mx in (("hp", "hp_max"), ("stamina", "stamina_max")):
            if own[k] < -1e-3 or own[k] > own[mx] + 1e-3:
                self.bug("range", f"{k}={own[k]} outside [0,{own[mx]}]")
        if abs(own["x"]) > BOUND or abs(own["z"]) > BOUND:
            self.bug("out_of_bounds", f"position ({own['x']:.1f},{own['z']:.1f}) beyond +-{BOUND}")
        fl = math.hypot(*own["facing"])
        if abs(fl - 1) > 0.02 and fl != 0:
            self.bug("range", f"facing length {fl:.3f}")
        step = math.hypot(own["x"] - p["own"]["x"], own["z"] - p["own"]["z"])
        at_nest = math.hypot(own["x"] - self.nest[0], own["z"] - self.nest[1]) < 0.05
        respawn = p["own"]["hp"] <= 0 and own["hp"] > 0 and at_nest
        if step > MAX_STEP and not respawn:
            self.bug("teleport", f"moved {step:.2f} in one tick without respawn")
        if p["own"]["hp"] <= 0 and own["hp"] <= 0 and step > 0.01:
            self.bug("dead_acting", f"creature at hp 0 moved {step:.3f}")
        if p["own"]["hp"] <= 0 < own["hp"]:
            pass
        if own["hp"] <= 0 < p["own"]["hp"]:
            self.deaths += 1
        for v in o["legal_verbs"]:
            if v not in KNOWN_VERBS:
                self.bug("schema_drift", f"unknown legal verb {v}")
        ids = [n["id"] for n in o["nearby"]]
        if len(ids) != len(set(ids)):
            self.bug("schema_drift", "duplicate ids in nearby")
        for n in o["nearby"]:
            if n["type"] not in NEAR_TYPES or n["distance"] < 0 or abs(n["bearing"]) > 180.01:
                self.bug("schema_drift", f"bad nearby entry {n}")
            if n["type"] == "carcass" and n["id"] not in self.wins:
                self.wins.add(n["id"])
        if o["last_error"] not in KNOWN_ERRORS:
            self.bug("schema_drift", f"unknown last_error {o['last_error']!r}")

    def probe_legal(self):
        """On a clone: every advertised verb must be accepted; unadvertised target verbs must not."""
        o = self.obs
        legal = set(o["legal_verbs"])
        n_wild = 24
        moves = [m["name"] for m in o["attack_moves"]]
        try:
            for v in KNOWN_VERBS:
                ok = False
                if v == "go":
                    ok = clone_world(self.w).command("go 1 1") == 0
                elif v == "heading":
                    ok = clone_world(self.w).command("heading 45") == 0
                elif v in ("flee", "go_nest", "wait"):
                    ok = clone_world(self.w).command(v) == 0
                elif v == "approach":
                    ok = any(clone_world(self.w).command(f"approach #{i}") == 0 for i in range(1, n_wild + 1))
                elif v == "attack":
                    ok = any(clone_world(self.w).command(f"attack #{i} {m}") == 0
                             for i in range(1, n_wild + 1) for m in (moves or ["bite"]))
                if v in legal and not ok:
                    self.bug("legal_verb_errors", f"'{v}' is listed in legal_verbs but every probe is rejected")
                if v not in legal and ok:
                    self.bug("illegal_verb_accepted", f"'{v}' is not in legal_verbs but was accepted")
        except Exception as e:  # noqa: BLE001
            self.bug("binding_exception", f"probe: {type(e).__name__}: {e}")

    # ---- one agent turn ------------------------------------------------
    def play_turn(self, cmd: str | None) -> dict:
        """Issue cmd (or continue) then run tpt ticks. Returns a result dict for the agent."""
        self.turn += 1
        code = 0
        verb = parse_verb(cmd) if cmd else ""
        pre = self.obs
        try:
            if cmd is not None:
                code = self.w.command(cmd)
                if code == 0:
                    self.order = (verb, cmd)
            self.ops.append(cmd)
            for i in range(self.tpt):
                p = self.obs
                self.tick_hashes.append(self.w.step(None))
                o = self._observe("tick")
                self.obs = o
                if o and p:
                    self.check_tick(p, o)
        except Exception as e:  # noqa: BLE001
            self.ops_exc = True
            self.bug("binding_exception", f"{type(e).__name__}: {e}", trace=traceback.format_exc()[-400:])
            code = -9
        o = self.obs
        err = ERR_TEXT.get(code, "exception")
        if cmd is not None:
            vs = self.verb_stats.setdefault(verb or "?", {"n": 0, "err": 0})
            vs["n"] += 1
            vs["err"] += code != 0
            if code != 0 and o.get("last_error") == "ok":
                self.bug("last_error_blind", "string-API rejection is invisible in observe().last_error "
                         f"(command {cmd!r} -> code {code} but obs last_error 'ok')", cmd=cmd)
        # movement bookkeeping
        d = math.hypot(o["own"]["x"] - pre["own"]["x"], o["own"]["z"] - pre["own"]["z"])
        self.dist_travelled += d
        self.cells.add(self._cell(o))
        if any(n["type"] == "nest" and n["distance"] < 2 for n in o["nearby"]):
            self.nest_visits += 1
        self.check_effect(pre, o, cmd, code, d)
        self.probe_legal()
        return {"cmd": cmd, "error": err, "moved": round(d, 2)}

    def check_effect(self, pre, o, cmd, code, d):
        near_c = min([n["distance"] for n in o["nearby"] if n["type"] == "creature"] + [999])
        fight_zone = near_c < 7 or o["own"]["hp"] < pre["own"]["hp"] or pre["own"]["hp"] <= 0
        if not self.order or fight_zone:
            self.still_turns = 0
            return
        v, c = self.order
        nest_d = math.hypot(o["own"]["x"] - self.nest[0], o["own"]["z"] - self.nest[1])
        pending = True
        if v == "go_nest" and nest_d < 1.5:
            pending = False
        if v == "go":
            m = re.match(r"go\s+(-?[\d.]+)[ ,]+(-?[\d.]+)", c)
            if m and math.hypot(float(m[1]) - o["own"]["x"], float(m[2]) - o["own"]["z"]) < 1.5:
                pending = False
        if v in ("wait", "attack", "approach"):
            pending = False
        if not pending or v not in MOVE_VERBS:
            self.still_turns = 0
            return
        if d < 0.05 and v == "flee":
            self.bug("silent_noop", "'flee' with no threat is accepted ('ok') but does nothing", cmd=c)
            return
        if d < 0.05:
            self.still_turns += 1
            obst = [n for n in o["nearby"] if n["type"] in ("rock", "tree") and n["distance"] < 4]
            if self.still_turns == 1 and cmd == self.order[1]:
                self.bug("no_effect", f"'{c.split()[0]}' accepted but no movement in a full turn",
                         cmd=c, near_obstacles=len(obst))
            if self.still_turns >= 3:
                self.bug("stuck", f"no movement for {self.still_turns * self.tpt} ticks under '{c.split()[0]}' "
                         f"(obstacles within 4: {len(obst)})", cmd=c, near_obstacles=len(obst))
        else:
            self.still_turns = 0

    # ---- determinism ---------------------------------------------------
    def replay_check(self) -> dict:
        try:
            w2 = StageWorld(seed=self.seed)
            hashes = []
            for cmd in self.ops:
                if cmd is not None:
                    w2.command(cmd)
                for _ in range(self.tpt):
                    hashes.append(w2.step(None))
            n = min(len(hashes), len(self.tick_hashes))
            for i in range(n):
                if hashes[i] != self.tick_hashes[i]:
                    self.bug("nondeterminism", f"replay hash diverges at tick {i + 1}")
                    return {"ok": False, "diverge": i + 1, "ticks": n}
            if len(hashes) != len(self.tick_hashes):
                self.bug("nondeterminism", "replay length mismatch")
                return {"ok": False, "ticks": n}
            return {"ok": True, "ticks": n, "final": f"{self.tick_hashes[-1]:016x}" if n else None}
        except Exception as e:  # noqa: BLE001
            self.bug("binding_exception", f"replay: {type(e).__name__}: {e}")
            return {"ok": False, "error": str(e)}
