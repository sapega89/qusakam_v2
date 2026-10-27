---
type: report
tags: [cloud, routines, integrate]
branch: cloud/integrate-30
---

# integrate-30 (cloud, 2026-10-27)

**Summary.**
- Merged into `cloud/integrate-30` (from `origin/feature/backlog` `91e6eccc`): `cloud/hero-death` (H1), `cloud/skills-v2-move` (H3 slices 1–3; it already held `skills-v2-data` and `skills-v2-screen`), `cloud/scale-exact` (R4, first half), `cloud/fx-film` (A9).
- D-IDs: **D807** death pose · **D808** provisional numbers of the 28 planned actives · **D809** shield skills need no shield · **D810** GAP: the SKILLS build loses 6 `verify_difficulty` rows · **D811** skills screen fits at 19 a tab · **D812** movement skills (dash, leap-slam). B rows: **B187–B192** (scale-exact, art lane, open), **B193** and **B194** (fixed here).
- Interplay fixes: **B193** a hero killed mid-dash slid on 190 px (`_break_action` now ends the push); **B194** a bandit dropped on the hero stayed on his top corner (`verify_combat_feel` [2], ~2 of 5 runs alone; `slide_off_bodies` mistook the corner for a side touch).
- The R4 probe ran in Godot here (scale-exact could not): 525 objects, 288 judged, **111 off** (the same 111 as the static run), 177 ok. The chart `design/shots/scale_chart.png`, `tables.md` and the 16 room rulers are redrawn from Godot's numbers.
- Full suite once after all merges: **`SUITE: 3 FAIL in 13 min 26 s, J=4`** (`nproc` = 4), 134 PASS. After the fixes: `verify_combat_feel` and `verify_weapon_animations` ALL PASS (also with 4 busy CPU loops beside them). **Still red: `verify_difficulty` 6 FAIL**, D810: a balance call (Sapega or a balance routine), not an integration break; the test was not loosened.
- `verify_camera_transitions` and `verify_combat_flow` (both red in the local run cut short): **PASS** in this suite, so no change was made to them. B170 stays open (it is intermittent); nothing in [2c] was found failing to fix here.

## Per branch

| Branch | Merge | Conflicts | ID mapping | Tests here |
|---|---|---|---|---|
| `cloud/hero-death` | `eab66d33` | `HANDOFF.md`, `MASTER_PLAN.md` → feature/backlog's text, H1 marked | new text → **D807**; B184 note (frames seen in `design/shots/hero_death.png`, row stays open for Sapega); its «needs its own B row» for `verify_combat_feel` [2] → **B194** (fixed) | `verify_hero_death` ALL PASS (+ new [4], see B193) |
| `cloud/skills-v2-move` (+ `-data`, `-screen`; both were ancestors, checked with `merge-base --is-ancestor`) | `9d4a61a3` | `SampleProject/Scripts/Player.gd` `take_damage`: feature/backlog's weak block (D776, half damage on an empty stamina bar) kept, and the weak-block half goes through `mitigated_damage(damage, guard == &"block")` (D809's Shield Block on a blow through a held block) | D-sv2a → **D808**, D-sv2b → **D809**, D-sv2c → **D810**, D-sv2s → **D811**, D-sv2m → **D812**; rewritten in 12 code files, `skills.json` and the three reports | `verify_skill_moves`, `verify_skill_screen`, `verify_skill_rules`, `verify_skill_fx` PASS in the suite; `verify_difficulty` 6 FAIL (D810) |
| `cloud/scale-exact` | `c239c8b1` | none | B-new-1…6 → **B187–B192** (only in its report; the older reports' «B-new-N» are other routines' and untouched) | no Godot test of its own; `verify_scripts_compile` ALL PASS; probe re-run (below) |
| `cloud/fx-film` | `11eb7493` | none | no D, no B | `verify_scripts_compile` ALL PASS (no game code) |

## Fixes made here

- **B193** — `PlayerCombat._break_action` (`SampleProject/Scripts/Player/Components/PlayerCombat.gd`) stops `mover` push in `CAST_MOVE`. `PlayerMover` lets a running push win over `locked`, so the H1 death pose (which locks the mover) did not stop a dash. `verify_hero_death` [4] (new): Dash Strike, killed while moving → the body stays (190.0 px before the fix, 0.0 after).
- **B194** — `CombatBody2D.slide_off_bodies`: the 2 px down-probe on the other fighter's top corner gives a side normal (1, 0); it now still counts as standing on top when the feet are at that body's top. Per-frame log of a failing run: the bandit slid from x +4 to +28 and stopped at y 327.9 (`is_on_floor` true, on the hero's corner). 6 of 6 runs green after.
- **B186 pattern** (tests waiting by the clock for a physics result): `verify_weapon_animations` sampled the strike frame 0.06 s after a tap with `create_timer` → `_physics_wait` counts physics steps (it was the suite's third FAIL, `[false, true, true]`, green alone). `verify_hero_death` [1] timed Game Over with `Time.get_ticks_msec` → physics steps.

## Full suite (once, after all merges)

`Scripts/Tools/run_verify.sh`, J=4 (`nproc` 4), `verify_masher` skipped (`## MANUAL`, D806):
`SUITE: 3 FAIL in 13 min 26 s, J=4` — 134 PASS.

| FAIL | Why | Now |
|---|---|---|
| `verify_combat_feel` [2] «a bandit dropped on the hero slides off» (y 327.9 vs 368.0) | B194 | fixed, ALL PASS (also under load) |
| `verify_weapon_animations` «each strike frame shows with the hitbox on» `[false, true, true]` | clock wait (B186) | fixed, ALL PASS (also under load) |
| `verify_difficulty` 6 FAIL (SKILLS build: elite brute L8, tower shield guard L9, armoured scorpion L11, Mercenary L12, scorpion L9, brute rows) | D810 (skills-v2-data: no flat −20 % from a worn shield) | open, needs the balance call |

10 slowest: 138 s `verify_combat_enemies`, 129 s `verify_camera_transitions`, 111 s `verify_lab_route`, 110 s `verify_room_entrances`, 108 s `verify_rooms_batch1`, 106 s `verify_camera_rooms`, 90 s `verify_souls_combat`, 81 s `verify_bosses`, 81 s `verify_archer`, 66 s `verify_lab_cells`.

Re-runs after the fixes (only the failed ones): `verify_combat_feel` ALL PASS (22 s), `verify_weapon_animations` ALL PASS (57 s), `verify_hero_death` ALL PASS (8 s); `verify_scripts_compile` ALL PASS before the suite.

## R4 probe (scale-exact could not run Godot)

`xvfb-run … --script res://SampleProject/UI/probe_world_scale.gd -- out=design/shots/scale` (97 s), then
`scale_exact.py` (no rooms named) and `scale_chart.py` (system `/usr/bin/python3`: the `/usr/local` one has a broken Pillow).
- 525 objects (scale-exact counted 339: rooms-dressing's grass and critters came since scale-probe), 288 judged, **111 off**, 177 ok (153 grass, 24 critters: D803/D805 built them from the exact plan). Every off object is the same as in scale-exact's static run, so its top-20 table and B187–B192 stand.
- One difference: Godot measures the elites at their runtime scale (D766): `bandit_brute` 98.9 px (×0.69, was 86 static), `shield_tower` 97.2 px (×0.68, was 81). Still too small against 144.
- Committed: `design/shots/scale/probe.json`, `tables.md`, `design/shots/scale_chart.png` (2400×8982), the 16 `rooms/*_grid.jpg` rulers (now from fresh captures, so the 5 changed rooms are current). The raw `rooms/*.png` captures are not committed (as before).

## What is left
- **D810**: the SKILLS build vs 6 difficulty rows — Sapega's call (options a/b/c in D810). `verify_difficulty` stays red until then.
- **R4**: Sapega's «ок» on `design/shots/scale_chart.png` (palm 4 H, elites ×1.25?, companions, storeys), then the regeneration list (B187–B192).
- **B184**: Sapega to look at the Death frames in `design/shots/hero_death.png`.
- **H3**: next slices ranged → stance (+ H2 shields) → control; art lane list in `skills-v2-move.md`.
- **B170** (`verify_combat_flow` [2c]) stays open: green in this suite. Its waits are `create_timer` while the enemy's wind-up/strike also runs on process-time timers, so only the hit check is a physics result; I did not change it without a failing run to measure.
- Merge `cloud/integrate-30` into `feature/backlog` (the orchestrator).
