#!/usr/bin/env python3
"""Generate docs/lore/primigenia-food-web.md, the food-web diagram and the contact sheet from lore/foodweb/primigenia.json.

  python3 tools/lore/foodweb_report.py     (needs rsvg-convert + ImageMagick convert for the diagram JPG, Pillow for the contact sheet)
Outputs: docs/lore/primigenia-food-web.md, docs/evidence/lore/food-web.jpg (+ .svg), docs/evidence/lore/food-web-contact-sheet.jpg
"""
import os, subprocess, sys, textwrap
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "council")); sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lorelib import ROOT, load
import foodweb as fw
from foodweb_classify import H, LEVELS
from foodweb_draw import SIZE_TXT, PLAN_TXT, SLOTS

LCOL = {"producer": "#3f8f4f", "primary_consumer": "#c9a227", "secondary_consumer": "#d9822b", "tertiary_consumer": "#c0453a", "apex_predator": "#7a1f5c", "scavenger": "#6b6f76",
        "decomposer": "#8a5a3c", "parasite": "#3a7ca5", "omnivore": "#9b7bb8"}
LAB = {"producer": "Producers", "primary_consumer": "Primary consumers", "secondary_consumer": "Secondary consumers", "tertiary_consumer": "Tertiary (mid) predators", "apex_predator": "Apex predators",
       "scavenger": "Scavengers", "decomposer": "Decomposers", "parasite": "Parasites", "omnivore": "Omnivores"}
ROW = {"producer": 8, "decomposer": 7, "primary_consumer": 6, "parasite": 5, "omnivore": 4, "secondary_consumer": 3, "scavenger": 2, "tertiary_consumer": 1, "apex_predator": 0}


def names(M):
    out = {}
    for i, m in M.items():
        d = load(os.path.join(ROOT, "lore", "creatures" if m["kind"] == "creature" else "flora", i + ".json")); out[i] = d["name"]["en"]
    return out


def matrix(M, new=None):
    rows = ["| level | " + " | ".join(H) + " | total |", "|---|" + "---|" * (len(H) + 1)]
    for lv in LEVELS:
        cells = []; tot = 0
        for h in H:
            n = sum(1 for m in M.values() if m["level"] == lv and h in m["habitats"] and (new is None or m.get("new", False) == new or (new is False and not m.get("new"))))
            cells.append(str(n) if n else "**0**"); tot += n
        rows.append(f"| {LAB[lv]} | " + " | ".join(cells) + f" | {len(set(i for i, m in M.items() if m['level'] == lv and (new is None or bool(m.get('new')) == new)))} |")
    return "\n".join(rows)


def diagram(M, N, out_svg):
    W, Hh = 2400, 1500; colw = {h: 0 for h in H}
    hab = {i: m["habitats"][0] for i, m in M.items()}
    order = sorted(H, key=lambda h: H.index(h)); x0 = {}; x = 60
    cnt = {h: max(1, sum(1 for i in M if hab[i] == h)) for h in H}
    tot = sum(cnt.values()); span = W - 120
    for h in order: x0[h] = x; x += span * cnt[h] / tot
    pos = {}; slots = {}
    for i, m in M.items():
        h = hab[i]; r = ROW[m["level"]]; slots.setdefault((h, r), []).append(i)
    for (h, r), ids in slots.items():
        w = span * cnt[h] / tot
        for k, i in enumerate(sorted(ids)):
            pos[i] = (x0[h] + w * (k + 0.5) / len(ids), 90 + r * 150 + (k % 2) * 34)
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{Hh}" viewBox="0 0 {W} {Hh}" font-family="Liberation Sans, sans-serif">', f'<rect width="{W}" height="{Hh}" fill="#fbf8f1"/>',
         '<text x="60" y="40" font-size="26" font-weight="bold" fill="#222">Primigenia food web (arrows run from the eaten to the eater; columns are the first habitat of each species; top = apex, bottom = producers)</text>']
    for h in order:
        o.append(f'<text x="{x0[h]:.0f}" y="{Hh - 40}" font-size="22" fill="#555" font-weight="bold">{h}</text><line x1="{x0[h]:.0f}" y1="60" x2="{x0[h]:.0f}" y2="{Hh - 70}" stroke="#ddd"/>')
    for i, m in M.items():
        for e in m.get("eats", []):
            if e in M:
                (ax, ay), (bx, by) = pos[e], pos[i]
                my = (ay + by) / 2
                o.append(f'<path d="M{ax:.0f},{ay:.0f} C{ax:.0f},{my:.0f} {bx:.0f},{my:.0f} {bx:.0f},{by:.0f}" fill="none" stroke="{LCOL[m["level"]]}" stroke-opacity="0.35" stroke-width="1.4"/>')
    for i, m in M.items():
        x, y = pos[i]; col = LCOL[m["level"]]; new = m.get("new")
        o.append(f'<rect x="{x-52:.0f}" y="{y-13:.0f}" width="104" height="26" rx="5" fill="{col}" fill-opacity="{1 if new else 0.55}" stroke="{"#000" if new else "none"}" stroke-width="1.2"/>')
        o.append(f'<text x="{x:.0f}" y="{y+5:.0f}" font-size="13" text-anchor="middle" fill="#fff">{N[i][:16]}</text>')
    for k, lv in enumerate(LEVELS):
        o.append(f'<rect x="{60 + k * 250}" y="{Hh - 28}" width="16" height="16" fill="{LCOL[lv]}"/><text x="{82 + k * 250}" y="{Hh - 15}" font-size="15" fill="#333">{LAB[lv]}</text>')
    o.append(f'<text x="{W-560}" y="{Hh-75}" font-size="15" fill="#333">outlined = new in the 2026-11-21 batch; pale = existing</text></svg>')
    open(out_svg, "w").write("\n".join(o))


def contact_sheet(M, N, path):
    from PIL import Image, ImageDraw, ImageFont
    news = [i for i, m in M.items() if m.get("new")]
    news.sort(key=lambda i: (ROW[M[i]["level"]], M[i]["kind"], i))
    F = lambda b, s: ImageFont.truetype("/usr/share/fonts/liberation/LiberationSans-%s.ttf" % ("Bold" if b else "Regular"), s)
    cw, ch, cols = 420, 215, 4; rows = (len(news) + cols - 1) // cols
    img = Image.new("RGB", (cols * cw + 20, rows * ch + 90), "#fbf8f1"); d = ImageDraw.Draw(img)
    d.text((16, 14), "Primigenia food web: new species, 2026-11-21 batch (seed %s)" % fw_seed(), font=F(True, 26), fill="#222")
    d.text((16, 50), "colour = trophic level; bar = size class; creatures show plan and activity", font=F(False, 15), fill="#555")
    sizes = ["insect", "small", "medium", "large", "giant"]
    for n, i in enumerate(news):
        m = M[i]; x = 10 + (n % cols) * cw; y = 80 + (n // cols) * ch; col = LCOL[m["level"]]
        d.rounded_rectangle([x, y, x + cw - 10, y + ch - 10], 8, fill="#ffffff", outline="#d8d2c4")
        d.rectangle([x, y, x + cw - 10, y + 34], fill=col)
        d.text((x + 10, y + 5), N[i], font=F(True, 20), fill="#fff")
        d.text((x + cw - 20 - d.textlength(LAB[m["level"]].split(" ")[0], font=F(False, 13)), y + 10), LAB[m["level"]].split(" ")[0], font=F(False, 13), fill="#fff")
        lines = [f"{i}  |  {m['kind']}", f"role: {m['role'].replace('_', ' ')}", "habitat: " + ", ".join(m["habitats"])]
        if m["kind"] == "creature":
            lines.append(f"size: {SIZE_TXT.get(m.get('size'), '?')}")
            lines.append(f"plan: {PLAN_TXT.get(m.get('plan'), '?').split(' (')[0]}; {m.get('activity', '?').replace('_', ' ')}")
        else:
            pf = load(os.path.join(ROOT, "lore", "flora", i + ".json")); g = pf["generator"]["height_m"]
            lines.append(f"form: {pf['growth_form']}; height {g['min']}-{g['max']} m")
            lines.append("colour: " + str(pf["generator"].get("colour", {}).get("base", ""))[:44])
        yy = y + 42
        for ln in lines:
            d.text((x + 10, yy), ln[:62], font=F(False, 14), fill="#333"); yy += 19
        eats = ", ".join(M[i].get("eats", [])[:5]) or "-"
        d.text((x + 10, yy), "eats: " + eats[:58], font=F(False, 13), fill="#666"); yy += 18
        if m["kind"] == "creature":
            si = sizes.index(m.get("size", "small")); d.rectangle([x + 10, y + ch - 28, x + 10 + (si + 1) * 60, y + ch - 20], fill=col)
            d.rectangle([x + 10 + (si + 1) * 60, y + ch - 28, x + 310, y + ch - 20], fill="#eee")
    img.save(path, "JPEG", quality=88)


def fw_seed(): return load(fw.web_path(ROOT))["seed"]


def md_table(header, rows): return "\n".join(["| " + " | ".join(header) + " |", "|" + "---|" * len(header)] + ["| " + " | ".join(str(c) for c in r) + " |" for r in rows])


def main():
    web = load(fw.web_path(ROOT)); M = web["members"]; N = names(M)
    old = {i: m for i, m in M.items() if not m.get("new")}; new = {i: m for i, m in M.items() if m.get("new")}
    der = load(os.path.join(ROOT, "lore", "worlds", "primigenia.derivation.json"))
    draw = load(os.path.join(ROOT, "lore", "foodweb", "primigenia.draw.json"))
    ev = os.path.join(ROOT, "docs", "evidence", "lore"); os.makedirs(ev, exist_ok=True)
    svg = os.path.join(ev, "food-web.svg"); diagram(M, N, svg)
    subprocess.run(["rsvg-convert", "-o", os.path.join(ev, "food-web.png"), svg], check=True)
    subprocess.run(["convert", os.path.join(ev, "food-web.png"), "-quality", "85", os.path.join(ev, "food-web.jpg")], check=True); os.remove(os.path.join(ev, "food-web.png"))
    contact_sheet(M, N, os.path.join(ev, "food-web-contact-sheet.jpg"))
    errs, warns = fw.check_web(ROOT)
    o = ["<!-- generated by tools/lore/foodweb_report.py from lore/foodweb/primigenia.json; do not edit -->", "", "# Primigenia's food web", "",
         "Tracker test L-TROPHIC. Brief: `docs/briefs/trophic-web.md`. Method: `lore/rules/derivation.md` (derive forward, biosphere before creatures). Data: `lore/foodweb/primigenia.json`; checker: `tools/lore/foodweb.py` (run by `tools/lore/validate.py`).", "",
         "![food web](../evidence/lore/food-web.jpg)", "", "Contact sheet of the new species: `docs/evidence/lore/food-web-contact-sheet.jpg`.", "",
         "## 1. Derivation sheet (summary)", "", "Sheet: `lore/worlds/primigenia.derivation.json`, recomputed by `tools/lore/derivation.py`. Premises: " + der["premises"], "",
         md_table(["id", "item", "value", "confidence"], [[it["id"], it["key"].replace("_", " "), (f"{it.get('value')} {it.get('unit', '')}".strip() if it.get("value") is not None else ""), it["confidence"]] for it in der["items"]]), "",
         "Two discrepancies in the existing world canon were exposed by recomputing it (reported as warnings, not changed): D16 terminal velocity (F4 says 25% lower, the same ratio gives about 18%) and D19 moon period (F6: 29.7 d at 450,000 km, Kepler gives 32.4 d; about 425,000 km would match).", "",
         "## 2. Classification of what existed (before the batch)", "", f"{sum(1 for m in old.values() if m['kind'] == 'creature')} creatures of world `primigenia` and {sum(1 for m in old.values() if m['kind'] == 'plant')} flora files (the brief says 21; `lore/flora/` holds 20).", ""]
    for kind, title in (("creature", "Creatures"), ("plant", "Flora")):
        rows = [[f"`{i}`", N[i], LAB[m["level"]], m["role"].replace("_", " "), ", ".join(m["habitats"]), ", ".join(m.get("eats", []))] for i, m in sorted(old.items(), key=lambda t: (ROW[t[1]["level"]], t[0])) if m["kind"] == kind]
        o += [f"### {title}", "", md_table(["id", "name", "level", "role", "habitats", "eats"], rows), ""]
    o += ["Habitat ranges were widened where a creature's own diet text needs it (for example merodeador hunts rondo at the meadow edge). `vents` (fumaroles and hot springs) is an eighth habitat added for the chemosynthetic producers; the seven main habitats are meadow, forest, shore, shallows, caves, spring, highlands.", "",
          "## 3. Gaps before", "", "Species per level and habitat, existing only:", "", matrix(M, False), "",
          "Gaps (zero cells and dead ends in the existing web):", ""]
    before_gaps = [
        "No apex predator anywhere; the top of every habitat is a mid predator (garfio, espinodo, merodeador). Coloso and the player have no predator by lore.",
        "One scavenger (el_resoplido, vents and slopes); none on the shore, forest floor, meadow or in the shallows although carcasses drift ashore (F20).",
        "One decomposer animal (babosa) and one fungus (pan_de_humus): none on the shore, spring, shallows or highlands; no dung, wrack or wood eaters.",
        "No parasite and no mutualist cleaner of any kind.",
        "No insect herbivores, pollinators, granivores or algae scrapers: insectivores and nectar flowers (velilla) had nothing to connect to. No zooplankton, so the filter feeders and jellies had no food item.",
        "Producers: none planktonic, none chemosynthetic below the fumarole crust, none in dark lava tubes, only green or violet-red pigments (no black or brown producer), no parasitic plant.",
        "Shallows had no mid predator; meadow and spring had no secondary consumer; forest had no primary consumer among animals.",
        "Plants without an eater: caramillo, salvisca, rodela_de_nieve, lengua_de_lava (hierroflor and vetirroja are defended).",
        "Existing animals with no predator written: sosa, corona, sifon, cuarteta, brujula, el_resoplido, ecolumbre (only the nocturnal creature, now acechalunas), alula."]
    o += ["- " + g for g in before_gaps]
    o += ["", "## 4. Seed and random draw", "", f"Fixed seed `{draw['seed']}` (`python random.Random(seed)`, `tools/lore/council/foodweb_draw.py`, record `lore/foodweb/primigenia.draw.json`). Each slot is a gap (level x role x habitat). The draw picks body plan (legs 0/2/4/6/8+, radial, sessile), size class (insect to giant) and activity (day, night, dawn and dusk, tidal) at random, 30% from a wide list; a draw is kept only if the planet physics can justify it (rejection rules in the script: arthropod size ceiling, apex needs mass, insectivores are small, detritivores and parasites are small, cleaners work by day, tidal activity needs a tidal habitat, no day activity in caves). The council (qwen draft, DeepSeek skeptic, Composer astrobiology referee) then derives each species around its accepted draw.", "",
          md_table(["slot", "level", "role", "habitats", "plan", "size", "activity", "draws rejected"], [[s["slot"], s["level"], s["role"], ", ".join(s["habitats"]), s["plan"], s["size"], s["activity"], s["n_rejected"]] for s in draw["creature_slots"]]), "",
          "## 5. New species", ""]
    rows = []
    for i, m in sorted(new.items(), key=lambda t: (ROW[t[1]["level"]], t[1]["kind"], t[0])):
        rows.append([f"`{i}`", N[i], m["kind"], LAB[m["level"]], m["role"].replace("_", " "), ", ".join(m["habitats"]), SIZE_TXT.get(m.get("size"), "") if m["kind"] == "creature" else "", ", ".join(m.get("eats", []))])
    o += [md_table(["id", "name", "kind", "level", "role", "habitats", "size", "eats"], rows), "", "## 6. Gaps after", "", matrix(M), "",
          "Quotas: " + ", ".join(f"{LAB[lv]} {sum(1 for m in new.values() if m['level'] == lv)} new" for lv in ("apex_predator", "scavenger", "decomposer", "parasite")) + f"; mutualists (cleaner, seed disperser, pollinator): {sum(1 for m in M.values() if m['role'] in fw.MUTUALIST)} in total; chemosynthetic producers: {sum(1 for m in M.values() if m['role'] == 'chemosynthetic')}.", "",
          "## 7. Energy pyramid and spawn weights", "", "Starting values, to be checked by tracker test L-TROPHIC (A27 ecology). About 10% of the energy passes up each level (Lindeman 1942; Pauly and Christensen 1995; D25), so apex animals are rare and grazers common. Scavengers, decomposers, parasites and omnivores are put on the level whose flux feeds them. Within a habitat, the level weight is split evenly among the species of that level, and the creature weights of each habitat are normalised to 100 (plants separately, by role).", "",
          md_table(["level", "relative weight", "why"], [["primary consumer", fw.LEVEL_W["primary_consumer"], "base of the animal pyramid"], ["decomposer", fw.LEVEL_W["decomposer"], "detritus flux about equals herbivory"], ["omnivore", fw.LEVEL_W["omnivore"], "spans primary and secondary"],
              ["secondary consumer", fw.LEVEL_W["secondary_consumer"], "10% of primary"], ["parasite", fw.LEVEL_W["parasite"], "lives on primary hosts"], ["scavenger", fw.LEVEL_W["scavenger"], "carrion is the tail of every level"], ["tertiary consumer", fw.LEVEL_W["tertiary_consumer"], "10% of secondary"], ["apex predator", fw.LEVEL_W["apex_predator"], "10% of tertiary; D26: about 6 adults island-wide"]]), "",
          "Creature spawn weight by habitat (each column sums to 100):", ""]
    ids = [i for i, m in sorted(M.items(), key=lambda t: (ROW[t[1]["level"]], t[0])) if m["kind"] == "creature"]
    o += [md_table(["species", "level"] + H, [[f"{N[i]}", M[i]["level"].replace("_consumer", "").replace("_predator", "")] + [M[i]["spawn"].get(h, "") for h in H] for i in ids]),
          "", "| sum | |" + "|".join(f" {round(sum(M[i]['spawn'].get(h, 0) for i in ids), 3)} " for h in H) + "|", "", "Flora spawn weight by habitat (each column sums to 100; photosynthetic 10, chemosynthetic 3, mixotroph 2, decomposer 5, parasite 1, defended x0.2):", ""]
    pids = [i for i, m in sorted(M.items(), key=lambda t: (t[1]["role"], t[0])) if m["kind"] == "plant"]
    o += [md_table(["species", "role"] + H, [[N[i], M[i]["role"]] + [M[i]["spawn"].get(h, "") for h in H] for i in pids]), "",
          "## 8. Consistency", "", f"`python3 tools/lore/foodweb.py check`: {len(errs)} error(s), {len(warns)} warning(s). Checked: no dangling ids, every consumer has a food source that shares its habitat and sits below it, nothing is a dead end except apex animals, coloso and the player, weights sum to 100 and fall from primary to apex, batch quotas, at least one species per level in each main habitat.", ""]
    o += ["- warning: " + w.split(": ", 1)[-1] for w in warns] + [""]
    o += ["## 9. Playable hooks (new creatures)", ""]
    hooks = []
    for i, m in sorted(new.items(), key=lambda t: (ROW[t[1]["level"]], t[0])):
        if m["kind"] != "creature": continue
        c = load(os.path.join(ROOT, "lore", "creatures", i + ".json")); ch = c["chains"][0]
        hooks.append([N[i], "; ".join(f"{x['skill']['name']['en']} ({x['skill']['role']})" for x in c["chains"][:3]), ch["weakness"][:120], (c.get("secrets") or [""])[0][:120], c["niche"]["diet"][:80]])
    o += [md_table(["species", "skills (observe to learn)", "weakness (threat counter)", "secret", "food and gifts"], hooks), "",
          "## 10. Not done", "", "- Game import is milestone 6: no snapshot, event or `core/` change. Spawn weights are data only.", "- All new entries are `draft`; the owner sets `canon`.", "- Whether gameplay numbers (weights) feel right is open until tracker test L-TROPHIC.", ""]
    open(os.path.join(ROOT, "docs", "lore", "primigenia-food-web.md"), "w").write("\n".join(o))
    print("report written;", len(errs), "errors")


if __name__ == "__main__":
    main()
