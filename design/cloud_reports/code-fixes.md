---
type: report
status: done
tags: [cloud, code, 4b, bugs]
---

# Cloud report — `cloud/code-fixes` (2026-10-22)

Branch `cloud/code-fixes` from `origin/feature/backlog` @ `d3a29c64`. Covers [[remaining_work]] → Code 2, 3, 4 and 6
(the portraits; the tutorial topic screenshots are still open), plus B42, B4 and GitHub #29. Decisions D388–D391 are agent
calls for Sapega to confirm ([[figma_decision_register]]).

## 1. Boss telegraph (D388)

The problem: both bosses inherited `default_enemy.tscn`'s Sprite2D meta `tell_at = (3, −26)`, which is the bandit's sword
position, so the glint floated beside the boss. A charge also drew no ground line, because `lunge` is 0 for bosses.

- `Scripts/Gameplay/Components/EnemyView.gd:87` `weapon_point()` now uses the meta `tell_at_<assigned_animation>` when
  the scene has one, otherwise `tell_at`. It uses `assigned_animation` because the one-key pose clips (`charge`,
  `slam`…) end immediately and leave `current_animation` empty.
- `Scenes/Characters/Bosses/brass_collector.tscn`: `tell_at` (0, −46) is the raised sweep fist, `tell_at_charge` (24, 3)
  and `tell_at_slam` (20, −40). `fire_djinn.tscn`: `tell_at` (−11, 2) is the drawn-back claw, `tell_at_fireball`
  (16, −37) and `tell_at_pillar` (17, −18). All points were measured on the frames shown at tell time.
- `Scripts/Gameplay/DefaultEnemy.gd:244` adds `_on_logic_attack_telegraphed()`, which replaces the inline lambda.
  `Scripts/Gameplay/Characters/Bosses/BossEnemy.gd:74` overrides it. A `charge` draws the red chevron line over
  `distance + melee_reach` (450 px for the Brass Collector).
- `fire_djinn.tscn` AnimationPlayer `metadata/attack_strike_time = 0.3`. The djinn's strike frame starts at 0.3 s, but
  the inherited 0.4 made the claws strike one frame before the tell ended.
- Shots: `design/shots/fb9_2_{brass_tell_sweep,brass_tell_charge,brass_tell_slam,djinn_tell_claws,djinn_tell_fireball,djinn_tell_pillar}.png`,
  taken with `capture_bosses.gd` under xvfb. Software rendering is slow enough to skip the 0.25 s tell, so the capture
  slows time during the wind-up and freezes it for the shot. Every glint sits on the weapon of the pose shown.

## 2. Attack cooldowns on game time (D388)

- `EnemyLogic.gd:56` `attack_ready_in` replaces `last_attack_time` and the wall clock. `:140` counts it down by the
  physics delta. `:321` starts an attack when it reaches 0.
- `BossLogic.gd:60` `_rest()` sets `attack_ready_in = attack_cooldown`, still counted from the end of the move.
- `ArcherLogic.gd:29` works the same way with `enemy.attack_cooldown`.
- A physics delta of 0 under hitstop (`time_scale` 0) and no physics while paused mean the countdown waits in both
  cases. `verify_bosses`, `verify_archer`, `capture_bosses` and `capture_bow` now set `attack_ready_in` instead of
  `last_attack_time`.
- New check in `verify_bosses` `_game_time_cooldown`: the cooldown holds for 0.6 s at time_scale 0 and for 0.6 s
  paused, then the next move comes.

## 3. `verify_souls_combat` [0] flake (D389)

Root cause: this was not a lock, and the test's timing was not the problem either. Instrumented over 6 × 12 s:

- Every "stuck" second (< 100 px) contained a designed finisher stagger of about 0.6 s (D264, `st5` for 28–36 frames)
  plus its 50 px push. In those frames the hero has no control by design.
- I found no stagger chains: no re-stagger inside a running stagger, and the i-frames are 0.5 s.

The fix is in the test: `UI/verify_souls_combat.gd:175`. Movement is now measured only in frames where the hero is not
staggered. A second counts as stuck only if he was free for at least 0.25 s of it and moved slower than 150 px/s while
free. The measured minimum free speed was 337 px/s. A real freeze (event lock, mover lock) still reads 0. The check is
now `stuck_seconds == 0` (the old limit was ≤ 2).

**10 runs after the change: 10 × `RESULT: ALL PASS`** (staggered 0.5–1.6 s of 12 per run, 0 stuck seconds).

## 4. Bugs

- **B42**: removed the dangling `10_objective` ext_resource from `Game.tscn` and deleted
  `Scenes/UI/ObjectiveHUD.tscn` and `Scripts/UI/ObjectiveHUD.gd(.uid)`. `combat_hud_top` replaced them long ago.
  - The root guard: `UI/verify_scripts_compile.gd:18` `_unused_ext_resources()` now fails on any ext_resource that no
    `ExtResource("id")` uses, in any .tscn or .tres (185 files). Before the deletion it reproduced exactly B42; after,
    it returns ALL PASS.
- **B4**: `UI/verify_misc_modal.gd:126` now asserts that the running Game is still `current_scene` and in the tree
  (it was `current_scene == null or true`). The source-grep [6] Tutorial and [7] Exit checks are removed:
  `verify_misc_destinations` [5] and [6] press those buttons for real. Both are ALL PASS.
- **GitHub #29**: `NpcBase._on_task_chosen()` ran `open_tasks()[0]` whatever row was chosen.
  - `Scripts/Gameplay/NPCs/NpcBase.gd:108` `quest_rows()` returns `{id: "task:<id>", label: title, main}`, and there
    is one **Quest** entry per NPC.
  - `:179` `_on_quest_chosen()`: with one row, its talk starts at once; with several, a list opens in the same NPC
    menu. `:198` `_on_task_chosen(task_id)` runs the chosen task.
  - `StoryNpc.gd:22` puts the main quest first with the gold diamond (`npc_action_menu.gd:16` `DIAMOND`,
    `UITokens.ACCENT`). Its label is the current zone title (D188, `GameFlow.gd:115` `current_zone_title()`).
  - The `ponytail:` comment is gone. D390.
  - Tests: `verify_tasks` [4] covers a two-task fixture where choosing the second row takes the second task, and [5]
    covers old man + tasks with the main row first and the diamond only on it. `verify_npc_recall` now uses the real
    Quest id.
  - The list itself has no capture against Figma: Figma is only reachable from the laptop, and 164:1302 / 176:1357 show
    only the single menu.

## 5. Journal Characters portraits (D391)

- `Scripts/Systems/journal_records.gd:56` makes `people()` carry the DialogueQuest character's `portrait`.
- `Scenes/Menus/Game/journal_component.tscn` gets `PortraitBackground` (`PanelContainerForeground`) with `Portrait`
  (128 px, nearest filter), the same as in the dialogue box, at the top of the detail column.
- `journal_component.gd:306` shows it, and hides the frame when a person has no art.
- Test `verify_journal_sections` [2] checks that the grandfather's portrait is the dialogue one. [6] checks that the
  villager gets no frame and that going back to the grandfather shows his portrait again.
- Shot: `design/shots/fb13_characters_portrait.png`.

## Results

| Test | RESULT |
|---|---|
| verify_bosses | ALL PASS |
| verify_archer | ALL PASS |
| verify_souls_combat ×10 | ALL PASS ×10 |
| verify_scripts_compile | ALL PASS (fails before the B42 fix, as intended) |
| verify_misc_modal / verify_misc_destinations | ALL PASS / ALL PASS |
| verify_tasks / verify_npc_recall / verify_blacksmith / verify_shop | ALL PASS ×4 |
| verify_journal_sections / verify_journal / verify_story_journal | ALL PASS ×3 |

**Full suite `Scripts/Tools/run_verify.sh`: 86 PASS, 1 FAIL**, `SUITE: 1 FAIL`. The one failure is
`verify_game_ui_theme`, which is expected until Sapega regenerates the theme. It reports "every button focus is the
shared ring (off: FilterButton, MainMenuItem, … NpcMenuItem, ShopRow…)", which comes from his local `GameUITheme.tres`
edits and not from this branch.

## Notes

- Not committed, per the rules: `project.godot`, `MainMenu.tscn`, `GameUITheme.tres`, `playthrough.gd`.
- One extra commit: the five `gen_front.png.import` files for the A5a foreground planes. Godot generated them on import;
  the art commit `d3a29c64` left them out and the repo tracks `.import` files.
- Still open, not touched:
  - **B111**: enemy tempo ignores `EnemyStats.attack_cooldown`; needs Sapega's call.
  - The tutorial topic screenshots.
  - The party panel shows a purple placeholder square for Kusakam's portrait (visible in `fb13_characters_portrait.png`);
    this is pre-existing.
