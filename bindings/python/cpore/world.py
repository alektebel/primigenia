"""ctypes binding for the P4 creature world (CpStageWorld / cp_stage_*)."""

from __future__ import annotations

import ctypes
import json
import os
from ctypes import (c_byte, c_float, c_int16, c_int32, c_size_t, c_uint8,
                    c_uint16, c_uint32, c_uint64, c_char_p, c_void_p)

from .env import lib as _core_lib

# Layout sizes from the native headers (64-bit LP64).
_WORLD_BYTES = 22328
_SETUP_BYTES = 17604

CP_STAGE_CONTINUE = 0
CP_STAGE_WAIT = 1
CP_STAGE_GO = 2
CP_STAGE_HEADING = 3
CP_STAGE_APPROACH = 4
CP_STAGE_ATTACK = 5
CP_STAGE_FLEE = 6
CP_STAGE_GO_NEST = 7
CP_STAGE_GUARD = 8
CP_STAGE_DODGE = 9

CP_STAGE_MAX_WILD = 24
CP_STAGE_MAX_OBSTACLES = 1024

_STAGE_BOUND = False


class CpCombatProfile(ctypes.Structure):
    _fields_ = [
        ("mouth", c_uint8),
        ("charge", c_uint8),
        ("spit", c_uint8),
        ("tail", c_uint8),
        ("guard", c_uint8),
        ("_pad", c_uint8 * 3),
        ("hp", c_float),
        ("stamina", c_float),
        ("speed", c_float),
        ("radius_cm", c_uint16),
        ("_pad2", c_uint16),
    ]


class CpStageSpawn(ctypes.Structure):
    _fields_ = [
        ("x", c_float),
        ("z", c_float),
        ("home_x", c_float),
        ("home_z", c_float),
        ("species", c_int32),
        ("bot", c_int32),
        ("profile", CpCombatProfile),
    ]


class CpStageObstacle(ctypes.Structure):
    _fields_ = [
        ("x", c_float),
        ("z", c_float),
        ("r", c_float),
        ("type", c_int32),
    ]


class CpStageSetup(ctypes.Structure):
    _fields_ = [
        ("seed", c_uint32),
        ("terrain_seed", c_uint32),
        ("terrain", c_int32),
        ("n", c_int32),
        ("n_obstacles", c_int32),
        ("nest_x", c_float),
        ("nest_z", c_float),
        ("flat_height", c_float),
        ("water_x", c_float),
        ("water_z", c_float),
        ("water_radius", c_float),
        ("player", CpCombatProfile),
        ("wild", CpStageSpawn * CP_STAGE_MAX_WILD),
        ("obstacles", CpStageObstacle * CP_STAGE_MAX_OBSTACLES),
    ]


class CpStageInput(ctypes.Structure):
    _fields_ = [
        ("verb", c_int32),
        ("target", c_int32),
        ("move", c_int32),
        ("dir", c_int32),
        ("sprint", c_int32),
        ("hx", c_int16),
        ("hz", c_int16),
        ("x", c_float),
        ("z", c_float),
    ]


class CpStageLogEntry(ctypes.Structure):
    _fields_ = [
        ("tick", c_uint32),
        ("input", CpStageInput),
    ]


assert ctypes.sizeof(CpStageSetup) == _SETUP_BYTES
assert ctypes.sizeof(CpStageInput) == 32
assert ctypes.sizeof(CpStageLogEntry) == 36


def _bind_stage(lib):
    global _STAGE_BOUND
    if _STAGE_BOUND:
        return lib
    lib.cp_stage_setup_default.argtypes = [ctypes.POINTER(CpStageSetup), c_uint32]
    lib.cp_stage_reset.argtypes = [c_void_p, ctypes.POINTER(CpStageSetup)]
    lib.cp_stage_reset.restype = c_int32
    lib.cp_stage_command.argtypes = [c_void_p, c_char_p]
    lib.cp_stage_command.restype = c_int32
    lib.cp_stage_order.argtypes = [c_void_p, ctypes.POINTER(CpStageInput)]
    lib.cp_stage_order.restype = c_int32
    lib.cp_stage_step.argtypes = [c_void_p, ctypes.POINTER(CpStageInput)]
    lib.cp_stage_step.restype = c_uint64
    lib.cp_stage_hash.argtypes = [c_void_p]
    lib.cp_stage_hash.restype = c_uint64
    lib.cp_stage_observe.argtypes = [c_void_p, c_char_p, c_size_t]
    lib.cp_stage_observe.restype = c_int32
    lib.cp_stage_order_error.argtypes = [c_int32]
    lib.cp_stage_order_error.restype = c_char_p
    lib.cp_stage_replay.argtypes = [
        ctypes.POINTER(CpStageSetup),
        ctypes.POINTER(CpStageLogEntry),
        c_int32,
        c_uint32,
        ctypes.POINTER(c_uint64),
    ]
    lib.cp_stage_replay.restype = c_uint64
    _STAGE_BOUND = True
    return lib


def _world_ptr(blob):
    return ctypes.cast(blob, c_void_p)


def input_from_mapping(action: dict) -> CpStageInput:
    """Build a CpStageInput from a plain dict (verb may be a name or int)."""
    verb = action.get("verb", CP_STAGE_CONTINUE)
    if isinstance(verb, str):
        verb = {
            "continue": CP_STAGE_CONTINUE,
            "wait": CP_STAGE_WAIT,
            "go": CP_STAGE_GO,
            "heading": CP_STAGE_HEADING,
            "approach": CP_STAGE_APPROACH,
            "attack": CP_STAGE_ATTACK,
            "flee": CP_STAGE_FLEE,
            "go_nest": CP_STAGE_GO_NEST,
            "guard": CP_STAGE_GUARD,
            "dodge": CP_STAGE_DODGE,
        }[verb]
    return CpStageInput(
        int(verb),
        int(action.get("target", 0)),
        int(action.get("move", 0)),
        int(action.get("dir", 0)),
        int(1 if action.get("sprint") else 0),
        int(action.get("hx", 0)),
        int(action.get("hz", 0)),
        float(action.get("x", 0.0)),
        float(action.get("z", 0.0)),
    )


def _parse_profile(tokens, idx):
    if idx + 9 > len(tokens):
        raise ValueError("truncated combat profile")
    mouth, charge, spit, tail, guard = (int(tokens[idx + i]) for i in range(5))
    hp, stamina, speed = (_num(tokens[idx + 5]),
                          _num(tokens[idx + 6]),
                          _num(tokens[idx + 7]))
    radius = int(tokens[idx + 8])
    prof = CpCombatProfile(
        mouth, charge, spit, tail, guard,
        (c_uint8 * 3)(),
        c_float(hp), c_float(stamina), c_float(speed),
        c_uint16(radius), c_uint16(0),
    )
    return prof, idx + 9


def _num(s: str) -> float:
    return float(s) if "." in s or "e" in s.lower() else float(int(s))


def parse_world_log(path: str) -> tuple[CpStageSetup, list[CpStageLogEntry], int]:
    """Parse a CPORE_WORLD_LOG file (same format as build/world_cli --replay)."""
    with open(path, encoding="utf-8") as f:
        head = f.readline().split()
        if len(head) != 2 or head[0] != "CPORE_WORLD_LOG" or int(head[1]) != 2:
            raise ValueError("not a world-1 replay log")
        tok = []
        for line in f:
            tok.extend(line.split())
        if len(tok) < 11:
            raise ValueError("truncated setup")

    off = 0
    setup = CpStageSetup()
    setup.seed = c_uint32(int(tok[0]))
    setup.terrain_seed = c_uint32(int(tok[1]))
    setup.terrain = c_int32(int(tok[2]))
    setup.nest_x = c_float(_num(tok[3]))
    setup.nest_z = c_float(_num(tok[4]))
    setup.flat_height = c_float(_num(tok[5]))
    setup.water_x = c_float(_num(tok[6]))
    setup.water_z = c_float(_num(tok[7]))
    setup.water_radius = c_float(_num(tok[8]))
    setup.n = c_int32(int(tok[9]))
    setup.n_obstacles = c_int32(int(tok[10]))
    off = 11
    setup.player, off = _parse_profile(tok, off)
    for i in range(setup.n):
        setup.wild[i].x = c_float(_num(tok[off]))
        setup.wild[i].z = c_float(_num(tok[off + 1]))
        setup.wild[i].home_x = c_float(_num(tok[off + 2]))
        setup.wild[i].home_z = c_float(_num(tok[off + 3]))
        setup.wild[i].species = c_int32(int(tok[off + 4]))
        setup.wild[i].bot = c_int32(int(tok[off + 5]))
        setup.wild[i].profile, off = _parse_profile(tok, off + 6)
    for i in range(setup.n_obstacles):
        setup.obstacles[i].x = c_float(_num(tok[off]))
        setup.obstacles[i].z = c_float(_num(tok[off + 1]))
        setup.obstacles[i].r = c_float(_num(tok[off + 2]))
        setup.obstacles[i].type = c_int32(int(tok[off + 3]))
        off += 4
    ticks = int(tok[off])
    off += 1
    entries = []
    for _ in range(ticks):
        if off + 9 > len(tok):
            raise ValueError("truncated tick log")
        verb, target, move, direction, sprint, hx, hz, x, z = tok[off:off + 9]
        entries.append(CpStageLogEntry(
            c_uint32(_),
            CpStageInput(int(verb), int(target), int(move), int(direction),
                         int(sprint), c_int16(int(hx)), c_int16(int(hz)),
                         c_float(float(x)), c_float(float(z))),
        ))
        off += 9
    if off != len(tok):
        raise ValueError("trailing data in replay log")
    return setup, entries, ticks


class StageWorld:
    """Single P4 world episode via cp_stage_* in libcpore.so."""

    def __init__(self, seed: int = 42, lib_path: str | None = None):
        self._lib = _bind_stage(_core_lib() if lib_path is None else
                                __import__(".env", fromlist=["_load"])._load(lib_path))
        self._blob = (c_byte * _WORLD_BYTES)()
        self._world = _world_ptr(self._blob)
        self._setup = CpStageSetup()
        self._seed = int(seed) & 0xFFFFFFFF
        self.reset(self._seed)

    def reset(self, seed: int | None = None) -> dict:
        if seed is not None:
            self._seed = int(seed) & 0xFFFFFFFF
        self._lib.cp_stage_setup_default(ctypes.byref(self._setup), c_uint32(self._seed))
        if self._lib.cp_stage_reset(self._world, ctypes.byref(self._setup)) != 0:
            raise RuntimeError("cp_stage_reset failed")
        return self.observe()

    def command(self, text: str) -> int:
        return int(self._lib.cp_stage_command(self._world, text.encode()))

    def step(self, action: str | dict | CpStageInput | None = None) -> int:
        """Advance one 10 Hz tick; *action* may be a verb string or input struct."""
        if isinstance(action, str):
            code = self.command(action)
            if code < 0:
                raise ValueError(self.order_error(code))
            h = self._lib.cp_stage_step(self._world, None)
        elif action is None:
            h = self._lib.cp_stage_step(self._world, None)
        elif isinstance(action, dict):
            inp = input_from_mapping(action)
            h = self._lib.cp_stage_step(self._world, ctypes.byref(inp))
        elif isinstance(action, CpStageInput):
            h = self._lib.cp_stage_step(self._world, ctypes.byref(action))
        else:
            raise TypeError("action must be a verb string, dict, CpStageInput, or None")
        return int(h)

    def hash(self) -> int:
        return int(self._lib.cp_stage_hash(self._world))

    def observe(self, bufsize: int = 65536) -> dict:
        buf = ctypes.create_string_buffer(bufsize)
        n = int(self._lib.cp_stage_observe(self._world, buf, bufsize))
        if n < 0:
            raise RuntimeError("cp_stage_observe buffer too small")
        return json.loads(buf.value[:n].decode())

    @staticmethod
    def order_error(code: int) -> str:
        return _bind_stage(_core_lib()).cp_stage_order_error(int(code)).decode()

    def replay_log(self, path: str, *, tick_limit: int | None = None) -> tuple[list[int], int]:
        """Replay a log file and return per-tick hashes and the final hash."""
        setup, entries, ticks = parse_world_log(path)
        if tick_limit is not None:
            ticks = min(ticks, int(tick_limit))
            entries = entries[:ticks]
        log_arr = (CpStageLogEntry * len(entries))(*entries) if entries else None
        hashes = (c_uint64 * ticks)()
        final = int(self._lib.cp_stage_replay(
            ctypes.byref(setup),
            log_arr,
            len(entries),
            c_uint32(ticks),
            hashes,
        ))
        if final == 0:
            raise RuntimeError("cp_stage_replay failed")
        return [int(hashes[i]) for i in range(ticks)], final


def default_lib_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "..", "..", "build", "libcpore.so"))