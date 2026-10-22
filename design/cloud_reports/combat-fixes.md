---
type: report
tags: [cloud, combat, input]
---

# cloud/combat-fixes

**Summary**
- **B116 fixed:** `PlayerCombat._track_combat` now ends the fight on the spot when the hero is held (`player.event`: cutscene, dialogue, chest) or dead. There's no `COMBAT_LINGER` and nothing special-cased in MayorHall, so the weapon is sheathed and the room track comes back. B116 row: remove.
- **Input moved:** the actions from `CombatInput.gd` and `SkillScreenInput.gd` are now in `project.godot` → `[input]`. Both scripts, their `.uid` files and the two preloads in `GameManager._initialize` are deleted. Keys, buttons, event order and deadzones are unchanged.
- **D-ID text (proposed):** *D4xx — Cutscenes and defeat are not fighting: a held (`event`) or dead hero leaves combat at once (weapon sheathed, battle track off). Combat and Skills-screen input actions live in `project.godot`.*
- **Full suite:** `SUITE: 1 FAIL` (93 scripts). The one failure is `verify_audio` ("the hero hurt → hero_hurt_voice"). It passed 4 out of 4 runs on its own, and that line is in the damage path, which this branch doesn't touch. I treat it as a timing flake under suite load.

## B116 details
- `SampleProject/Scripts/Player/Components/PlayerCombat.gd:261`: `if player.event or player.is_dead: _combat_left = 0.0`.
- Cause, traced with temporary prints:
  - **Win:** the last swing (`SWING`) restarted the 3 s linger, and it was still running during the victory talk.
  - **Loss:** the collector is `PROCESS_MODE_DISABLED` but still alive with `is_attacking = true`, so `_enemy_engaged()` stayed true for the whole cutscene.
- `verify_mayor_hall`: `_room_music_back` now expects the hall's own Music within 1 s, plus `not in_combat()` and `weapon_view.sheathed` (win and lose). Without the fix: `RESULT: 4 FAIL`. With it: `RESULT: ALL PASS`.
- `verify_lab_boss`: the same check on the weapon, and the wait for the music cut from 8 s to 1 s → `RESULT: ALL PASS`.
- Side effect: a dialogue or chest started mid-fight also sheathes the weapon. When control comes back and an enemy is still chasing, the hero draws again.

## Input details
- New in `project.godot`:
  - `heavy_attack`: RMB / R / pad B
  - `block`: L Ctrl / MMB / pad LB
  - `cutscene_skip`: Tab / pad Y
  - `skills_accept`: F / pad Y
  - `skills_unpick`: Backspace / pad X
  - All five keep deadzone 0.5.
- Added to existing actions:
  - `skill_slot_1..4` get the pad events RT (axis 5, value 1.0), R3, L3 and Back. Deadzone stays 0.2.
  - `weapon_prev` gets Z, after D-pad ←.
- Written by Godot itself (`ProjectSettings.save()` from the runtime InputMap). The diff only adds lines.
- One difference: events registered in code had `device` 0, and they now use `device` -1 (all devices), like every other event in the file. A second gamepad now triggers them too.
- Notes updated: `souls_combat_plan.md` item 8 and `skill_screen_rework_plan.md` (Hotbar row). Older reports and the decision register still mention `CombatInput.gd` as history.
- Green: verify_gamepad, gamepad_parity, combat_flow, souls_combat, skill_screen, skills, skills_ui, skills_combat, skill_casts, kusakam_skills, skill_trees, skill_trees_ui, settings (Controls tab), cutscene, hotbar.
