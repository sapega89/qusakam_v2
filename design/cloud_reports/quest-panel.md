---
type: report
tags: [cloud, routines, ui, hud]
branch: cloud/quest-panel
date: 2026-10-26
---

# Cloud report: quest-panel (D717, the HUD quest panel shows briefly)

**Summary.** D717 is built on `cloud/quest-panel`. The branch starts from `cloud/hints-toggle` a4ebe201 and merges its later head bd99e1dd.
The quest panel at the top of the HUD shows when the objective changes or the hero enters another location (`LocationDB`), stays `UITokens.OBJECTIVE_PLAQUE_HOLD` (5 s), then fades out. Leaving a menu or a dialogue no longer brings it back, and neither does a room change inside the same location.
It never shows during a dialogue or a cutscene (`Player.event`). If a show is asked for during one, it waits for the end. If a dialogue starts while the panel is up, the panel hides at once.
The HUD had no location-name element, so nothing was removed. A test checks that none appears. The Journal still shows the full quest (`verify_objective_plaque` [4]).
**D-ID:** D717 (register text unchanged; "Built by routine `hints-toggle`" → `quest-panel`). **B rows fixed:** none.
**Full suite:** `SUITE: 7 FAIL` on 7b5cb081. After merging hints-toggle's head, `verify_lab_cells` and `verify_audio` are ALL PASS. The 5 left are hints-toggle's ui-critic baseline failures, not from this branch.
**MASTER_PLAN** §3: row QP1 / D717 👀 → `integrator`.
**ID clash for the orchestrator:** ui-critic's report also used D717, for the hint banner placement, which D726 has since removed. The register's D717 is this quest-panel decision. ui-critic's banner D717 needs another number or should be dropped.

## What changed

- `SampleProject/UI/Components/combat_hud_top.gd`
  - Removed: the reshow on the pause → play edge (`_was_paused`) and on `EventBus.dialogue_finished`.
  - New: `_on_room_loaded()` (`Game.room_loaded`) compares `LocationDB.of_scene(map)` with the last location and shows only when it changed. The first room only records the location, because the objective shows the panel anyway.
  - New: `_story_holds_screen()` (dialogue active, or `player.event`), `_plaque_pending`, `is_plaque_pending()`. `_on_frame()` hides a visible panel while the story holds the screen, and shows a pending one after.
- `SampleProject/UI/verify_objective_plaque.gd`: [2] and [3] are rewritten for D717; [3b] and [3c] are new.
- `SampleProject/UI/capture_quest_panel.gd` (new) → `design/shots/quest_panel_d717.png`: the top 360 px of the HUD, with the panel (top) and after it faded (bottom).
- `design/MASTER_PLAN.md` §3: row QP1 / D717.
- Godot's import also produced `.import`/`.uid` files for assets added by earlier routines. They are committed separately.

## Tests

`verify_objective_plaque` — **RESULT: ALL PASS** (on the merged head fcb3ac17):
- [1] a new objective shows the panel; it fades after ≥ HOLD s and the objective stays set.
- [2] Esc and pad Start open and close the Game Menu with no panel during or after.
- [3] An objective set mid-dialogue does not show and waits (`is_plaque_pending`). No panel on any dialogue line. It shows after the dialogue ends. A dialogue starting while it is up hides it at once. A talk with no objective change brings nothing back.
- [3b] Canyon → DragonMural (same location): hidden, nothing pending. → GatehouseCellar (city): shown with the objective, faded after ≥ HOLD s. → BanditCamp (back to the canyon): shown. → DragonMural: hidden.
- [3c] No `Label` under `Game/UICanvas` holds any `locations.json` name.
- [4] The Journal lists the objective as a current sub-row (unchanged).

Also green: `verify_combat_hud`, `verify_onboarding`, `verify_responsive`, `verify_lab_cells`, `verify_audio`.

Room choice in the test: entering LaboratoryOutside sets "Finish the demo" and holds the hero, so the panel correctly waited there; CityGates changes the objective. GatehouseCellar and BanditCamp change neither, so they test the location rule alone.

## Full suite

`Scripts/Tools/run_verify.sh` on 7b5cb081: **SUITE: 7 FAIL**.
- `verify_lab_cells`: fixed by hints-toggle bd99e1dd. ALL PASS after the merge.
- `verify_audio`: hints-toggle saw it fail on its baseline too. ALL PASS on a rerun after the merge (flaky).
- The other five are the same ones listed in `hints-toggle.md` (ui-critic baseline) → `integrator`:
  - `verify_dialogue_speaker`: hangs; `DialogueQuest` compile error.
  - `verify_gamepad_parity`: 1 FAIL.
  - `verify_npc_arrival`: 10 FAIL; parse errors in `Arrow.gd`/`PlayerCombat.gd`.
  - `verify_save_load_room`: no RESULT line.
  - `verify_tasks`: 1 FAIL.

## Shot

`design/shots/quest_panel_d717.png`: top, the panel «Active Quest — Return to the village» right after the objective was set; bottom, the same HUD after it faded. Only the hero panel, the potion slot, the coins and the menu button stay. Neither half has a location name.
