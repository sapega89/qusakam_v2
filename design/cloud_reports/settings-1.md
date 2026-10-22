---
type: report
status: done
tags: [cloud, settings, gamepad]
---

# Cloud report — `cloud/settings-1` (2026-10-22)

**Summary.** Both parts are built.
- **#100 / [[settings_plan]] slice 1:** Display Mode has a third value, **Borderless**. There is a new **Game → Auto-Save** row (On/Off, default Off, D413). `verify_settings.gd [22]` covers every row: change → applied → restart round trip → Restore. **Not fixed:** settings live in the slot file, so with no save in the last-used slot a change does not survive a restart (proposed B-row below).
- **#36 / [[gamepad_plan]] slice 1b (D417):** the cursor is hidden in play and **Alt** (`toggle_mouse`, now in `project.godot`) shows or hides it. Menus, pauses and modals always show the cursor, and closing them restores the Alt state. While the cursor is hidden, the GUI gets no clicks and no hover, and LMB still attacks. The test is `verify_mouse_cursor.gd`.
- New D-IDs (agent calls, for Sapega to confirm): **D-S1** (Borderless), **D-S2** (Auto-Save trigger), **D-S3** (cursor rules). The text is below.
- B rows fixed: none. One B row is proposed (settings without a save).
- Full suite: **90 PASS / 3 FAIL** on the first run. All 3 failures came from this branch's own changes, so I fixed them and re-ran those 3: ALL PASS, which makes **93/93**. I did not run the whole suite a second time.
- Untouched, as asked: Resolution, Frame Rate Limit, Brightness, Ambient, Text Speed, Screen Shake. Note: Resolution and Frame Rate Limit **already exist** on feature/backlog (BACKLOG 41, `verify_settings_graphics.gd`). #52 / D418 may need only a check, not a build.

## D-ID text for the orchestrator

| ID | Type | Text |
|---|---|---|
| D-S1 | GAP | **Borderless as built** (#100, [[settings_plan]] slice 1; agent call). The settings key `display_mode` (`windowed` / `fullscreen` / `borderless`) replaces the bool `fullscreen`. Fullscreen = `WINDOW_MODE_EXCLUSIVE_FULLSCREEN`; Borderless = `WINDOW_MODE_FULLSCREEN` (Godot's borderless window covering the screen). Both run at the screen's native resolution, and the Resolution row is disabled in both. On load, an old `fullscreen` key is dropped, so a slot saved in fullscreen opens windowed once. |
| D-S2 | GAP | **Auto-Save trigger** (#100, D413; agent call). Settings → Game → Auto-Save, key `auto_save`, default Off. When On, every room change (`EventBus.room_entered`) saves through the same `Game.save_game()` a SavePoint uses. The first room after a new game or a load is not a transition and is not saved. Off → saving stays manual at a SavePoint. |
| D-S3 | GAP | **Cursor rules as built** (#36, D157 → D417; agent call). The cursor is forced visible while the tree is paused, a UIManager state is open or a modal is up; Alt is ignored then and the play state is kept. `toggle_mouse` is keyboard & mouse only: a pad never moves the cursor, so it has no pad event and is exempt from pad parity. It is rebindable in Settings → Controls as "Show / Hide Cursor" and is not listed on Misc → Controls. |

## Proposed B row
**Settings do not survive a restart when the last-used slot has no save.** `SaveSystem.save_game_settings()` (`Scripts/Systems/SaveSystem.gd`, `if not FileAccess.file_exists(slot_path): return true`) writes settings only into an existing slot file. A fresh install that changes the language or volume from the Main Menu and quits loses the change. This fails the plan rule for every row. Fixing it means moving settings out of the slot into one global file (e.g. `user://saves/settings.json`), which touches `Game.save_game`, `SaveSystem` and 6 tests. That is a storage-design change, so I did not make it in this slice. Recommendation: global settings, one file; slot files stop carrying `game_settings`.

Also: **Restore Default Settings** does not reset keybinds. Controls has its own per-device **Reset** (D397), so I left it as is.

## What changed
- `Scripts/Systems/DisplayManager.gd`: `DISPLAY_MODES`, `set_display_mode()`, `display_mode` (the last applied value, readable in headless), `is_windowed()`. `set_fullscreen` / `is_fullscreen` / `fullscreen_changed` are replaced by `display_mode_changed`.
- `Scripts/Systems/Save/Modules/SettingsModule.gd`: the `display_mode` and `auto_save` keys; the legacy `fullscreen` key is erased on load; the unused `toggle_fullscreen()` is removed.
- `Scripts/Menus/Game/options_component.gd`: Display Mode has 3 cells; Resolution is enabled only in Windowed; new Auto-Save row and `_on_auto_save_changed`; the Game tab hint mentions auto-save.
- `Scripts/Systems/SaveSystem.gd`: `_connect_scene_events()` (it was an empty stub) now connects `EventBus.room_entered` to `_on_room_entered()`.
- `Scripts/UI/mouse_cursor.gd` + `Scenes/UI/mouse_cursor.tscn` (`process_mode` Always, a `Shield` CanvasLayer at layer 128 with a full-rect `Blocker`, `MOUSE_FILTER_PASS`). The scene is instanced by `Game._ready()`. `_exit_tree` restores `MOUSE_MODE_VISIBLE` for the Main Menu.
  - Why a shield: Godot computes hover (`mouse_entered`) from the stored mouse position *before* `_input`, so filtering events in `_input` stopped clicks but not hover focus (tried first, failed `[3]`). The PASS shield takes hover and clicks without marking them handled, so `Player._unhandled_input` still attacks.
- `project.godot`: `toggle_mouse` = physical Alt. `input_options_menu.tscn`: the action is listed as "Show / Hide Cursor".
- `en.po` / `uk.po`: "Borderless" / «Без рамки», "Auto-Save" / «Автозбереження», "Show / Hide Cursor" / «Показати / сховати курсор», and the new Game-tab hint. **The Ukrainian strings are drafts for Sapega to review.**
- Tests:
  - `verify_settings.gd`: `[6]` now expects 3 modes; new `[22]`/`[22b]`/`[22c]` cover every row, a restart round trip (module reset to defaults, then `load_game_settings()`), and Restore, including Auto-Save writing / not writing the slot.
  - `verify_mouse_cursor.gd` (new).
  - `verify_full_regression.gd`: "Borderless" is no longer in the deferred list.
  - `verify_gamepad_parity.gd`: `MOUSE_ONLY = [toggle_mouse]`.
  - `verify_onboarding.gd`: `NOT_GAMEPLAY` gets `toggle_mouse`.
- `capture_settings.gd`: `-- --tabs=… --prefix=…` and tutorial windows off.
- Plans updated: [[settings_plan]] (slice 1 ✅), [[gamepad_plan]] (slice 1b ✅ as built).

## RESULT lines
- `verify_settings` — RESULT: ALL PASS
- `verify_mouse_cursor` — RESULT: ALL PASS
- `verify_gamepad_parity`, `verify_onboarding`, `verify_full_regression` — RESULT: ALL PASS after the fixes above
- `verify_locale`, `verify_damage_numbers`, `verify_settings_graphics`, `verify_gamepad`, `verify_save_load` — PASS in the full run
- Full suite (first run): `SUITE: 3 FAIL` → the three listed above, now fixed.

## Shots
`design/shots/settings1_display.png` (Display: Windowed / Fullscreen / Borderless) and `design/shots/settings1_game.png` (Game: Language, Tutorial Windows, Damage Numbers, Auto-Save), 1920×1080 under xvfb. The new cell and row reuse the existing `SettingsSegment` / `SettingsSegmentOn` styles and the 68 px choice row. There was no Figma MCP in this session, so I compared against the existing settings shots and [[settings_mapping]] only. Figma 17:280 and 17:632 already show these rows, so I am not raising a Q.
