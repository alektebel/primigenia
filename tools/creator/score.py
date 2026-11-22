#!/usr/bin/env python3
"""Creator-editor scorecard (docs/briefs/creator-score.md): judges a creator_replay capture directory against
docs/evidence/godot/creator-score/reference.json (hand-annotated from the owner's reference video; never committed frames).
Usage: score.py <label dir> [reference.json]      (Python 3 stdlib + Pillow; no numpy)

Input  <dir>/replay.json            moments (camera pitch, probe, scene flags), actions, events, frame times
       <dir>/<moment>.jpg           what the player sees, 1280x720
       <dir>/<moment>_mask.png      creature on a flat magenta key, scenery + UI hidden (bounding box)
       <dir>/<moment>_ui.png        UI only on the same key (UI coverage)
       <dir>/gates.json             optional, tools/creator/gates.sh: studio / ui / first_quest = pass|fail|skip
Output <dir>/summary.json, summary.md, contact.jpg (ours); contact_with_ref.jpg when the local reference frames exist (git-ignored).

Metrics per moment (ours measured exactly where the reference was annotated by hand, see reference.json "measurement_notes"):
  height_frac   mask bounding-box height / viewport height (the mask is eroded 5 px so thin 3D handle lines do not count)
  cx, cy        bounding-box centre / viewport size
  ui_coverage   fraction of the UI-only pass that is not the key colour (panels, text, hint line, drag ghost)
  elev_deg      camera pitch above the horizon, from the editor's own camera (exact, the reference value is estimated)
  clutter       grass or rocks drawn in the scene (the reference stage has nothing between camera and creature)
  spheres/ring  Studio.creator_probe() when the editor has it (vertebra spheres, part ring); 0/false before the creator-flow work
Timing and events come from Studio.creator_event. An event the editor never emits is ABSENT and fails; it never crashes the run.
"""
import json, os, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "docs", "evidence", "godot", "creator-score")
REF_DEFAULT = os.path.join(ROOT, "reference.json")
MOMENTS = ["start", "spine_hover", "part_picked", "part_dropped", "spine_drag", "part_rotate", "final"]
REQUIRED_EVENTS = ["part_placed", "puff_spawned", "cost_popup_shown", "cost_popup_hidden", "head_target_changed", "handle_shown"]
GOOD_HANDLE_KINDS = ("vertebra_sphere", "part_ring")


def key_mask(im):
    """255 where the pixel is the magenta key."""
    r, g, b = im.convert("RGB").split()
    return ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 235 else 0), g.point(lambda v: 255 if v < 22 else 0)),
                               b.point(lambda v: 255 if v > 235 else 0))


def creature_bbox(path):
    im = Image.open(path)
    body = ImageChops.invert(key_mask(im)).filter(ImageFilter.MinFilter(5))
    bb = body.getbbox()
    return im.size, bb


def ui_cov(path):
    im = Image.open(path)
    ui = ImageChops.invert(key_mask(im))
    return sum(1 for v in ui.resize((im.size[0] // 4, im.size[1] // 4), Image.BOX).getdata() if v > 64) / float((im.size[0] // 4) * (im.size[1] // 4))


def check(cid, group, value, target, ok, note=""):
    return {"id": cid, "group": group, "value": value, "target": target, "pass": bool(ok), "note": note}


def first(events, name, after=-1.0, pred=None):
    for e in events:
        if e["name"] == name and e["t"] >= after and (pred is None or pred(e)):
            return e
    return None


def timing_checks(rep, ref):
    ev = rep["events"]
    T = ref["timing"]
    out = []
    placed = first(ev, "part_placed")
    t0 = placed["t"] if placed else None
    puff = first(ev, "puff_spawned", t0 if t0 is not None else 0.0)
    shown = first(ev, "cost_popup_shown", t0 if t0 is not None else 0.0)
    hid = first(ev, "cost_popup_hidden", shown["t"] if shown else 0.0)
    head = first(ev, "head_target_changed", t0 if t0 is not None else 0.0)
    good = first(ev, "handle_shown", pred=lambda e: e["data"].get("kind") in GOOD_HANDLE_KINDS)
    d = lambda a, b: None if (a is None or b is None) else round(a["t"] - b["t"], 3)
    v = d(puff, placed)
    out.append(check("drop_to_puff_s", "timing", v, T["drop_to_puff_s"]["value"], v is not None and abs(v) <= T["drop_to_puff_s"]["tol"], "absent" if v is None else ""))
    v = d(shown, placed)
    t = T["cost_popup_delay_s"]
    out.append(check("cost_popup_delay_s", "timing", v, t["value"], v is not None and abs(v - t["value"]) <= t["tol"], "absent" if v is None else ""))
    v = d(hid, shown)
    t = T["cost_popup_life_s"]
    out.append(check("cost_popup_life_s", "timing", v, t["value"], v is not None and t["lo"] <= v <= t["hi"], "absent" if v is None else ""))
    v = d(head, placed)
    t = T["head_react_delay_s"]
    out.append(check("head_react_delay_s", "timing", v, t["value"], v is not None and abs(v - t["value"]) <= t["tol"], "absent" if v is None else ""))
    fade = None if good is None else good["data"].get("fade_ms")
    fade = None if fade is None else round(fade / 1000.0, 3)
    t = T["handle_fade_in_s"]
    note = "absent: no vertebra_sphere / part_ring handle event" if good is None else ("absent: handle event has no fade_ms" if fade is None else "")
    out.append(check("handle_fade_in_s", "timing", fade, t["value"], fade is not None and fade <= t["max"], note))
    return out


def moment_checks(name, m, rep, ref, d):
    R = ref["moments"][ref["ours_to_ref"][name]]
    tol = ref["tolerances"]
    out = []
    size, bb = creature_bbox(os.path.join(d, name + "_mask.png"))
    if bb is None:
        h = cx = cy = None
    else:
        h = round((bb[3] - bb[1] + 4) / size[1], 3)
        cx = round((bb[0] + bb[2]) / 2 / size[0], 3)
        cy = round((bb[1] + bb[3]) / 2 / size[1], 3)
    g = "framing"
    t = tol["height_frac"]
    out.append(check(name + ".height_frac", g, h, R["height_frac"], h is not None and h >= t["floor"] and abs(h - R["height_frac"]) <= t["tol"]))
    t = tol["cx"]
    out.append(check(name + ".cx", g, cx, R["cx"], cx is not None and abs(cx - R["cx"]) <= t["tol"]))
    t = tol["cy"]
    out.append(check(name + ".cy", g, cy, R["cy"], cy is not None and abs(cy - R["cy"]) <= t["tol"]))
    u = round(ui_cov(os.path.join(d, name + "_ui.png")), 3)
    out.append(check(name + ".ui_coverage", "hud", u, "<=%s (ref %s)" % (tol["ui_coverage"]["max"], R["ui_coverage"]), u <= tol["ui_coverage"]["max"]))
    el = m["pitch_deg"]
    out.append(check(name + ".elev_deg", "camera", el, R["camera_elev_deg"], abs(el - R["camera_elev_deg"]) <= tol["camera_elev_deg"]["tol"]))
    cl = bool(m.get("grass_visible") or m.get("rocks_visible"))
    out.append(check(name + ".clutter", "stage", cl, False, not cl, "grass/rocks between camera and creature" if cl else ""))
    pr = m.get("probe", {})
    if name in ("spine_hover", "spine_drag"):
        s = pr.get("vertebra_spheres", 0)
        need = 3 if name == "spine_hover" else 2
        out.append(check(name + ".spheres", "handles", s, ">=%d (ref %d)" % (need, R["vertebra_spheres"]), s >= need, "" if rep.get("has_probe") else "no creator_probe: spine arrows only"))
    if name == "part_rotate":
        out.append(check(name + ".part_ring", "handles", bool(pr.get("part_ring", False)), True, bool(pr.get("part_ring", False)), "" if rep.get("has_probe") else "no creator_probe: rotation bead only"))
    return out


def contact(d, ref, out, with_ref):
    cw = 320
    cols = []
    rf = os.path.join(ROOT, "ref_frames")
    for n in MOMENTS:
        im = Image.open(os.path.join(d, n + ".jpg")).convert("RGB").resize((cw, 180))
        col = Image.new("RGB", (cw, 180 + 16 + ((318 + 16) if with_ref else 0)), (20, 20, 20))
        col.paste(im, (0, 16))
        ImageDraw.Draw(col).text((4, 2), n, fill=(255, 255, 0))
        if with_ref:
            rp = os.path.join(rf, ref["ours_to_ref"][n] + ".png")
            col.paste(Image.open(rp).convert("RGB").resize((cw, 318)), (0, 180 + 32))
            ImageDraw.Draw(col).text((4, 180 + 18), "reference " + ref["ours_to_ref"][n], fill=(0, 255, 255))
        cols.append(col)
    W = Image.new("RGB", (cw * len(cols), cols[0].size[1]))
    for i, c in enumerate(cols):
        W.paste(c, (i * cw, 0))
    W.save(out, quality=88)


def main():
    d = sys.argv[1]
    ref = json.load(open(sys.argv[2] if len(sys.argv) > 2 else REF_DEFAULT))
    rep = json.load(open(os.path.join(d, "replay.json")))
    checks = []
    for n in MOMENTS:
        checks += moment_checks(n, rep["moments"][n], rep, ref, d)
    checks += timing_checks(rep, ref)
    seen = {e["name"] for e in rep["events"]}
    good = first(rep["events"], "handle_shown", pred=lambda e: e["data"].get("kind") in GOOD_HANDLE_KINDS)
    absent = [e for e in REQUIRED_EVENTS if e not in seen or (e == "handle_shown" and good is None)]
    for e in REQUIRED_EVENTS:
        checks.append(check("event." + e, "events", e not in absent, True, e not in absent, "absent" if e in absent else ""))
    gates = json.load(open(os.path.join(d, "gates.json"))) if os.path.exists(os.path.join(d, "gates.json")) else {}
    for k in ("studio", "ui", "first_quest"):
        st = gates.get(k, "unknown")
        checks.append(check("gate." + k, "gates", st, "pass", st == "pass", "gate, not part of the score" ))
    scored = [c for c in checks if c["group"] != "gates"]
    groups = {}
    for c in scored:
        g = groups.setdefault(c["group"], [0, 0])
        g[0] += c["pass"]
        g[1] += 1
    passed = sum(c["pass"] for c in scored)
    summary = {"label": os.path.basename(os.path.abspath(d)), "passed": passed, "total": len(scored), "score": round(passed / len(scored), 3),
               "groups": {k: "%d/%d" % tuple(v) for k, v in groups.items()}, "absent_events": absent, "gates": {k: gates.get(k, "unknown") for k in ("studio", "ui", "first_quest")},
               "frame_ms_median": rep["frame_ms_median"], "frame_ms_p95": rep["frame_ms_p95"], "has_probe": rep.get("has_probe", False), "checks": checks}
    json.dump(summary, open(os.path.join(d, "summary.json"), "w"), indent=1)
    L = ["# creator score %s: %d/%d (%.0f%%)" % (summary["label"], passed, len(scored), 100 * summary["score"]), "",
         "groups: " + ", ".join("%s %s" % kv for kv in summary["groups"].items()),
         "absent events: " + (", ".join(absent) or "none"), "gates: " + ", ".join("%s %s" % kv for kv in summary["gates"].items()),
         "frame ms (software GL, whole replay incl. capture passes): median %s, p95 %s" % (rep["frame_ms_median"], rep["frame_ms_p95"]), "",
         "| check | group | value | target | pass | note |", "|---|---|---|---|---|---|"]
    for c in checks:
        L.append("| %s | %s | %s | %s | %s | %s |" % (c["id"], c["group"], c["value"], c["target"], "yes" if c["pass"] else "NO", c["note"]))
    open(os.path.join(d, "summary.md"), "w").write("\n".join(L) + "\n")
    contact(d, ref, os.path.join(d, "contact.jpg"), False)
    if os.path.isdir(os.path.join(ROOT, "ref_frames")):
        contact(d, ref, os.path.join(d, "contact_with_ref.jpg"), True)
    print("\n".join(L[:7]))


main()
