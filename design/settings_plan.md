---
type: plan
status: planned
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
| Display Mode | Windowed / Fullscreen / Borderless (D66). Window switches at once. | ⚠️ Windowed ↔ Fullscreen works in a standalone window (probe 2026-10-16: mode 0 → 3 → 0). **Does nothing when the game runs embedded in the editor's Game tab** — Godot ignores window-mode requests there. Borderless missing. |
| Resolution | Window size from a list; disabled in Fullscreen. | ❌ no key, no list. Values undefined → Q. |
| VSync | On/Off → `DisplayServer.window_set_vsync_mode`. | ✅ works; has no visible effect except tearing/FPS. |
| Frame Rate Limit | `Engine.max_fps` from a list. | ❌ values undefined → Q. |
| Screen Brightness | 0–100 stepper slider, applied to the world and UI; DARK/BRIGHT preview swatches. | ❌ no system. |

## Audio — `17:409`

| Row | Must do | Today |
|---|---|---|
| Master / Music / Sound Effects | 0–100, bus volume at once. | ✅ |
| Ambient | 0–100 on an Ambient bus. | ❌ no bus, nothing routed to it. |

## Game — `17:632`

| Row | Must do | Today |
|---|---|---|
| Language | Switches UI and Journal text at once (D194); dialogue stays Ukrainian for now. | ❌ **switches nothing.** `TranslationServer.set_locale()` runs (`LocalizationManager.gd:60`), but `project.godot:167` registers only the maaacks en/fr translations; `Resources/Translations/uk.po` is not registered and holds 14 strings; UI is English literals (D121), `.dqd` dialogue is Ukrainian only. |
| Text Speed | Default / Quick: dialogue box typing speed and bubble line time (D178, D192). | ❌ |
| Screen Shake | On/Off; off = no camera shake. | ❌ no shake system exists — the row has nothing to switch. |
| Auto-Save | On/Off → `SaveSystem.enable_auto_save_on_scene_transition`, persisted. | ⚠️ target exists, no key, no row. |
| Damage Numbers | On/Off. | ❌ no damage-number system exists. |

## Controls — `17:756`

Two tabs (D193, [#98](https://github.com/sapega89/qusakam_v2/issues/98)):
**Keyboard & Mouse** accepts only keys and mouse buttons; **Gamepad** accepts only pad
buttons/axes. Each lists every action; rebinding a slot listens to that device only;
Reset restores that tab. Today: one mixed list, a pad slot offers the mouse, mouse buttons
cannot be assigned (`key_assignment_window.gd:67-76` treats mouse input as non-confirming),
the scrollbar is too faint to see (#79).

## Decisions required

1. ~~Q55~~ → **D194:** Language switches UI + Journal now (EN/UK), `.dqd` dialogue stays Ukrainian for now.
2. Resolution list and Frame Rate Limit list — **GAME DESIGN DECISION REQUIRED** (values).
3. Screen Shake, Damage Numbers, Brightness, Ambient need their systems first; each gets its own plan.

## Slices

### Slice 1 — honest Display and Game rows
- `DisplayManager` + `SettingsModule`: Borderless as a third Display Mode value.
- Auto-Save row + `auto_save` key.
- Language (D194): wrap every UI literal in `tr()`, extract to `Resources/Translations/{en,uk}.po`, journal texts from
  `story.json` too; register both in `project.godot` `locale/translations`. Who writes the Ukrainian UI strings is
  Sapega's call — draft them marked for review.
- `verify_settings.gd`: every row → change → value applied → restart round trip → Restore.

### Slice 2 — Controls split (D193, #98) — ✅ built 2026-10-22 (D397, `cloud/ui-bugs`)
- Keyboard & Mouse / Gamepad tabs over the maaacks list; device filter on rebinding; mouse buttons accepted.
- `verify_settings.gd` [controls]: a pad slot ignores keys and mouse, a keyboard slot accepts a mouse button.

### Slice 3 — Text Speed
- One speed key read by the dialogue box typing and `DialogueManager._play_bubbles`.

### Slice 4+ — rows that need a system (each with its own plan)
Brightness, Ambient bus, Screen Shake, Damage Numbers, Resolution, Frame Rate Limit.

## Order

1 → 2 → 3; 2 and 3 are independent. 4+ waits on the value decisions.

## Out of scope

Figma restyle of the Controls rows (D48 keeps the maaacks widget).
