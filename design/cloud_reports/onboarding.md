---
type: report
status: done
tags: [onboarding, tutorial, combat, cloud]
---

# Cloud report — BACKLOG 28 onboarding (`cloud/onboarding`)

Built on top of the WIP commit 04255d56 (combat training, frame folders, Controls page, plan), which had never been
run. Plan and decisions: [[onboarding_plan]]. Godot 4.6.2 headless ran here; no display, so no window captures.

## What was built / fixed

### The six lessons in the street fight (slice 2)
- `SampleProject/Scripts/Gameplay/CombatTraining.gd` — lesson list, done-checks, safety, banners. `start()` :37,
  done-checks `_on_hit` :82 (attack, combo finisher, heavy), `_on_guard` :98 (block / parry), `_physics_process`
  :104 (dodge through a live swing within 160 px), `_keep_alive` :114, `_stop` resets the health floor :132.
- `SampleProject/Scripts/Gameplay/Scenes/Village.gd:180` `_start_fight` — training first ("Learn to fight: follow the
  lesson"), then "Defeat the bandit in the street"; training freed with the fight :323.
- **Fix:** `SampleProject/Scripts/Combat/CombatBody2D.gd:11,46` `min_health` — a health floor. The WIP healed only
  *after* a blow took health below 40 %, so the 3-hit finisher from ~45 % killed the bandit in the middle of the
  lessons (the verify caught it on the pad run). The training sets the floor to 1 for the hero and the bandit and
  back to 0 when it ends or leaves the tree.
- Lessons `lesson_attack … lesson_heavy` in `SampleProject/Resources/Data/tutorial.json:45…` (WIP), each with its
  `{action}` glyph, resolved per device by `input_glyphs.gd` (banner updates on the next input from the other device).

### Moving pictures in every tutorial window (slice 3)
- `SampleProject/Scripts/Menus/Game/tutorial_menu.gd:53` plays `"frames"` (`load_frames` :63, 10 fps `_process` :70),
  next to the button badge (`HintBar/KeyBadge`).
- Frame sets checked on disk and opened in the window: `move_jump` 14, `combo` 10, `dodge` 10, `block` 10, `parry` 12
  (the red glint is visible), `heavy` 10, `heal` 12, `assist` 12. Topics using them: movement, attack, heavy_attack,
  block, the six lessons, healing_palm, call_guard, companions. **No topic is missing its frames** — nothing to record
  locally. (The four general topics — Basic Controls, The Map, Saving, The Journal — keep their still screenshots.)

### Controls page (slice 4)
- `SampleProject/Scenes/Menus/Game/controls_component.tscn`, `SampleProject/Scripts/Menus/Game/controls_component.gd:11`
  (every action, keyboard + pad columns via `InputGlyphs.names_for` `input_glyphs.gd:61`); Misc row
  `misc_menu_modal.gd:27,44`, `game_menu.gd:154`. Common Theme variations only; GameUITheme.tres untouched.
- **Fix:** `SampleProject/Scripts/Core/CombatInput.gd:21,39` — `weapon_prev` had no keyboard key; now **Z** (D-28i).

### Where to go next (slice 5, D-28h amended — built)
- `SampleProject/Scripts/Game.gd:490-507` `set_objective(text, target)`, `objective_target`, `objective_marker()`.
- `SampleProject/UI/Components/combat_hud_top.gd:50,59` + `combat_hud_top.tscn` `QuestPanel/Row/Direction` (theme
  variation `QuestTitle`): arrow ← → ↑ ↓ after the objective, hidden within 96 px or when the step has no marker.
- Markers `ObjectiveTargets/<id>` added at the end of `Maps/Canyon.tscn`, `Village.tscn`, `DesertRoad.tscn`,
  `CityGates.tscn`; targets passed in `Canyon.gd`, `Village.gd`, `DesertRoad.gd`, `CityGates.gd`.

### Playtest checklist
- `design/onboarding_plan.md` → "Playtest checklist for Sapega's coworkers" (watch list + after-questions; now also
  asks about the arrow).

### Tests
- `SampleProject/UI/verify_onboarding.gd` (WIP, fixed and extended): [1] keyboard/mouse and [2] gamepad
  (`InputEventJoypadButton`) — each lesson blocks, a wrong move does not pass it, the right button does; banner names
  the device's button. [3] nobody fell, the bandit can be killed after. [4] every topic with `"frames"` has ≥ 6 frames
  and its window shows frame 0 then animates, with a button badge. [5] Misc → Controls by clicks: every action has
  keyboard and pad names, **every gameplay InputMap action is listed** (only `ui_*`, `save_delete` — Load menu, and
  `menu_next_tab` — shares the tab row — are exempt). [6] same page by Start → D-pad → A. [7] every early objective
  names a marker existing in its room (or is a fight / talk / cutscene); the arrow flips sides and hides on arrival.
- `verify_game_menu.gd:83` — ContentRoot now has 9 panels (Controls).

## Decisions (agent calls, Sapega to confirm) — ready to paste

- **D-28a … D-28g** — as written in [[onboarding_plan]] (lessons in the Village street fight; order and done-checks;
  safe fight; lesson = tutorial topic, window then sticky banner; recorded frames; Controls page in Misc; no skip).
- **D-28c (amended)** — During the lessons the hero's and the bandit's health cannot drop below 1
  (`CombatBody2D.min_health`); below 40 % they heal to full. Both end with the last lesson. Agent call, Sapega to
  confirm.
- **D-28h (amended)** — The quest plaque shows an arrow (← → ↑ ↓) toward the current objective's marker
  `ObjectiveTargets/<id>`; the same id at the edge of each room on the route; no arrow for fights, talks, cutscenes;
  hidden within 96 px. "Pursue the kidnappers" points straight at the village gate (the one-line RoadToVillage
  monologue by the bridge may be skipped). Agent call, Sapega to confirm.
- **D-28i** — `weapon_prev` gets keyboard **Z** (was pad-only, D-pad ←); registered in `CombatInput.gd` because
  project.godot is not committable. Agent call, Sapega to confirm.

## New bugs (B-ID text, for the orchestrator to number)

- **B-new-1 — Combat training could kill the bandit (fixed on this branch).** The 40 % heal ran after the blow, so a
  combo finisher from ~45 % killed him mid-lesson and skipped the remaining lessons. Fixed by `min_health`
  (D-28c amended). Found by `verify_onboarding` [2].
- **B-new-2 — `weapon_prev` had no keyboard binding (fixed on this branch, D-28i).** Keyboard players could only
  cycle weapons forward with Q.
- **B-new-3 — `Scripts/Tools/godot_locked.sh` and `run_verify.sh` are not executable in git** (mode 100644).
  `run_verify.sh` calls `godot_locked.sh` directly, so on Linux every test fails with "Permission denied". Not
  fixed here (a mode change is a repo-wide tooling call); fix: `git update-index --chmod=+x` on both, or call
  `bash Scripts/Tools/godot_locked.sh` from `run_verify.sh`. This run used a scratch copy calling it through `bash`
  with a 400 s per-test timeout.
- **Note (not a bug of this branch):** `verify_onboarding` takes ~3–4 min headless (two full lesson runs) — longer
  than `run_verify.sh`'s 180 s timeout per test. See the suite result below.

## Verify runs

| verify | RESULT |
|---|---|
| verify_onboarding | RESULT: ALL PASS |
| verify_village_fight | RESULT: ALL PASS |
| verify_tutorial_hints | RESULT: ALL PASS |
| verify_canyon_exit | RESULT:ALL PASS |
| verify_souls_combat | RESULT: ALL PASS |
| verify_misc_modal | RESULT: ALL PASS |
| verify_game_menu | RESULT: ALL PASS (after the 9-panel count fix) |

Full suite: SUITE_PLACEHOLDER

## What is left

- Settings → Controls (the rebinding table) still lacks a pad column and lists debug actions (plan table row 11) —
  the new Misc → Controls page covers reading; rebinding parity is its own item.
- No window here: the plaque arrow and the Controls page were checked by code, not by eye against Figma (no Figma
  frame exists for either). Capture them locally (`capture_*.gd`) and compare with the HUD Figma `434:6580`.
- The playtest itself (checklist in the plan) — Sapega's coworkers.
- Lesson texts are English only (BACKLOG 31 localises all texts).
- `capture_tutorial_frames.gd` was not re-run (needs a window); all eight sets from the WIP were checked and are real.
