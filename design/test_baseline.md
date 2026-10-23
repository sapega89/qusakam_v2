# Test Baseline — Runtime UI Completion, Slice 0

Recorded 2026-09-27 on `feature/figma-ui-pipeline` at `c2590ea4`, before any
Runtime UI Completion code changes. **Nothing was fixed.** This is the reference
every later slice compares against.

- **Engine:** Godot 4.6.3-stable (official), `Godot_v4.6.3-stable_win64_console.exe`
- **Mode:** headless, Windows 10
- **Suite:** the 17 `SampleProject/UI/verify_*.gd` scripts. There are no GUT tests
  (see below).

## Current state — 2026-10-21

- **Suite:** 69 `SampleProject/UI/verify_*.gd` scripts (`ls SampleProject/UI/verify_*.gd | wc -l`),
  run with `Scripts/Tools/run_verify.sh`. Godot 4.6.2 console build (`/d/Godot/4.6.2`).
- **Last logs (`logs/verify_*.log`, 2026-10-21):** every current script green with 0 SCRIPT ERROR,
  except `verify_souls_combat.log`, which ends mid-run at check [13] with no RESULT line (a run that was
  interrupted, not a recorded failure — re-run it). The flakes of the last runs were fixed (see the run
  notes below). `logs/verify_cutscene_old.log` and `logs/verify_verify_*.log` are leftovers of a deleted
  script and a mistyped glob — ignore them.
- **GUT:** the addon is gone (D240), together with `godot-rapier2d`, `py4godot` and `modal_window`, so
  the old GDExtension and invalid-UID noise is gone too. There are no GUT tests.
- **Known pre-existing issues now: three** — 1 (exit 139), 5 (headless display server), 6 (missing item
  icons). Issues 2, 3 and 4 are closed. Details below.
- **Fixed log:** B74–B80 were fixed and their rows removed from `design/BUGS.md`; look them up with
  `git log --grep "B7[4-9]\|B80"`.

## How to run

```bash
G=/d/reset/projects/sapega/Godot_v4.6.3-stable_win64_console.exe
"$G" --headless --path . --import
for f in SampleProject/UI/verify_*.gd; do
  "$G" --headless --path . --script "res://$f" > "logs/$(basename "$f" .gd).log" 2>&1
done
```

**Read the `RESULT:` line, not the exit code.** Every Godot process for this project
exits with **139 (segfault on shutdown)** — see known issue 1.

**Since 2026-10-16 the suite runs through `Scripts/Tools/run_verify.sh`**, which also fails a
script whose log contains `SCRIPT ERROR`. `RESULT: ALL PASS` alone missed runtime errors in
coroutines: `PlayerCombat.perform_attack` hit `get_tree()` on null after the player left the
tree mid-attack, and no test failed (`verify_combat_flow` [4] now covers it).

## Results

**Latest full run: 2026-10-23, after playtest-1 + ui-kit — `SUITE: ALL PASS`, 93 of 93** (`Scripts/Tools/run_verify.sh` on `7c130aa5`). Watch: in the cloud, under suite load, `verify_audio` (three times, different checks) and `verify_weapon_animations` failed once each and passed alone; never seen locally.

| Script | Result | Notes |
|---|---|---|
| verify_combat_hud | ALL PASS | starting_map error (issue 3) |
| verify_core_wiring | ALL PASS | — |
| verify_equipment | ALL PASS | — |
| verify_full_regression | ALL PASS | starting_map error |
| verify_game_ui_theme | ALL CHECKS PASSED | — |
| verify_hotbar | ALL PASS | — |
| verify_inventory | ALL PASS | — |
| verify_journal | ALL PASS | starting_map error |
| verify_misc_modal | ALL PASS | — |
| verify_pause | ALL PASS | — |
| **verify_responsive** | **1 FAIL** | `logical canvas stays 1920x1080 (got (1868, 1051))` — known issue 2 |
| verify_settings | ALL PASS | `[SettingsModule] Invalid settings data, using defaults` (local settings file) |
| verify_skills | ALL PASS | — |
| verify_skills_combat | ALL PASS | — |
| verify_skills_ui | ALL PASS | — |
| verify_status | ALL PASS | — |
| verify_world_map | ALL PASS | — |

**16 / 17 pass, 1 failure.**

GUT (`-s addons/gut/gut_cmdln.gd`): **runs zero tests.** No `tests/` or `test/`
folder exists, and both gutconfig files point to missing directories. `CLAUDE.md`'s
"154 tests (100% pass)" is stale (Q13).

## Known pre-existing issues

These are baseline noise. A later slice is only responsible for **new** entries.

1. **Segfault on shutdown (exit 139).** It happens on a plain
   `--headless --path . --quit` of this project, after "ServiceLocator: Cleaned up".
   It is project-level and not caused by the tests. The import step shows
   `_exit_tree` script errors in `MetSysPlugin.gd:81` and `gut_plugin.gd:123`
   (`menu_manager` on Nil). Not investigated further. (2026-10-21: neither error appears in the
   current logs; GUT is gone, D240. The exit 139 itself remains.)
2. ~~**`verify_responsive` canvas check fails headless**~~ — **closed 2026-10-12** (see below): the window reports 1868×1051
   instead of 1920×1080. Probably environment-dependent (the headless window size),
   but unconfirmed. All other responsive checks pass.
   **Root cause (slice 8):** not flaky — the maaacks menus addon saves the window size to
   `%APPDATA%/New Game Project/player_config.cfg` (`[VideoSettings] ScreenResolution`) and applies it on
   every start, headless included. 1868×1051 was a window size saved on this machine earlier; windowed
   capture runs overwrite it. The test passes when the saved value is 1920×1080. Capture scripts now
   restore the previous window size; if the test fails with an odd size, reset that value.
   **Resolved 2026-10-12:** the check measured the *window* (`root.size`), which the
   saved setting overrides. It now measures the logical `canvas_items` canvas
   (`root.get_visible_rect()`), which stays 1920×1080 at any window size — the test
   passes with the odd saved size and no config reset is needed.
3. ~~**`Cannot resolve starting_map to scene ref`**~~ — **not noise, it was a bug; fixed
   2026-10-12.** The save wrote `current_room_scene_path` by gluing the map folder to the
   MetSys room name (`res://SampleProject/Maps/:uid`), loading could not resolve it and
   silently started in Canyon. Loading now uses `current_room`. If this line reappears,
   it is a regression — not baseline.
4. ~~**Missing GDExtension binaries**~~ (`py4godot`, `godot-rapier2d`) — **closed:** both addons were
   removed in D240.
5. **Headless-only:** thousands of `Not supported by this display server`
   (`keyboard_get_keycode_from_physical`) — about 3,700 across the 2026-10-21 logs. Not an issue in a windowed run.
6. **Missing item icons:** `ItemDatabase: Icon file does not exist for item ...` for items whose icon path
   points into `res://release/assets/textures/ui/items/...` (iron_ingot, iron_sword, copper_sword,
   leather_armor, iron_armor, iron_ore, copper_ingot, leather, ...) — icons not exported yet (D5, partly
   closed by D128). The old `potion.png`, `modal_window` and MetSys `Exquisite` invalid-UID warnings no
   longer appear (D240 / D128).

Also seen at shutdown in every run, part of issue 1: `ObjectDB instances leaked at exit` and
`N resources still in use at exit`.

## Final comparison — after Runtime UI Completion slice 8

| | Baseline (slice 0) | After slice 8 |
|---|---|---|
| Verify scripts | 17 | 23 (+ interaction, save_load, main_menu, shop, blacksmith, game_over) |
| Passing | 16 | **23** |
| verify_responsive | 1 FAIL (saved window size) | passes with `ScreenResolution=1920×1080` — see issue 2 |
| New errors | — | none beyond the known issues above (missing item icons D5 add warnings in shop tests) |

Known issues 1, 3, 4, 5 and 6 are unchanged.

## Full run — 2026-10-21, after BACKLOG 22 skill trees (D279–D285)

`Scripts/Tools/run_verify.sh`: SUITE ALL PASS. New: `verify_skill_trees` (data, points, oath, passives, save, respec,
cap 99), `verify_skill_trees_ui` (tabs by mouse and pad, double click learns — B77), `verify_oath` (the City keepers by
pad and key). `verify_kusakam_skills` now expects one point per level (D279), `verify_skills_ui` fixtures use `oath`.

## Full run — 2026-10-21, after BACKLOG 26 audio (D274–D278)

`Scripts/Tools/run_verify.sh`: 51 / 55 PASS; the 4 FAILs were this pass's own regressions and are fixed, each re-run
alone to ALL PASS: `verify_blacksmith`, `verify_enchanting` (NpcBase named the `AudioManager` autoload — test scripts
compile NpcBase before autoloads; now `get_node("/root/AudioManager")`), `verify_canyon_exit` (the cloud reported
"typed" one letter before its typing returned, so an Enter was swallowed), `verify_npc_recall` (its test NPC had no
`character_id` for the greeting). New: `verify_audio` (81 checks).

## Full run — 2026-10-18, after the combat fixes (B57–B64)

`Scripts/Tools/run_verify.sh` on `feature/backlog`, Godot 4.6.2 console build, headless:
**45 / 45 PASS, 0 SCRIPT ERROR** (the count of scripts is `ls SampleProject/UI/verify_*.gd`; it grows).

The run before the fixes, same day: 44 pass, `verify_settings` HUNG — B63/B64 (the in-game
Settings → Exit to Main Menu did nothing, and its stale screen stayed in `UIRoot`).

New coverage: `verify_combat_flow` [0] spawn on the floor and moving with the room, [0b] enemy
passes through the player (D197), [1] one hit = one damage event, [1b] a miss, [1c] the hit equals
Phys. Atk. and grows with the weapon (D199), [2b] invulnerability frames, [2c] enemy wind-up /
facing / height / no friendly fire (D198); `verify_map_geometry` [5] every spawn point stands on a tile.
