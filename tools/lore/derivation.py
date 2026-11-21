#!/usr/bin/env python3
"""Check lore/worlds/<id>.derivation.json (rule: lore/rules/derivation.md).

  python3 tools/lore/derivation.py [--root DIR]

Each item may carry `check: {kind, inputs{}, expect, tol}`; the checker recomputes `kind` from `inputs` and compares it with `expect`
(relative tolerance `tol`, default 3%). A mismatch is an error, unless the item has `known_discrepancy` (then a warning, so the sheet can
expose an error in the canon without hiding it). `kind: range` checks lo <= value <= hi.
Kinds: surface_gravity_g, equilibrium_temperature_k, scale_height_km, boiling_point_c, jeans_lambda, orbital_period_days,
local_days_per_year, terminal_velocity_ratio, partial_pressure_o2_bar, moon_period_days, insolation_earth, air_density_ratio, sound_speed_ms, ratio, range.
"""
import argparse, glob, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lorelib import ROOT, load

G = 6.674e-11; M_EARTH = 5.972e24; R_EARTH = 6.371e6; M_SUN = 1.989e30; L_SUN = 3.828e26; AU = 1.496e11
SIGMA = 5.670e-8; K_B = 1.380649e-23; R_GAS = 8.314462; M_LUNA = 7.342e22; G_EARTH = 9.80665; M_H = 1.6735e-27


def _boil_c(p_bar):
    """Water boiling point from the IAPWS Wagner-Pruss saturation curve (bisection)."""
    tc, pc = 647.096, 22.064e6
    a = (-7.85951783, 1.84408259, -11.7866497, 22.6807411, -15.9618719, 1.80122502)
    def psat(t):
        th = 1 - t / tc
        return pc * math.exp(tc / t * (a[0] * th + a[1] * th ** 1.5 + a[2] * th ** 3 + a[3] * th ** 3.5 + a[4] * th ** 4 + a[5] * th ** 7.5))
    lo, hi = 300.0, 640.0
    for _ in range(100):
        mid = (lo + hi) / 2
        if psat(mid) < p_bar * 1e5: lo = mid
        else: hi = mid
    return lo - 273.15


def compute(kind, i):
    if kind == "surface_gravity_g": return (i["mass_earth"] * M_EARTH * G / (i["radius_earth"] * R_EARTH) ** 2) / G_EARTH
    if kind == "equilibrium_temperature_k": return (i["luminosity_sun"] * L_SUN * (1 - i["bond_albedo"]) / (16 * math.pi * SIGMA * (i["orbit_au"] * AU) ** 2)) ** 0.25
    if kind == "scale_height_km": return R_GAS * i["temperature_k"] / (i["mean_molar_mass_g"] / 1000 * i["gravity_g"] * G_EARTH) / 1000
    if kind == "boiling_point_c": return _boil_c(i["pressure_bar"])
    if kind == "jeans_lambda":
        r = (i["radius_earth"] * R_EARTH + i["exobase_km"] * 1000); v2 = 2 * G * i["mass_earth"] * M_EARTH / r
        return v2 * i["particle_mass_amu"] * 1.66054e-27 / (2 * K_B * i["exobase_temperature_k"])
    if kind == "orbital_period_days": return math.sqrt(i["orbit_au"] ** 3 / i["star_mass_sun"]) * 365.25
    if kind == "local_days_per_year": return i["year_earth_days"] * 24 / i["day_hours"]
    if kind == "partial_pressure_o2_bar": return i["o2_fraction"] * i["pressure_bar"]
    if kind == "moon_period_days": return 2 * math.pi * math.sqrt((i["orbit_km"] * 1000) ** 3 / (G * (i["planet_mass_earth"] * M_EARTH + i["moon_mass_luna"] * M_LUNA))) / 86400
    if kind == "insolation_earth": return i["luminosity_sun"] / i["orbit_au"] ** 2
    if kind == "air_density_ratio":  # ideal gas, relative to Earth sea level (1.013 bar, 288.15 K, 28.97 g/mol)
        return (i["pressure_bar"] / 1.01325) * (288.15 / i["temperature_k"]) * (i["mean_molar_mass_g"] / 28.97)
    if kind == "sound_speed_ms": return math.sqrt(i["gamma"] * R_GAS * i["temperature_k"] / (i["mean_molar_mass_g"] / 1000))
    if kind == "terminal_velocity_ratio": return math.sqrt(i["gravity_g"] / i["air_density_ratio"])  # v_t ~ sqrt(m g / (rho Cd A)), same body
    if kind == "ratio": return i["a"] / i["b"]
    raise ValueError("unknown check kind " + kind)


def check_sheet(sheet, fn="derivation"):
    errors, warnings = [], []
    seen = set()
    for it in sheet.get("items", []):
        iid = it.get("id", "?")
        if iid in seen: errors.append(f"{fn}: duplicate item id {iid}")
        seen.add(iid)
        if it.get("confidence") not in ("measured", "derived", "estimated", "speculative"):
            errors.append(f"{fn}: {iid}: confidence must be measured/derived/estimated/speculative")
        for dep in it.get("after", []):
            if dep not in seen: errors.append(f"{fn}: {iid}: depends on {dep}, which does not come earlier in the chain")
        if not it.get("facts") and not it.get("source") and not it.get("formula"):
            errors.append(f"{fn}: {iid}: needs facts, source or formula")
        c = it.get("check")
        if not c: continue
        try:
            if c["kind"] == "range":
                v = c["inputs"]["value"]; ok = c["inputs"]["lo"] <= v <= c["inputs"]["hi"]; got = v
            else:
                got = compute(c["kind"], c["inputs"]); exp = c["expect"]
                ok = abs(got - exp) <= c.get("tol", 0.03) * abs(exp)
        except Exception as e:
            errors.append(f"{fn}: {iid}: check failed to run: {e}"); continue
        if not ok:
            msg = f"{fn}: {iid} ({it.get('key')}): recomputed {got:.4g}, sheet says {c.get('expect', c['inputs'])}"
            (warnings if it.get("known_discrepancy") else errors).append(msg + (f" [known: {it['known_discrepancy']}]" if it.get("known_discrepancy") else ""))
    if not isinstance(sheet.get("violation"), dict) and sheet.get("violation") is not None:
        errors.append(f"{fn}: violation must be an object or null")
    return errors, warnings


def validate_derivations(root):
    errors, warnings = [], []
    for p in sorted(glob.glob(os.path.join(root, "lore", "worlds", "*.derivation.json"))):
        fn = os.path.relpath(p, root); sheet = load(p)
        wid = os.path.basename(p)[:-len(".derivation.json")]
        if sheet.get("world") != wid: errors.append(f"{fn}: world '{sheet.get('world')}' does not match the file name")
        wp = os.path.join(root, "lore", "worlds", wid + ".json")
        facts = {f["id"] for f in load(wp)["facts"]} if os.path.exists(wp) else set()
        if not facts: errors.append(f"{fn}: no world file for '{wid}'")
        for it in sheet.get("items", []):
            for f in it.get("facts", []):
                if f not in facts: errors.append(f"{fn}: {it.get('id')}: fact {f} does not exist in world {wid}")
        e, w = check_sheet(sheet, fn); errors += e; warnings += w
    return errors, warnings


def main():
    ap = argparse.ArgumentParser(description=__doc__); ap.add_argument("--root", default=ROOT); a = ap.parse_args()
    e, w = validate_derivations(a.root)
    for x in w: print("warning:", x)
    for x in e: print("error:", x)
    print(f"lore derivation: {len(e)} error(s), {len(w)} warning(s)")
    return 1 if e else 0


if __name__ == "__main__":
    sys.exit(main())
