---
type: report
status: done
tags: [cloud, settings, save]
---

# Cloud report — `cloud/settings-store` (2026-10-22)

**Summary.** B118 is fixed. Settings are now one file per install, `<save_dir>/settings.sav` (`user://saves/settings.sav` in the game; tests use their own folder).
- It is written on every Settings change and on Restore, and read once at boot before the Main Menu. Slot files and `Game.save_game()` no longer carry `game_settings`. There is no old-save branch: a `game_settings` block left in an old slot is ignored.
- **Proposed D-ID (agent call, for Sapega to confirm):** *D-S4 — Settings storage. Settings belong to the install, not to a save slot: one file `user://saves/settings.sav`. It is written on every Settings change and on Restore Default Settings, and read once at boot before the Main Menu. Slot files never carry settings. Switching, loading or deleting a slot never changes them. A `game_settings` block in an old slot is ignored.*
- **B rows fixed:** B118 (remove the row).
- **Not changed:** no new Settings rows (that is `cloud/settings-2`'s job).
- **Full suite:** `SUITE: ALL PASS` (93 scripts).

## Calls made
- **File name: `settings.sav`, not `settings.json`.** The content is `var_to_str`, the same format as the slot files. JSON would bring `fps_limit` back as a float (`60.0`), which breaks the typed comparisons and `module.settings == changed`.
- **Boot.** `SaveSystem._ready()` reads the file into `SettingsModule` right away (`SettingsModule.read()`, values only), so anything in the Main Menu's `_ready` already sees the stored values. Applying them (`apply_settings`) is still deferred to the end of the frame, because AudioManager, DisplayManager and LocalizationManager are autoloads loaded after SaveSystem.
- **Switching slots no longer reloads settings.** `set_current_slot()` used to call `load_game_settings()`; it no longer does.
- **`set_save_dir()` does not re-read the settings.** A test that needs a restart calls `load_game_settings()`, which is the same read followed by an apply.

## What changed
- `Scripts/Systems/SaveSystem.gd`:
  - `SETTINGS_FILE`, `get_settings_path()`, `save_game_settings()` (writes the file), `_read_settings_file()` (`{}` when there is no file, which means defaults), `load_game_settings()`.
  - The `game_settings` mirror variable and `_read_slot()` are gone.
- `Scripts/Systems/Save/Modules/SettingsModule.gd`: `read(data)` merges the data over the defaults; `load_data` is now `read` + `apply_settings`.
- `Scripts/Game.gd`: `save_game()` no longer writes `game_settings`.
- Tests:
  - `verify_settings.gd`:
    - `[9]` is now *B118: a change with no slot save at all survives a restart*. It checks that all 4 slots are empty, that the change wrote the settings file by itself, that no slot file was created, and that the value comes back after a reload.
    - `[22]`: the Auto-Save stub is created there, and a new check asserts that the slot file carries no settings.
    - `[22b]`: the settings file already holds every change without a `save_game_settings()` call from the test, and the restart reads that file.
    - `[22c]`: Restore writes the defaults to the settings file.
    - The test folder is cleared at the start, so an aborted earlier run cannot leave saves behind.
  - `verify_settings_graphics.gd [6]` reads the settings file instead of the slot.
  - `verify_save_load.gd`, `verify_damage_numbers.gd`: the slot stubs no longer carry or need settings.
  - Comments updated in `verify_locale.gd` and `verify_tutorial_hints.gd`.
- `design/settings_plan.md`: the open item in slice 1 is marked built.

## Results
- `verify_settings`, `verify_settings_graphics`, `verify_save_load`, `verify_save_load_room`, `verify_damage_numbers`, `verify_tutorial_hints`, `verify_locale`, `verify_main_menu`: `RESULT: ALL PASS`.
- Full suite: `SUITE: ALL PASS`.
- Limit: the "restart" in the tests is `load_game_settings()` inside the same process. The boot path (`read` in `_ready` + deferred apply) runs at the start of every test, but no test starts a second process to read the file back.
