---
type: report
tags: [cloud, routines, ui]
---

# Cloud report rows-3: Settings row templates (#50 order 6)

**Summary.** Order 6 `options_component` of [[game_menu_single_scene_plan]] is done the D423 / D426 way. That was the last screen of "Slices 2+" (D117), and the plan's table marks it done. Every row still works. The after captures of all four tabs match the before ones pixel for pixel; only the PLAYTIME clock in the top right changed.
Not done: nothing from the task. The Controls tab is the Maaacks addon widget, which was left as it is (it was never our rows).
**D-ID text (next free number, D432 at the time of writing; orchestrator applies):** | D4xx | TECH | **Settings rows are scene templates** (D117, #50 order 6; agent call, Sapega to confirm; `cloud/rows-3`). Sidebar: `%Tab` (Pointer + Button) in `Sidebar`, filled by `RowFill.fill()`. The list mixes row kinds in a fixed order, so its templates sit in a hidden `RowTemplates` holder: `%SegmentRow` (cells are filled from `Cell0` by `RowFill`), `%StepperRow`, `%SliderRow`, `%Separator` and `%BrightnessPreview` (DARK / BRIGHT swatches). Each list row is a copy of its template and is rebuilt as before, so focus is restored by path. New theme types: `SettingsRow`, `SettingsSeparator`, `SettingsControlGroup`, `SettingsSegmentCells`, `SettingsPreviewColumn`, `SettingsPreviewDark` / `SettingsPreviewBright`, `SettingsValueDisabled` (Resolution outside Windowed). New token: `SETTINGS_READOUT_WIDTH`. `options_component.gd` has no `.new()`. |
**B rows fixed:** none (this is #50 / D117 work, no B-ID).
**Full suite:** `Scripts/Tools/run_verify.sh` → `SUITE: 1 FAIL` (92 PASS + `verify_audio`). The one failure is the known flake from `test_baseline.md` (it fails under suite load). `verify_audio` does not touch Settings, and it passed 2 of 2 re-runs on its own on this branch.

## What changed (`82c0ec09`)
- `SampleProject/Scenes/Menus/Game/options_component.tscn`
  - `%Tab` in `Layout/Sidebar` (`:47`).
  - Hidden `RowTemplates` (`:164`) holds the row templates. Sizes are written in the scene as in D426, and `verify_settings` [12] checks them against the tokens.
  - `TabIcons/Pointer` and `TabIcons/compass` are gone: the templates hold those textures now.
- `SampleProject/Scripts/Menus/Game/options_component.gd`
  - `_build_sidebar` (`:77`) uses `RowFill`.
  - `_copy` (`:229`) and `_make_row` (`:236`) copy a template.
  - `_add_segment_row` (`:248`) fills the cells with `RowFill`.
  - `_add_stepper_row` (`:264`), `_add_slider_row` (`:306`) and `_add_brightness_preview` (`:324`) only fill in and wire the copies.
  - Removed: 15 `X.new()` nodes, the `StyleBoxFlat` for the swatches, the `StyleBoxLine` for the separator and the colour override for the disabled stepper value.
  - Row names and paths are unchanged (`<Label>Row/<Label>/Segments/Cells/CellN`, `Stepper/Prev|Value|Next`, `Slider/Minus|Value|Plus|Readout`, `BrightnessPreview`), so every test that reads rows by path still works.
- `SampleProject/UI/build_game_ui_theme.gd`
  - `_settings_rows` (`:350`).
  - The `SettingsValueDisabled` label role (`:208`).
  - `GameUITheme.tres` was regenerated, and `verify_game_ui_theme` reports `ALL CHECKS PASSED`.
- `SampleProject/UI/Tokens/UITokens.gd:169`: `SETTINGS_READOUT_WIDTH := 36`. It replaces a literal that was in the script.
- `SampleProject/UI/verify_settings.gd:469`: new checks that the script has no `.new()` and that the template sizes match the tokens (17 OK).
- `design/game_menu_single_scene_plan.md`: order 6 is marked ✅.

## Tests (RESULT lines, before → after)
- verify_settings: ALL PASS → ALL PASS
- verify_settings_graphics: ALL PASS → ALL PASS
- verify_mouse_cursor: ALL PASS → ALL PASS
- verify_locale: ALL PASS → ALL PASS
- verify_game_ui_theme: ALL CHECKS PASSED → ALL CHECKS PASSED
- Also read the Settings rows, after the change: verify_damage_numbers ALL PASS, verify_gamepad_parity ALL PASS.

## Shots
- `design/shots/rows_3_before_{display,audio,game,controls}.png` and `rows_3_after_*.png`, taken with `capture_settings.gd -- --prefix=…` under xvfb at 1920×1080.
- `design/shots/rows_3_before_after.png`: before | after side by side, four tabs.
- `compare -fuzz 6%` finds a difference in only one box per tab, at about x 1614–1640, y 104–130: the PLAYTIME clock (00:00:28 → 00:00:31).
