---
type: report
tags: [cloud, routines, integration]
---

# integrate-27 (cloud routine, 2026-10-27)

**Summary — NOT DONE, do not fast-forward feature/backlog yet.**
- Godot could not be fetched: the session's permission check refused the download of the Godot 4.6.2 zip (ROUTINE_RULES Setup 2), and no Godot binary exists in the container. **No test ran** (steps 1, 2, 4, 5, 6 unverified).
- Fix 1 (vulture floor) is written from the code and the scenes, **unrun**. Fix 2 (city_gates_raid fall) is **not fixed**: the cause cannot be found without running it.
- Step 3 done: `origin/feature/backlog` merged, 2 conflicted files resolved by keeping both sides; no new duplicate D-/B-IDs.
- No D-ID text, no B rows fixed. Full suite: **not run**.
- Branch `cloud/integrate-27`: `7b315503` (fliers), `36aec1ff` (merge).

## 1. verify_flying_enemies — the vulture touches the floor (written, unrun)
Cause: D766 grew the vulture's art ×1.25 (bat ×1.33 from 0.75 → 1.0, Cthulhu fly ×1.5 from 0.75 → 1.125) but kept the fliers' bodies, and `FlyingLogic` still aims the swoop at the hero's centre and keeps the station at `hover_height` over his feet. So the drawn wings reach as low as before plus the growth.
Fix: the swoop target, and the station height next to the hero, rise by `_lift`. That is how far the drawn bottom grew, measured from the sprite: the opaque bounds of the flight and strike frames (`HitAreas.body_rect` ∪ `strike_rect`). The bottom is multiplied by `1 − 1/grown`, where `grown` is the D766 factor stored on the scene's `Sprite2D` as `metadata/grown`.
- `SampleProject/Scripts/Gameplay/Components/FlyingLogic.gd:61` `_lift`; `:69`, `:73-79` `_art_growth()`; `:166` station height; `:178` `_in_reach` height; `:212-214` `_hero_centre()` (the dive and bite target).
- `enemy_vulture.tscn` `metadata/grown = 1.25`, `enemy_bat.tscn` `1.3333334`, `enemy_fly.tscn` `1.5`. The old vulture (elite, not grown by D766, scale 1.0) has no meta, so it gets no lift.
- Expected by hand: the vulture's strike frames reach ≈37.5 px below its centre (the hitbox shape), so the lift is ≈7.5 px and the lowest feet go from 383 to ≈375.5. The bat lift is ≈4 px, the fly ≈15 px.
- Agent call: the growth factor is stored in the scene rather than derived, because the pre-D766 scale is not in the data. Sapega or the orchestrator may prefer «the art's drawn bottom, not the body's, ends at the hero's centre», which needs no meta but lifts the vulture ≈21 px instead of 7.5.
- To verify: `verify_flying_enemies`, `verify_hit_areas`, `verify_combat_enemies`.

## 2. verify_city_gates_raid — «the hero falls after the teleport (y 360.0 -> 360.0)» (not fixed)
Not run alone (no Godot). Read statically: the check (`verify_city_gates_raid.gd:168-179`) teleports to `CityGates/Arrival` (900, 344), waits 30 physics frames after the room swap and expects y to grow. hard-fights-2's diff (`git diff ab344b46^1 ab344b46 --stat`) touches nothing on the teleport or fall path. Its only player change is `PlayerCombat.hold/shove/_break_action` (D769), which is not reached here. Candidates for the PC:
- timing: the hero stays frozen through the D506 fade-in for longer than 30 frames;
- or the hero already stands at y 360: the Arrival foot line. city-life (D740) and the PlatformSupport props are new in this room since perf-1 last saw this check green.
First step on the PC: run it alone and print `player.is_on_floor()` and the fade state at y0.

## 3. Merge of origin/feature/backlog
- `design/figma_decision_register.md` (tail): both sides kept, in order D766–D770 (hard-fights-2), then D771–D774 (feature/backlog).
- `design/MASTER_PLAN.md`:
  - A17: this branch's row, which lists the 8 missing poses from hard-fights-2 §5 and is newer.
  - A18: feature/backlog's row (D764 art done, the game check left to this routine).
  - Change log: feature/backlog's three lines, then this branch's hard-fights-2 line.
- `design/BUGS.md`: auto-merged.
- Duplicate-ID check (`grep -o '^| D[0-9]* '` / `'^| B[0-9]* '` | `uniq -d`): no new duplicates. D750–D774 and B159 each appear once. D89, D90, D91, D104, D105, D108 repeat, as they already do on `origin/feature/backlog`: the old OVERRIDE rows that restate earlier calls.

## 4–6. Not done
Not done: verify_progression, verify_save_load_room, verify_city_life, verify_laboratory (D764 `Seat` hop, `SavePoint.gd:62`), verify_scripts_compile, the `heavy_battle.mp3.import` uid rewrite, and the full suite. All of them need Godot. Nothing in `project.godot` or `export_presets.cfg` was touched.
