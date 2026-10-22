---
type: report
tags: [cloud, settings]
branch: cloud/settings-2
---

# Cloud report — settings-2 (GitHub #52, D418)

**Summary.** Done: Resolution now lists only the sizes the monitor fits, and Frame Rate Limit already matched D418. Text Speed, Screen Shake, Ambient and Screen Brightness are built. Every row changes at once, survives a restart and is put back by Restore (`verify_settings` [3], [22]).
New D-IDs: **D425** (Text Speed), **D426** (Screen Shake), **D427** (Ambient), **D428** (Brightness), **D429** (Resolution list as built). The text of each is below. They are provisional numbers, so the orchestrator may renumber them.
B rows fixed: none (no B row was open for these rows).
The **Ukrainian strings are drafts for Sapega**: Швидкість тексту / Звичайна / Швидка / Тряска екрана / Звуки довкілля / Яскравість екрана / ТЕМНО / СВІТЛО, plus the two longer hints.
The compass icon on the preview swatches is drawn by Claude (`settings_compass.svg`); Figma was not reachable.
Full suite: SUITE_LINE

## D-ID text (for `figma_decision_register.md`)

| D-ID | Kind | Text |
|---|---|---|
| D425 | GAP | **Text Speed: Default / Quick** (#52; agent call, Sapega to confirm; `cloud/settings-2`). Key `text_speed` (`default` / `quick`), default Default; `SettingsModule.TEXT_SPEEDS = {default: 1.0, quick: 2.0}`. Quick doubles everything: the dialogue box types 48 letters/s instead of 24 (D254; `GameDialogueBox._process` runs the addon's typing clock ×2, so `[speed]` tags stay proportional); a D178 cloud line holds 1 s + 0.025 s/char, max 3 s, instead of 2 s + 0.05 s/char, max 6 s (monologues and NPC chatter); a D263 cloud talk types ×2. D254 "cannot be skipped until fully shown" is unchanged. The setting is read at each line, so a change in the pause menu applies from the next line. |
| D426 | GAP | **Screen Shake On / Off** (#52; agent call, Sapega to confirm). Key `screen_shake`, default On. Off = no camera movement from hits (`VFXHooks._kick_camera`: hero hit, hit landed, parry) and none from cutscene shakes (`Cutscene.shake`: Mayor Hall wall burst, Lab cells shout / explosions / quake). Gamepad rumble, hit-stop, flashes and the hurt vignette are not screen shake and stay. |
| D427 | GAP | **Ambient volume** (#52; agent call, Sapega to confirm). Key `ambient_volume` 0.0–1.0 (shown 0–100), default 1.0, on the existing Ambience bus. 100 = the bus's mix in `default_bus_layout.tres` (−6 dB), so the default sounds as before. Ambience still sends into SFX, so Sound Effects scales it as well (D274). |
| D428 | GAP | **Screen Brightness, one mechanism** (#52; agent call, Sapega to confirm). Key `brightness` 0–100, default 50 (no change). One place: `DisplayManager.tscn → BrightnessLayer` (CanvasLayer 127: above the HUD, menus, modals and transitions at ≤ 100, below the mouse cursor at 128) with one full-screen `ColorRect` and the `Shaders/brightness.gdshader` gamma over the screen texture. Gamma = 2^((b − 50) / 50): 0 → 0.5 (darker), 100 → 2.0 (brighter). Black stays black and white stays white; there is no per-scene code. At 50 the layer is hidden, so it costs nothing. Under the row are two preview swatches, a compass on near-black (DARK) and a compass on near-white (BRIGHT), each barely visible (`UITokens.SETTINGS_PREVIEW_*`). They sit under the same layer, so they show the live result. |
| D429 | GAP | **Resolution list as built** (D418, #52; agent call). The row lists only the D418 sizes that fit the current screen (`DisplayManager.available_resolutions` / `resolutions_for_screen`). 1280×720 is always offered. Headless (no screen) gets the full list. A saved size larger than the screen (game moved to a smaller monitor) opens at the largest size that fits, and the saved value is kept, so a larger screen gets it back. The row is disabled in Fullscreen and Borderless (D420). |

## What changed

- `Scripts/Systems/Save/Modules/SettingsModule.gd`: keys `ambient_volume`, `brightness`, `text_speed`, `screen_shake`; `TEXT_SPEEDS`, `text_speed_factor()`, `screen_shake_enabled()`.
- `Scripts/Systems/DisplayManager.gd` + `Scenes/Systems/DisplayManager.tscn` + `Shaders/brightness.gdshader`: `set_brightness`, `BrightnessLayer/Brightness`; `available_resolutions`, `resolutions_for_screen`, `fitted_resolution`; `set_resolution` applies the fitted size.
- `Scripts/Systems/AudioManager.gd`: `set_ambient_volume` / `get_ambient_volume` relative to the layout's Ambience mix.
- `Scripts/UI/GameDialogueBox.gd` (`_process`), `Scripts/Systems/DialogueManager.gd` (cloud typing, monologue and chatter line time): Text Speed.
- `Scripts/Systems/VFXHooks.gd` (`_kick_camera`), `Scripts/Systems/Cutscenes/Cutscene.gd` (`shake`): Screen Shake.
- `Scripts/Menus/Game/options_component.gd` (+ `.tscn` `TabIcons/compass`): Display gets Screen Brightness (stepper slider, 68 px like the other Display rows) and the DARK / BRIGHT preview; Audio gets Ambient; Game gets Text Speed and Screen Shake (Figma order: Language, Text Speed, Screen Shake, then Tutorial Windows, Damage Numbers, Auto-Save). The Resolution stepper steps through the fitted list. Tab hints are updated.
- `UI/Tokens/UITokens.gd`: `SETTINGS_PREVIEW_*`. The theme is not touched, so it needs no regeneration.
- `Resources/Translations/uk.po` / `en.po` (via `po_sync.py`): 8 new keys and 2 changed hints.
- `design/settings_plan.md`: rows marked built, slices 3–4 marked done.

## Tests

- `verify_settings`: [3] now checks that the once-deferred rows are present on their tabs (it used to check they were absent). [22] adds Brightness 80 (gamma 2^0.6, layer visible, above layer 100), the preview swatches, Ambient 40 (bus below −13 dB), Text Speed Quick (the dialogue box types 48 letters in 1 s instead of 24; a 40-letter cloud line lasts 2 s instead of 4 s), and Screen Shake On/Off (a real `_kick_camera` moves or does not move the game camera). [22b] reloads and checks each of these is re-applied. [22c] checks Restore brings back Brightness 50 (layer hidden), Ambient 100, 24 letters/s and the kick. `RESULT: ALL PASS`.
- `verify_settings_graphics`: [2] adds Screen Brightness to the Display row order. [8] is new and tests the monitor cut (2560×1440 → 4, 1920×1080 → 3, 1366×768 and 1024×768 → 1280×720 only; the row matches this screen). `RESULT: ALL PASS`.
- `verify_full_regression` [7]: the four rows left the "forbidden" list.

## Shots

`design/shots/settings2_display.png`, `settings2_audio.png`, `settings2_game.png`, `settings2_controls.png` (xvfb 1920×1080; Resolution shows 1920 × 1080 and the list there has 3 sizes). Not compared against Figma because Figma was not reachable from the cloud. The preview swatch size (208×96) and the compass are my own choices, to be checked against `brightness-preview-container` in 17:280.
