# Settings — Figma → Godot mapping

**Figma:** `settings-display` `17:280` · `settings-audio` `17:409` ·
`settings-gameplay` `17:632` · `settings-controls` `17:756`
**Godot:** `Scenes/Menus/Game/options_component.tscn` /
`Scripts/Menus/Game/options_component.gd` (`extends BaseOptionsComponent`)

All four Figma tabs share one shell: `UI/Settings Top Section` (1800×101), a
56px icon-only `UI/Settings Sidebar`, `UI/Settings Section Header`, a
`settings-list` of 68px (or 50/51px) rows separated by 1px lines, a
`UI/Scrollbar`, a `Restore Default Settings` button and the shared `Bottom Bar`.

Row anatomy is consistent: 16px icon + label on the left, control on the right
at a fixed x. Three control archetypes only:

| Archetype | Figma shape | Used by |
|---|---|---|
| **Stepper** | `chevron-left` · 280px value box · `chevron-right`, total 360 | Display Mode, Resolution, Frame Rate Limit, Language |
| **Segmented toggle** | two ~150px cells, active one carries a `✓`, total 298 | VSync, Text Speed, Screen Shake, Auto-Save, Damage Numbers |
| **Stepper slider** | `minus` · 320×8 track + diamond thumb · `plus` · value, total 432 | Screen Brightness, all four volumes |

## What the existing Godot settings system actually supports

`options_component.tscn` today: `AudioSettings` (Master/Music/SFX = Label +
HSlider + value), `GraphicsSettings` (FullscreenCheckBox, VSyncCheckBox),
`ControlsSettings` (a third-party `InputOptionsMenu` instance), plus
Save / Reset / Back / ExitToMainMenu.

Persistence is `Scripts/Systems/Save/Modules/SettingsModule.gd`, and it stores
**exactly five keys**: `master_volume`, `music_volume`, `sfx_volume`,
`fullscreen`, `vsync`. Nothing else in the project persists a user setting
except the maaacks addon's own keybind storage (`app_settings.gd`) and
`LocalizationManager._save_language()`.

Audio buses in `default_bus_layout.tres`: **Master, Music, SFX**. That is all.

## Per-row backing verdict

### Display `17:280`

| Row | Backing | Verdict |
|---|---|---|
| Display Mode | `fullscreen: bool` + `DisplayServer.window_set_mode()` | **Partial.** Real support for Windowed ↔ Fullscreen only. Figma's displayed value is *Borderless Window*, which the persisted bool cannot express. |
| Resolution | none | **NEEDS DESIGN DECISION** |
| VSync | `vsync` key + `DisplayServer.window_set_vsync_mode()` | ✅ real |
| Frame Rate Limit | none persisted (`Engine.max_fps` exists as an API) | **NEEDS DESIGN DECISION** |
| Screen Brightness | none — no post-process, no canvas modulate, no key | **NEEDS DESIGN DECISION** |
| `brightness-preview-container` (DARK/BRIGHT compass swatches) | depends on brightness | blocked with it |
| Restore Default Settings | existing `ResetButton` | ✅ real |

### Audio `17:409`

| Row | Backing | Verdict |
|---|---|---|
| Master Volume | `master_volume` → Master bus | ✅ real |
| Music | `music_volume` → Music bus | ✅ real |
| Sound Effects | `sfx_volume` → SFX bus | ✅ real |
| **Ambient** | **no Ambient bus exists** and nothing routes to one | **NEEDS DESIGN DECISION** |

Audio is the only tab that is almost fully backed. Note the Figma sliders are
0–100 integers with `minus`/`plus` steppers; the existing sliders are 0.0–1.0
linear, converted with `linear_to_db()` on apply. That is a presentation change
(display ×100), not a data change.

### Gameplay `17:632`

| Row | Backing | Verdict |
|---|---|---|
| Language | `LocalizationManager` autoload — `set_language()`, `get_language()`, `available_languages = ["en", "uk"]`, persisted by `_save_language()` | ✅ real. **Figma shows only "English"; the real system also ships Ukrainian.** Per the Equipment precedent (D-series: keep real capability, update Figma) both locales must be offered. |
| Text Speed (Default / Quick) | no text-speed setting in DialogueQuest integration or project code | **NEEDS DESIGN DECISION** |
| Screen Shake | no camera-shake system exists | **NEEDS DESIGN DECISION** |
| Auto-Save | `SaveSystem.enable_auto_save_on_scene_transition: bool` is real, but **not persisted** — no `SettingsModule` key | **Partial.** Toggle has a live target; persisting it means adding one key to the existing module (not a second system). |
| Damage Numbers | no damage-number system | **NEEDS DESIGN DECISION** |

### Controls `17:756`

Figma lists **12 binding rows**. The project defines **10** input actions.
They do not line up:

| Figma row | Real action | Verdict |
|---|---|---|
| Move Up / Down / Left / Right | `move_up/down/left/right` | ✅ real |
| Jump | `jump` | ✅ real |
| Attack | `attack` | ✅ real |
| Dash | — | **no such action** |
| Special Ability | — | **no such action** |
| Interact / Examine | — | **no such action** |
| Open Map | — | not an action; the map is a Game Menu tab |
| Inventory | — | not an action; Inventory is a Game Menu tab |
| Pause Menu | `ui_cancel` (built-in) | ✅ real, now that the pause handler was moved off a raw `KEY_ESCAPE` compare |
| *(absent from Figma)* | `skill_slot_1…4` | **Figma needs updating** — these are real, bound to keys 1–4, and shown as bind badges on the combat HUD |

Six of Figma's twelve rows name actions that do not exist. They must not be
fabricated: an unbindable row in a rebinding list is worse than an absent one.

## Constraint: the Controls tab is third-party

Rebinding works today **only** because `ControlsSettings` instances the maaacks
`InputOptionsMenu`, whose `input_actions_list.gd` / `input_actions_tree.gd` call
`InputMap.action_add_event()` / `action_erase_events()` and whose
`app_settings.gd` persists the result. No first-party rebinding code exists
anywhere in `SampleProject/`.

`design/ui_theme_scope_audit.md` deliberately isolates third-party UI from
`GameUITheme`. So the Controls tab presents a genuine conflict:

- Restyling it to Figma means either theming the addon's internals or
  reimplementing rebinding — the latter is explicitly forbidden ("preserve
  existing input rebinding functionality", "do not create a second settings
  system").
- Leaving it unstyled means one tab visibly diverges from the design.

**NEEDS DESIGN DECISION.** The recommended resolution is to keep the addon
widget and wrap it in the themed shell, accepting that the rows inside keep the
addon's appearance, until someone decides the rebinding UI is worth owning.

## Behaviour that must survive any restyle

1. **Dual mode.** `options_component.gd` carries `var mode: String = "game_menu"`
   and `_setup_mode()`, which swaps between a Back button (in-menu) and
   Exit-to-Main-Menu. Both paths are live.
2. **Persistence round trip.** Save → `SettingsModule.save()` → reload →
   `load_data()` → `apply_settings()`, which pushes to `AudioServer` and
   `DisplayServer`.
3. **Input rebinding** via the addon, including its own persistence.
4. **Reset** to defaults.
5. The component is reachable as the `Misc` tab of the pause menu
   (`MiscPanel/OptionsComponent`) — see the Pause section of
   `ui_visual_qa.md`. It must not be opened by a scene change.

## Scope recommendation

Implementable truthfully today: the shared shell (top section, 56px icon
sidebar, section header, row list, scrollbar, restore button, bottom bar), the
four-tab split, **Audio** (3 of 4 rows), **Display** (VSync + a two-value
Display Mode), **Gameplay** (Language with both real locales; Auto-Save if one
persistence key is added), and **Controls** wrapped but not re-skinned.

Blocked pending decisions: Resolution, Frame Rate Limit, Screen Brightness and
its preview, Ambient volume, Text Speed, Screen Shake, Damage Numbers, and six
of twelve control bindings.

That is **8 unsupported rows out of 19**, plus half the Controls tab. A Settings
screen where nearly half the visible rows are disabled placeholders is a design
conversation, not an implementation task — which is why this document stops at
the mapping.
