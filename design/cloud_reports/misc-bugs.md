---
type: cloud-report
branch: cloud/misc-bugs
date: 2026-10-22
---
# Cloud report: misc bugs (B91, B92, B93, B94, B107, B108)

Branch `cloud/misc-bugs`, cut from `origin/feature/backlog`. Godot 4.6.2, Linux, headless (plus xvfb for one scratch render).
Every row was checked against the current code before it was fixed. All six still applied. B93 turned out to need more than the row's fix, see below.

## B rows

| Row | State |
|---|---|
| B92 | **fixed** |
| B91 | **fixed** (two frames, because `Raise/2` does not exist) |
| B94 | **fixed** |
| B107 | **fixed** |
| B108 | **fixed** (agent call, see D-new below) |
| B93 | **partly fixed, keep it open**: the explicit type went in, but the `Area2D` workaround is still needed |

## What changed

### B92: a `Cutscene` whose game goes away ends itself
- **Reproduced first.** The new `verify_cutscene` [4] starts the Canyon descent, quits to the main menu the way `game_menu._on_exit_confirm_closed` does (`close_state`, `show_title_screen`, `change_scene_to_file(MainMenu)`), then starts a new game (`start_new_game`, `Game.tscn`). Before the fix the run ended with `handle_crash: Program crashed with signal 11` (exit 134) once the new game's `Canyon_Intro` started. The skip prompt also stayed on `root` (`FAIL the skip prompt left with its game`).
- `SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd:45` connects `player.tree_exiting` to `_abandon` (`:161`). `_abandon` sets `_abandoned`, queue-frees the prompt (root is in the middle of removing the game, so `free()` errors there), then `_release()`. `_release()` (`:167`) kills the shake, disconnects `_hold_later` from `DialogueManager.dialogue_started`, shows the hidden HUD layers again and clears the list, and sets `Engine.time_scale = 1`. `end()` disconnects `_abandon` first, keeps `_prompt.free()` (the comment explains why), then calls the same `_release()`.
- `say()` (`:74`): after `await dialogue_finished`, if `_abandoned` it returns. Without this, the same dialogue path in the next game (for example quitting during the intro and starting again) would break the loop and call `hold()` on the freed hero.
- `SampleProject/UI/verify_cutscene.gd:188-213` [4]: the prompt is gone and the speed is 1.0 in the main menu, the new game's first dialogue starts (counted via `dialogue_started`, because the intro is a bubble that never shows as `is_dialogue_active`), and the intro ends with the HUD back and control returned. `:215-217` [5]: in that new game the City Gates raid is played and then skipped, through the whole `_play_and_skip` check (HUD hidden, then back, prompt gone, speed 1, same end state).

### B91: the hero raises the found item
- `SampleProject/Player.tscn:40-41`: ext resources `raise1` and `raise3`. `:544` adds `Animation_raise` ("Raise", 0.2 s, not looping): `Raise/1` (reach down), then `Raise/3` (arms overhead) from 0.15 s on, held. It is in the default library next to `RESET`.
- **`Raise/2.png` is not in the repo.** `fc8c850b` deleted it after three failed generations (the Player README says so). Only its stale `Raise/2.png.import` is left. The animation therefore goes 1 → 3. If `Raise/2` lands later, it slots in as a key between the two.
- `SampleProject/Scripts/Gameplay/Chest.gd:15-17`: `HERO_POSE := &"Raise"`, with an updated comment.
- `SampleProject/UI/verify_chests.gd:16-17, 112-113`: the pose check uses `assigned_animation` (a finished non-looping animation clears `current_animation`) and also checks that the sprite shows `Raise/3`.
- Scratch render (not committed): with the `Found` offset (0, -72) the icon sits just above the open hands of `Raise/3`, centred. No offset change was needed.

### B93: explicit type in `Game.teleport_to_room`, but the workaround stays
- `SampleProject/Scripts/Game.gd:390`: `var old_room_instance: Node = MetSys.get_current_room_instance()`.
- **The row's expectation still fails.** I typed the doors in `verify_village_house` as `RoomDoor`. Before the change it hit the documented Parse Error. After the change compilation goes further and stops at `Compile Error: Identifier not found: MetSys` (`Game.gd:91`). When a `--script` test is compiled, the scene autoloads are not registered yet, so every bare `MetSys.` in `Game.gd` fails. That makes any `class_name` that reaches `Game` unusable from a verify's top-level types. The `Area2D` typing in `verify_village_house.gd:9-10` therefore stays, and its comment now gives the real reason.
- Suggested new row text for B93: "Got: … after the explicit type, `Identifier not found: MetSys` (scene autoloads are not registered when a `--script` compiles). Fix: either keep tests off `class_name`s that reach `Game`, or have `Game.gd` reach MetSys through a typed accessor. Severity: tests only."

### B94: the verify_audio focus tick
- `SampleProject/UI/verify_audio.gd:272-276`: stop `ButtonFocusedAudioStreamPlayer`, `grab_focus()`, then check `has_focus() and playing and bus == SFX` right away, without waiting a frame. `play()` runs synchronously from `focus_entered`, and one frame later the short tick may already have finished, which was the flake. Stopping the player first means an earlier tick cannot make the check pass.
- **10 runs in a row: 10 × `RESULT: ALL PASS`.**

### B107: Ether says SP
- `SampleProject/Resources/Data/items.json:392`: "Restores 30 SP.". The msgid is renamed in `en.po:1853-1854` and `uk.po:1854`; the Ukrainian text already said "Відновлює 30 SP.".

### B108: the potion line ascends
- `items.json:322-337` / `:356-371`: Potion and Lesser Potion swap their whole stat block: heal, buy and sell price, and description (rarity is the same). The line is now Lesser 50 (20/10) < Potion 75 (40/20) < Medium 125 (70/35) < Hi 200 (100/50). No new numbers were added. The descriptions keep their existing msgids.
- `crafting_recipes.json:322-350`: the chain follows. `craft_potion_lesser_chain` (id kept; its unshown name is now "Craft Potion") turns 2 Lesser into 1 Potion, and Medium takes 4 Potion. Before, 2 Potion made 1 Lesser, which only made sense while Lesser was the stronger one.
- `verify_use_item.gd`: [1]/[2] now expect a 75 HP potion (20 → 95, 10 → 85 → 100). The new [7] (`:128-139`) checks that heal, buy and sell rise strictly along the line, that each description says what the potion heals, and that Ether says SP.

## Decisions (agent call, Sapega to confirm)
- **D-new (B108):** the healing line ascends Lesser Potion (Мале зілля, 50 HP, buy 20 / sell 10) < Potion (Зілля, 75, 40/20) < Medium Potion (Середнє, 125, 70/35) < Hi-Potion (Велике, 200, 100/50). Potion and Lesser Potion swapped their values, prices and descriptions, and no new numbers were invented. The alchemy chain follows: 2 Lesser → Potion, 4 Potion → Medium, 8 Medium → Large. *(agent call, Sapega to confirm)*
- **D-new (B91):** the chest pose `Raise` is `Raise/1` → `Raise/3` held (0.15 s, then hold), with no `Raise/2` because that frame does not exist. *(agent call, Sapega to confirm)*
- **D-new (B92):** a cutscene ends with its hero. On `player.tree_exiting` it disconnects from DialogueManager, removes the skip prompt, resets `Engine.time_scale` to 1 and shows the HUD it hid. A dialogue in a later game never resumes it. *(agent call, Sapega to confirm)*

## Notes for the orchestrator
- `SampleProject/Sprites/Player/Raise/2.png.import` is a stale sidecar for a deleted frame. I left it alone (art pipeline).
- `--import` on Linux rewrites `addons/maaacks_menus_template/base/translations/*` (an import artefact). I reverted that and did not commit it.

## Test results
- verify_use_item: `RESULT: ALL PASS`
- verify_shop, verify_locale: `RESULT: ALL PASS`
- verify_village_house: `RESULT: ALL PASS`
- verify_audio ×10: `RESULT: ALL PASS` ×10
- verify_chests: `RESULT: ALL PASS`
- verify_cutscene: `RESULT: ALL PASS` (before the fix: signal 11 in [4])
- Full suite (`Scripts/Tools/run_verify.sh`), first run at `ea7f692f`+B92: **86 PASS, 2 FAIL**: `verify_game_ui_theme` (expected until the theme is regenerated) and `verify_combat_flow` (`RESULT: ALL PASS` + 1 SCRIPT ERROR from `Cutscene._abandon` at program exit, fixed in `b44e2eff`). Reruns on the final code: pending.
