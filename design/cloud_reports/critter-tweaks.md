---
type: report
tags: [cloud, routines, living-world]
---

# critter-tweaks — BACKLOG «Critter tweaks» (a smaller pigeon, a moth of its own shape; no new art)

**Done:** the pigeon 16 art px perched (24 world, was 24 art / 36 world), the moth stretched ×1.4 wide at the same 18 world px height and flapping slower — both in the critter scenes only. Chart row `critter_small` (pigeon) in `design/world_scale.json`. `verify_ambient_critters` and `verify_scripts_compile` ALL PASS; capture `design/shots/critter_tweaks.png`.
**Not done / found:** the smaller pigeon is **invisible in the City** — all three City pigeons perch at y 384, 24 px inside the street's `Terrain` strip (top at y 360, drawn after `Critters`), so before only the top third showed, now nothing does. Fix is in `Maps/City.tscn` (out of scope here) — new B row below.
**D-ID (next free, as built):** D868, text below. **B rows fixed:** none. **New B row:** B207 below.
**Full suite:** `SUITE: 3 FAIL` (139 PASS), none from this branch: `verify_difficulty` (17 FAIL) and `verify_lab_boss` (2 FAIL, balance numbers) fail identically on `origin/feature/backlog` with the critter changes reverted; `verify_camera_rooms` (1 FAIL, AlchemistStore camera step 41.7 px, a room without critters) passed on its one re-run on this branch and on the base — timing under J=4 load.

## D868 (ROUTINE CALL, `cloud/critter-tweaks`, BACKLOG «Critter tweaks», Sapega 28.10 «можна виправити розтягуючи»; amends D803 / D814)

**Critter tweaks, no new art.** *The pigeon* is smaller than the lark: 16 art px perched = 24 world px (¼ H; was the
`critter` row's 24 art / 36 world) — `critter_pigeon.tscn` Sprite scale 0.5455 (the perch frame's 44 opaque rows × 0.5455
= 24), its `Perch` notifier rect scaled with it; `design/world_scale.json` gains the row `critter_small` (h 0.25, 16 art,
24 world, keyword `pigeon`) ahead of `critter`, which loses `pigeon`. *The moth* keeps the chart's 12 art / 18 world
height but is stretched ×1.4 sideways (Sprite scale (1.3264, 0.9474)): broad, low wings and a stubby body next to the
butterfly's upright 1:1; its `Perch` rect widened to match; it flaps slower (fly 10 → 6 fps, perch 1.5 → 1.0 fps). Both
in the critter scenes, so every room that places them follows; scare / return / sound unchanged (D803).

## B207 (new, for BUGS.md)

| B207 | City pigeons sunk in the street | `Maps/City.tscn` `Critters/Pigeon1..3` sit at y 384, but the street `Terrain` sprite (top y 360) is drawn after `Critters` and covers the bottom 24 px. The 36-px pigeon showed only its head; the 24-px pigeon (D868) is fully hidden. Fix: pigeons to y 360 (on the street line), or `Critters` after `Terrain` — Maps/ was out of this routine's scope. `verify_ambient_critters` does not catch occlusion. |

## Details

- `SampleProject/Scenes/Backgrounds/Decor/critter_pigeon.tscn` — Sprite `scale` 0.8182 → 0.5455; `Perch` rect
  `Rect2(-15.274, -30.548, 30.548, 30.548)`.
- `SampleProject/Scenes/Backgrounds/Decor/critter_moth.tscn` — Sprite `scale` (0.9474, 0.9474) → (1.3264, 0.9474);
  `Perch` rect `Rect2(-26.528, -37.896, 53.056, 37.896)`; `fly` speed 10 → 6, `perch` 1.5 → 1.0. `flip_h` (perch_flip,
  flight direction) still mirrors correctly: the offset centres the cell, the scale applies after it.
- `SampleProject/UI/verify_ambient_critters.gd` — `ART_HEIGHT["critter_pigeon"]` 24 → 16 (the new chart row: the
  exact-size check would otherwise fail on the City pigeons at 24 vs 36 world px); new check in `_check_size`: the moth's
  sprite is ×1.4 wider than tall (so a later edit cannot quietly turn it back into the butterfly's shape).
- `design/world_scale.json` — row `critter_small` (pigeon). `scale_chart.py` / `probe_world_scale.gd` read the rows as
  data; no test pins the row list.
- `SampleProject/UI/capture_critter_tweaks.gd` (new) — run with `-- before` on the old scenes, then `-- after`; it
  sets every critter's scare distance to 0, lets a startled one land, holds perch frame 0, crops 480×270 around the
  critter ×2 and builds the 2×2 sheet.

### Tests

- `verify_ambient_critters` — `RESULT: ALL PASS`
- `verify_scripts_compile` — `RESULT: ALL PASS`
- Full suite (`Scripts/Tools/run_verify.sh`, J=4, nproc 4): 139 PASS, 3 FAIL as in the summary. The run was cut at my
  10-min tool limit after 73 tests; the other 69 ran with the same script on the rest of the list (`SUITE: ALL PASS`).
  The base check: the four changed files checked out from `origin/feature/backlog`, then `run_verify.sh` on the three.

### Shot

`design/shots/critter_tweaks.png` — left before, right after; top: City Pigeon3 by the hero (before: the head over the
street edge; after: hidden, B207), bottom: the attic moth by the hero (after: wider and lower, same height).
