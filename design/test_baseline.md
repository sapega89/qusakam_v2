# Test Baseline — Runtime UI Completion, Slice 0

Recorded 2026-09-27 on `feature/figma-ui-pipeline` at `c2590ea4`, before any
Runtime UI Completion code changes. **Nothing was fixed.** This is the reference
every later slice compares against.

- **Engine:** Godot 4.6.3-stable (official), `Godot_v4.6.3-stable_win64_console.exe`
- **Mode:** headless, Windows 10
- **Suite:** the 17 `SampleProject/UI/verify_*.gd` scripts. There are no GUT tests
  (see below).

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

## Results

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
   (`menu_manager` on Nil). Not investigated further.
2. **`verify_responsive` canvas check fails headless:** the window reports 1868×1051
   instead of 1920×1080. Probably environment-dependent (the headless window size),
   but unconfirmed. All other responsive checks pass.
3. **`Cannot resolve starting_map to scene ref: res://SampleProject/Maps/:dbq66sndnfrq7`**
   (`Game.gd:274`): the MetSys starting map is stored as a UID that doesn't resolve.
   Appears in scripts that boot `Game.tscn`.
4. **Missing GDExtension binaries:** `addons/py4godot/python.gdextension` and
   `addons/godot-rapier2d/godot-rapier2d.gdextension` fail to load in every run
   (68 `FileAccess::exists` + 68 load errors across the suite).
5. **Headless-only:** 960 × `Not supported by this display server`
   (`keyboard_get_keycode_from_physical`). Not an issue in a windowed run.
6. **Warnings:** a missing `potion` icon
   (`res://release/assets/textures/ui/items/jrpg_icons/potion.png`, 94×), and invalid
   UIDs in `addons/modal_window/default_window.tscn` and the MetSys `Exquisite`
   theme (17× each; Godot falls back to text paths).
