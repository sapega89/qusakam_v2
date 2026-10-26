---
type: report
tags: [cloud, routines, ui, tutorial]
branch: cloud/hints-toggle
date: 2026-10-26
---

# Cloud report: hints-toggle (Sapega's four notes on hints, 2026-10-26)

**Summary.** All four notes are done on `cloud/hints-toggle` (from `cloud/ui-critic` 4e957a5e). They override ui-critic's D719 and parts of D717/D718.
1. The combat training is gone. The first Village fight is an ordinary fight. Three «?» tips explain the white, yellow and red glints. 2. The hint banner window is gone, and every tip is a «?».
3. Every tip shows once per playthrough. That holds after a room reload, a death, a load of an earlier save or a new session; New Game starts fresh. 4. **Settings → Game → Hints** On/Off (default On) is one gate in `TipTray.show_tip`.
**D-IDs:** D725, D726, D727, D728 (text below). **B rows fixed:** none new. UC1/B151's banner no longer exists (D726).
**Full suite:** `SUITE: 6 FAIL` (116 PASS). verify_lab_cells was mine and is fixed (now ALL PASS); the other 5 also failed on the ui-critic baseline, so they are not from this branch.
**Touched verifies:** all green (list below). **MASTER_PLAN** §3: rows HT1–HT4 👀 → `integrator`.
**For integrator:** `cloud/elder-home` conflicts in `Village.gd`, and its new `ElderHouse.gd` still calls the removed hint window. Steps are under "Merging with elder-home".

## D-IDs for the register (orchestrator applies them)

| ID | Kind | Text |
|---|---|---|
| D725 | OVERRIDE (supersedes D-28a…D-28d, D503, D719) | **No combat training; the glint colours are «?» tips.** Sapega, 2026-10-26: «прибрати тренування бою, ну максимум знову ж таки знаки питання, щоб пояснити, що таке жовте свічення і червоне свічення у ворога». The Village street fight is an ordinary fight. The bandit can fall, the objective is "Defeat the bandit in the street" from the start, and nothing waits for lessons. `CombatTraining.gd`, the `lesson_*` topics, their en/uk texts, the `prompt` field and "Learn to fight: follow the lesson" are removed. The `training_<lesson>_done` flags of old saves stay in the save but gate nothing, so a save made during or after the training loads into the plain fight. New tutorial topics `tell_block` "White Glint", `tell_parry` "Yellow Glint" and `tell_dodge` "Red Glint" (D504: white can be blocked, yellow parried, red only dodged) each give one line. They name the button from the input map (`{block}`, `{dodge}`, so for example "Hold Ctrl / Middle Mouse", "Tap … just as it lands", "Dodge it with Shift"), in en and uk, with the existing block, parry and dodge frames. Each fires the first time an enemy **in view** (on screen) shows that colour: `TutorialManager` listens to `EventBus.enemy_tell_shown`, which normal enemies and bosses emit. |
| D726 | OVERRIDE (supersedes D717, amends D718 and D289) | **The tutorial hint window is gone; every tip is a «?».** Sapega, 2026-10-26: «і те, що можна щось вдягнути — тому вікно підказки прибрати взагалі, перенести все в туторіали». Removed: `Scenes/UI/TutorialHintDisplay.tscn`, `Scripts/UI/TutorialHintDisplay.gd`, the `tutorial_hint_display` group, the `TutorialBanner` theme style, the `HINT_BANNER_*` tokens and the banner tests (B151 [6]). Every tip goes through **`TipTray.show_tip(id)`** (`UI/Components/tip_tray.gd`, instanced in `Game.tscn` → `UICanvas/TipTray`, group `tip_tray`). That covers movement (WASD, 2 s after entering the game), attack, first kill, heavy attack, block, level up, the three glints, Healing Palm, the grandfather's gift ("Equipping Gear", the «you can equip this»), calling the guard, companions and choosing companions. Each keeps its text and trigger. A tip that asks for an action waits as a «?» until done, then `retire(id)` removes its «?» (gift equipped, Healing Palm learned, guard called or the fight over). The tray now also opens the tutorial window on a «?» (pause, unpause on close), which was `TutorialHintDisplay.open_tip`. There is no banner and no "essential" exception. The Settings → Game → Tutorial Windows row is replaced by Hints (D728). |
| D727 | OVERRIDE (amends D289 "once per game") | **Each tip once per playthrough, at its first occasion.** Sapega, 2026-10-26: «тільки один раз за гру це вискакує, коли перший раз зустрічається, так само і WASD». One record: `player_state.seen_tutorials` (the existing D289 list, saved by `PlayerDataModule`) plus a new **`playthrough_id`**. New Game creates the id and it is saved with the slot; saves from before D727 get one on their next save. `Game._initialize_save_and_room()` snapshots the record before `reset_player_state()`. After loading a save, `TutorialTopics.carry_over()` merges back the snapshot if it is the same playthrough (death → Resume, Load of an earlier save in the same run). It also merges the `seen_tutorials` of every slot of that playthrough (`SaveSystem.seen_tutorials_of`), for a new session loading an earlier save. A room reload never resets it. New Game gets a new id and an empty list. **Limit:** a tip seen in a session that was then quit without any save (no save point, Auto-Save off) is not on disk, so after a restart it can show once more. |
| D728 | GAP (new setting) | **Settings → Game → Hints On / Off.** Sapega, 2026-10-26: «якщо вимкнені підказки, то підказок не має бути, і туторіал з питаннями теж не вискакує». Figma is not reachable from the cloud. The row takes the place of Tutorial Windows in the Game tab (Language, Text Speed, Screen Shake, **Hints**, Damage Numbers, Auto-Save), the same `_add_segment_row` On/Off component. Labels are en "Hints" and uk "Підказки"; the tab's footer text is updated. It is stored by `SettingsModule` as `hints`, default `true`, and the stale `tutorial_windows` key is dropped on read. The one gate is `TipTray.show_tip`: with Off it shows no «?» and marks nothing seen. Interaction prompts («E Open», NPC menus), quest and story text and the Tutorial list in the menu stay. Switching it Off mid-game clears the waiting «?» (`call_group(&"tip_tray", &"clear")`). Switching it On shows tips from then on, with no flood. A tip whose occasion passed while Off was never marked seen, so it shows at its next occasion. |

## What changed (files)

- Removed: `Scripts/Gameplay/CombatTraining.gd` (+uid), `Scenes/UI/TutorialHintDisplay.tscn`, `Scripts/UI/TutorialHintDisplay.gd` (+uid).
- `UI/Components/tip_tray.gd`: the single delivery. It has `show_tip` (Hints gate, `mark_seen`), `retire`, `clear`, `open_tip`, and the movement trigger.
- `Game.tscn`: `UICanvas/TipTray` (group `tip_tray`) replaces `TutorialHintDisplay`.
- `Scripts/Managers/TutorialManager.gd`: all triggers go to `show_tip`; new `_on_enemy_tell_shown` (in-view check).
- `Scripts/UI/tutorial_topics.gd`: `snapshot` / `carry_over`; the `prompt` field is gone.
- `Scripts/Game.gd:172,200`: snapshot and carry-over around the load.
- `Scripts/Systems/SaveSystem.gd`: `seen_tutorials_of(playthrough_id)`.
- `PlayerStateManager.gd` (`playthrough_id`), `PlayerDataModule.gd` (save/load it).
- `SettingsModule.gd` (`hints`), `options_component.gd` (Hints row, `_on_hints_changed`, footer text).
- `Resources/Data/tutorial.json` (−4 lessons, +3 glint topics), `en.po`/`uk.po` (via `po_sync.py`), `data_fields.json`.
- `UITokens.gd`, `build_game_ui_theme.gd`, regenerated `GameUITheme.tres` (−`TutorialBanner`), `verify_game_ui_theme.gd`.
- `Scripts/Gameplay/Scenes/Village.gd` — **kept small** (−26/+5): no training, `_start_fight` sets the plain objective, the gift tip is `show_tip` / `retire`, and the `_exit_tree` that hid the banner is gone. `CityGates.gd`, `LabCells.gd`: `show_tip` / `retire`.
- Tests and captures: 119 `verify_*`/`capture_*` lines changed `settings.tutorial_windows = false` to `settings.hints = false` (no «?» in that run). The ones that check a tip use the tray: `verify_companions` [10], `verify_city_gates_raid` [5], `verify_kusakam_skills` [2b], `verify_starter_loot` [3], `verify_village_fight` [6]. `capture_ui_critic` lost its lesson shot; `capture_ui_text` shoots a «?» instead of the banner; `capture_game_menu_batch` opens the «?» with T.

## Tests (RESULT lines, this session, Godot 4.6.2 headless)

| verify | what it covers | RESULT |
|---|---|---|
| `verify_village_fight` | D725: the first fight has no training, objective "Defeat the bandit in the street" at once, the bandit has no HP floor and falls to real damage, the story goes on (old man, gift); a save flag `training_lesson_attack_done` changes nothing | ALL PASS |
| `verify_tips_once` (new) | WASD «?» once; white/yellow/red glints in view → their «?» once, buttons from the input map; off-screen glint → none; room reload, save + death → Game Over → Resume, Load of an earlier save, a new session → nothing comes back; New Game → fresh | ALL PASS |
| `verify_tutorial_hints` (rewritten) | movement and attack as «?» (no banner), stacking, T / D-pad / click open (with Alt for the cursor, D417), Tutorial list; Hints Off by mouse clears waiting «?», a kill + three glints + level-up give no «?» and mark nothing, a chest's «Open» prompt still shows, Off survives a settings save and load, On again → no flood, new occasion shows; every hint topic en+uk: a «?» and none of its text on screen; only `tutorial_menu.gd` resolves topic text; the old window's scene, script and group are gone | ALL PASS |
| `verify_onboarding` (training parts removed) | frames in tutorial windows (now incl. the glint topics), Controls page, objective arrow | ALL PASS |
| `verify_settings` | Hints row in Game, default On, no Tutorial Windows; Off stored, survives the restart round trip, Restore puts it back | ALL PASS |
| `verify_companions`, `verify_city_gates_raid`, `verify_kusakam_skills`, `verify_starter_loot`, `verify_locale`, `verify_game_ui_theme` | tips through the tray; new keys en/uk; theme without `TutorialBanner` | ALL PASS |

Capture: `design/shots/hints_toggle_game.png` (Settings → Game, 1920×1080, `capture_settings.gd -- --tabs=game --prefix=hints_toggle`).
The Hints row sits between Screen Shake and Damage Numbers. It uses the same On/Off segment style, with On selected.

## Full suite

`Scripts/Tools/run_verify.sh` on this branch: **SUITE: 6 FAIL**, 116 PASS.
- `verify_lab_cells` — mine (the test turned hints off and then checked the picker tip). Fixed afterwards: hints on, and it checks the «?»; it now gives **ALL PASS**.
- The other five also failed on ui-critic's head, 4e957a5e (baseline run here before any change of mine: 8 FAIL, incl. `verify_onboarding`, `verify_tutorial_hints` and `verify_audio`). They are not this branch's, and they go to `integrator`:
  - `verify_dialogue_speaker` — hangs; Compile Error `Identifier not found: DialogueQuest` in `dqd_parser.gd:172` (test preloads before autoloads).
  - `verify_gamepad_parity` — 1 FAIL.
  - `verify_npc_arrival` — 10 FAIL around D454/D721 (ui-critic's NPC menu) and `Arrow.gd`/`PlayerCombat.gd` parse errors at compile time.
  - `verify_save_load_room` — Godot aborts in `DialogueManager._play_bubbles` (DialogueManager.gd:355), no RESULT.
  - `verify_tasks` — 1 FAIL (the task list).
- `verify_audio` failed on the baseline and passed here.

## Merging with elder-home (for integrator)

`git merge-tree` of this branch with `origin/cloud/elder-home` conflicts only in `Scripts/Gameplay/Scenes/Village.gd`:
- the constants block: keep `OLDMAN_GIFT`/`HEALING_LIGHT` only if elder-home still uses them in Village, and drop `const CombatTraining`.
- the gift block: elder-home moved the gift to `ElderHouse.gd`, so take elder-home's side (removed).

Then convert `Scripts/Gameplay/Scenes/ElderHouse.gd` (elder-home) to D726:
- line 166 `…group(&"tutorial_hint_display").show_hint(OLDMAN_GIFT, true, true)` → `get_tree().get_first_node_in_group(&"tip_tray").show_tip(OLDMAN_GIFT)`.
- lines 173 and 188 (`current_hint == OLDMAN_GIFT` → `force_hide()`) → `…group(&"tip_tray").retire(OLDMAN_GIFT)` in the equip handler, and drop the `_exit_tree` hide.

After the merge, run `git grep -n "tutorial_hint_display\|show_hint\|tutorial_windows\|CombatTraining\|lesson_"`. Any test line `settings.tutorial_windows = false` becomes `settings.hints = false`.

## Not done / notes

- Figma is not reachable from the cloud, so the Hints row was not compared with frame `17:632`. It reuses the existing segment row; check it on the PC.
- `CombatContextDisplay` (narrative lines when entering a `CombatZone`) is not a tip and no room instances a `CombatZone`. Left as is.
- The D727 limit is above: a tip seen and never saved can show once more after a restart.
- ui-critic's other untested work: its baseline on this machine, before my changes, was 8 FAIL. Six of those are not this routine's and are listed in the full-suite section.
