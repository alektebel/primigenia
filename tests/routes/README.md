# Curated route graph (C1)

These are acceptance fixtures, including currently failing routes. A red certification is not a waiver.

(Retired after B1: the ring island fixtures `seed{1,7,42}.json`.) They pinned terrain v5 at n=1024 (v5 only added the version word and the desc hash to the terrain hash: the arrays are the v4 ones), the terrain hash, the actual initial Merodeador profile,
StageSetup nest and herd home positions, every generated cave record and the volcano descriptor.
`route_places` and `required_pairs` define the required graph. Every pair is tested in both directions,
with all nine bodies: Merodeador (4 legs, radius 3 m), and 2/4/6/8 legs at radii 0.5 and 4 m.
The graph is a nest-centred star: round trips to each home range, the start valley, water, river gap and hidden cave.
Terrain curation (docs/TERRAIN.md item 9) guarantees the last two: **river-gap** is the per-seed gap checkpoint (the lowest dry
cell on the 809 m circle around the start; `(796.29,138.87)` seeds 1 and 42, `(768.16,258.40)` seed 7, pinned in
`routes_fixture.gd`; the earlier `(800,120)` lay on a 114 m massif on seed 7) and **hidden-cave-entrance** is the mouth stand
point, 6 m in front of the first entrance record along its facing. The entrance cell itself stays a steep rock face by design
(terrain guarantee slope > 0.8; the rock behind it is never graded), so the certified endpoint is the apron in front of it.
No assertion claims that every arbitrary pair of island coordinates is connected.

The five nest/encounter/home points come directly from `StageSetup.build(..., herds=true)` using the real
profile and probe. The start-valley checkpoint is (30,20); lake shore/water approach is (-75,70), east of
the lake centred at (-150,70).
The hidden-cave endpoint is derived from the first generated entrance record (`caves[0]` + 6 m x facing), not a snapped point.
Other cave records are retained for later curation; interiors do not exist in the height field.

`seed*.txt` is the C-readable derivative. `tools/routes/fixtures.py --check` checks it against the JSON.
After deliberately changing data, run `python3 tools/routes/fixtures.py`.
To re-export actual placements, run Godot headless with
`--path godot --script res://game/tests/routes_fixture.gd -- <absolute tests/routes directory>`
using the freshly built extension, then regenerate the text fixtures. This export does not alter terrain or gameplay placement.

Missing gameplay placements, explicitly **TODO**, not certified:

| Place | Proposed coordinates (x,z), seeds 1 / 7 / 42 | Basis |
|---|---|---|
| Named spring | (-75,70) / (-75,70) / (-75,70) | Use the existing lake water approach; no spring entity is placed. |
| Fossil site | (747.070312,377.929688) / (-381.445312,543.164062) / (1.757812,827.929688) | First cave feature in each seed; proposed clue site, not an implemented fossil. |
| Crater rim | (-500,-750), all three seeds | Proposed high-col/range site only. `volcano=0` by default; all actual volcano/crater descriptors are zero. Enable and curate a volcano before certifying a rim. |
| Meteor shard | (30,20), all three seeds | Proposed starter-valley discovery site; no shard positions exist in core/game data. |

Do not turn these TODOs into fake successful trips to (0,0). The cave endpoint is the apron the terrain curation grades in
front of the entrance; certifying the exact steep notch cell is deliberately not claimed. Results are in `docs/evidence/routes/`.

## Measurements

`python3 tools/routes/report.py` builds the test, prints each table and writes the three evidence files,
returning nonzero if any required trip fails. `make test` includes the same strict gate for all three seeds.
Each trip starts with a fresh world at the endpoint, issues one GO, then uses only `cp_stage_step(NULL)`;
there are no debug moves or teleports during travel. It must emit `arrived`, finish within 0.3 m in 20,000 ticks,
and never exceed the 1.26 full-gradient ceiling (0.0001 measurement tolerance). Its complete tick-hash digest
must equal a second run. Encounters are disabled to isolate traversal, not certify combat survival.

Plan length is the initial `path_found.length`; walk length sums actual horizontal displacement. Grade is the
same 0.25 m gradient stencil used by the ceiling. Fords count entries into shallow river-class cells; stalls
count ticks with a blocked reason. Replans count subsequent `path_found` events. Cold planning explicitly
invalidates derived nav data using a different valid morphology; warm planning repeats exactly that route
on its lazily filled cache, not a fully prefilled whole-island grid. Times are wall clock and are not deterministic;
all simulation outputs and tick hashes are deterministic. A rejected route has zero simulated ticks.

## Star massif fixtures (B1)

`star-seed{1,7,42}.json` / `.txt` are the same graph on the frozen Star massif (`data/islands/star_massif.island.json`, n=1536, terrain hash mixes the desc hash).
Run with `routes_test --island star <seed>`; export with `godot ... --script res://game/tests/routes_fixture.gd -- <tests/routes dir> star`, then `python3 tools/routes/fixtures.py`.

- **The nest is not the origin.** The nest valley holds a lake (about 100 m radius, up to 2.4 m deep) around the origin, so `StageSetup.find_nest` picks the nearest cell that is dry, gentle (normal.y at least 0.9) and 30 m clear of any pond (seeds 1 and 42: (0,115); seed 7: (101.6,42.1)). Home and herd spots must now be normal.y above 0.9 along the whole line from the nest (it was 0.8: a 38 degree bank put Babosa out of every two-legged body's reach).
- **Places:** nest, the six homes, the four exits (the second point of each island trail, 300 to 650 m out, snapped to dry gentle ground), the cave mouth apron, five shards, the chamber. No river gap, start valley or lake shore (they belong to the ring island).
- **The chamber is certified from the mouth** (`hidden-cave-entrance -> cave-chamber`): the nav grid of the 8 km field is 7.8 m, and a GO order from far away into the passage is refused as unreachable.
- **`min_legs`**: the north and south passes are not certified for two-legged bodies (their grip, 0.5 and 4 m, cannot take the grade of the passes). The fixture lists them in `min_legs`; the test skips a pair when the body has fewer legs than either end asks for.
- The ring island fixtures (`seed*.json`, the v4 n=1024 graph described above, evidence `docs/evidence/routes/seed*.md`) were retired in the commit after the one that added these; they stay in git history. `routes_test` takes only `--island star`.
