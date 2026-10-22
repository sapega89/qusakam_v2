---
type: plan
status: built
figma: "settings-display 17:280 · settings-audio 17:409 · settings-gameplay 17:632 · settings-controls 17:756"
---

# Settings — how every option must work

2026-10-16. Spec for **behaviour**, row by row: what pressing it does, what is saved,
what a test checks. Layout and Figma mapping stay in [[settings_mapping]].
Decisions this rests on: D66 (build every Figma row), D121 (English first),
D190 → **D193** (keyboard and pad are separate tabs).

Rule for every row: **the change is visible at once, survives a restart, and Restore
Default Settings puts it back.** A row that cannot do all three is not shipped.
Persistence is `SettingsModule.settings` (`Scripts/Systems/Save/Modules/SettingsModule.gd:8`),
except keybinds (maaacks `app_settings.gd`).

## Display — `17:280`

| Row | Must do | Today |
|---|---|---|
| Display Mode | Windowed / Fullscreen / Borderless (D66). Window switches at once. | ✅ 2026-10-22 (`cloud/settings-1`): key `display_mode` = windowed / fullscreen (exclusive) / borderless (Godot `WINDOW_MODE_FULLSCREEN`). Still does nothing when embedded in the editor's Game tab — Godot ignores window-mode requests there. |
| Resolution | Window size from a list; disabled in Fullscreen. | ✅ D418 values; 2026-10-22 (`cloud/settings-2`): the list is cut to what the monitor fits, disabled in Fullscreen and Borderless (D420), a saved size larger than the screen opens at the largest that fits (D429). |
| VSync | On/Off → `DisplayServer.window_set_vsync_mode`. | ✅ works; has no visible effect except tearing/FPS. |
| Frame Rate Limit | `Engine.max_fps` from a list. | ✅ D418: 30 / 60 / 120 / 144 / Unlimited, default 60. |
| Screen Brightness | 0–100 stepper slider, applied to the world and UI; DARK/BRIGHT preview swatches. | ✅ 2026-10-22 (`cloud/settings-2`, D428): key `brightness` (default 50); one gamma shader on `DisplayManager/BrightnessLayer` (layer 127) over world and UI; DARK / BRIGHT compass swatches under the row. |

## Audio — `17:409`

| Row | Must do | Today |
|---|---|---|
| Master / Music / Sound Effects | 0–100, bus volume at once. | ✅ |
| Ambient | 0–100 on an Ambient bus. | ✅ 2026-10-22 (`cloud/settings-2`, D427): key `ambient_volume` on the Ambience bus, on top of its −6 dB mix; Sound Effects still scales it too (D274). |

## Game — `17:632`

| Row | Must do | Today |
|---|---|---|
| Language | Switches UI and Journal text at once (D194); dialogue stays Ukrainian for now. | ❌ **switches nothing.** `TranslationServer.set_locale()` runs (`LocalizationManager.gd:60`), but `project.godot:167` registers only the maaacks en/fr translations; `Resources/Translations/uk.po` is not registered and holds 14 strings; UI is English literals (D121), `.dqd` dialogue is Ukrainian only. |
| Text Speed | Default / Quick: dialogue box typing speed and bubble line time (D178, D192). | ✅ 2026-10-22 (`cloud/settings-2`, D425): key `text_speed`; Quick = ×2 (48 letters/s; cloud lines 1 s + 0.025 s/char, max 3 s). |
| Screen Shake | On/Off; off = no camera shake. | ✅ 2026-10-22 (`cloud/settings-2`, D426): key `screen_shake`; Off stops `VFXHooks._kick_camera` and `Cutscene.shake`; rumble stays. |
| Auto-Save | On/Off, default Off (D413): a room change saves the game with `Game.save_game()`. | ✅ 2026-10-22 (`cloud/settings-1`): key `auto_save`, `SaveSystem._on_room_entered`; the first room after a start or load is not a transition. |
| Damage Numbers | On/Off. | ✅ built 2026-10-22 (D408, `cloud/combat-stats`), default On. |

## Controls — `17:756`

Two tabs (D193, [#98](https://github.com/sapega89/qusakam_v2/issues/98)):
**Keyboard & Mouse** accepts only keys and mouse buttons; **Gamepad** accepts only pad
buttons/axes. Each lists every action; rebinding a slot listens to that device only;
Reset restores that tab. Today: one mixed list, a pad slot offers the mouse, mouse buttons
cannot be assigned (`key_assignment_window.gd:67-76` treats mouse input as non-confirming),
the scrollbar is too faint to see (#79).

## Decisions required

1. ~~Q55~~ → **D194:** Language switches UI + Journal now (EN/UK), `.dqd` dialogue stays Ukrainian for now.
2. ~~Resolution list and Frame Rate Limit list — **GAME DESIGN DECISION REQUIRED** (values).~~ → **D418** (2026-10-22).
3. Screen Shake, Damage Numbers, Brightness, Ambient need their systems first; each gets its own plan.

## Slices

### Slice 1 — honest Display and Game rows — ✅ built 2026-10-22 (`cloud/settings-1`, report [[settings-1]])
- `DisplayManager` + `SettingsModule`: Borderless as a third Display Mode value.
- Auto-Save row + `auto_save` key.
- Language (D194): wrap every UI literal in `tr()`, extract to `Resources/Translations/{en,uk}.po`, journal texts from
  `story.json` too; register both in `project.godot` `locale/translations`. Who writes the Ukrainian UI strings is
  Sapega's call — draft them marked for review.
- `verify_settings.gd`: every row → change → value applied → restart round trip → Restore. ✅ `[22]`.
- ✅ B118 (`cloud/settings-store`): settings are one file per install, `<save_dir>/settings.sav`, written on every
  change and on Restore, read once at boot; slot files carry no settings. `[9]` covers a change with no slot save.

### Slice 2 — Controls split (D193, #98) — ✅ built 2026-10-22 (D397, `cloud/ui-bugs`)
- Keyboard & Mouse / Gamepad tabs over the maaacks list; device filter on rebinding; mouse buttons accepted.
- `verify_settings.gd` [controls]: a pad slot ignores keys and mouse, a keyboard slot accepts a mouse button.

### Slice 3 — Text Speed — ✅ built 2026-10-22 (`cloud/settings-2`, D425, report [[settings-2]])
- One speed key read by the dialogue box typing (`GameDialogueBox._process`) and `DialogueManager._play_bubbles` / chatter.

### Slice 4 — rows that needed a system — ✅ built 2026-10-22 (`cloud/settings-2`, D426–D429)
Brightness, Ambient bus, Screen Shake, Resolution fit; Damage Numbers (D408), Frame Rate Limit (BACKLOG 41) earlier.
`verify_settings` [3], [22] cover every row; `verify_settings_graphics` [8] the monitor cut.

## Order

1 → 2 → 3; 2 and 3 are independent. 4+ waits on the value decisions.

## Out of scope

Figma restyle of the Controls rows (D48 keeps the maaacks widget).
