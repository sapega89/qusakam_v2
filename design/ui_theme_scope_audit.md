# Theme Scope Audit — impact of a project-wide `[gui] theme/custom`

**Date:** 2026-09-26
**Question:** what would inherit `GameUITheme.tres` if it were set project-global?
**Current state:** theme is applied at **two anchors only**, not globally.

## Method

Runtime walk of the live scene tree with `Game.tscn` loaded, collecting every
`Control` that is **not** already under a node carrying `GameUITheme`. Anything
in that list would change appearance the moment `gui/theme/custom` is set.
Supplemented by a static scan for addon UI scenes our code loads on demand.

---

## 1. Where the theme is applied today

| Anchor | Node | Covers |
|---|---|---|
| `Scenes/UI/ui_root.tscn` | `UILayer/StateRoot` | Every `UIManager` state: GameMenuState, OptionsState, LoadGameState, SaveGameState, MainMenuState, ModalState |
| `Scenes/UI/modal_layer.tscn` | `ModalLayer/Container` | All modals via `UIManager.show_modal()` / `modal_templates.gd` |

`UIManager._ensure_ui_root()` instantiates `ui_root.tscn` exactly once per scene,
so these two anchors cover **all** menu UI with no per-screen wiring.

Verified by `SampleProject/UI/verify_game_ui_theme.gd` (28 assertions, all pass).

---

## 2. Our UI that would be newly affected — **9 Controls**

All of these live under `Game.tscn`, outside the `UIRoot` hierarchy:

| Node | Script |
|---|---|
| `/root/Game/UI/MapWindow` | inline `Game.tscn::GDScript` |
| `/root/Game/UI/MapWindow/Percent` | inline `Game.tscn::GDScript` |
| `/root/Game/UICanvas/PlayerHealthBar` | `Scripts/UI/HealthBar.gd` |
| `/root/Game/UICanvas/PlayerXPBar` | `Scripts/UI/XPBar.gd` |
| `/root/Game/UICanvas/LevelUpNotification` | `Scripts/UI/LevelUpNotification.gd` |
| `/root/Game/UICanvas/CoinCounter` | `Scripts/UI/CoinCounter.gd` |
| `/root/Game/UICanvas/CombatContextDisplay` | `Scripts/UI/CombatContextDisplay.gd` |
| `/root/Game/UICanvas/TutorialHintDisplay` | `Scripts/UI/TutorialHintDisplay.gd` |
| `/root/Game/UICanvas/ObjectiveHUD` | `Scripts/UI/ObjectiveHUD.gd` |

**This is the entire gameplay HUD.** A global theme restyles all of it at once —
fonts, label colors, panel backgrounds — with no screen-by-screen review.

Per `design/ui_implementation_plan.md` §3.7, Figma has **no HUD design** (the
`Game Scene` section is empty; `desert-oasis-scene` shows only a `✦ MENU`
button). So a global theme would restyle seven widgets against **zero reference
art**. That is the single strongest argument for not going global yet.

---

## 3. Third-party UI that would be newly affected

### Live at runtime — **5 Controls**

| Node | Addon |
|---|---|
| `/root/ModalDialogGlobal/ModalDialog` | `ModalDialog` (autoload, always live) |
| `/root/Game/UI/Minimap` | `MetroidvaniaSystem` |
| `/root/Game/DialogueSystem/DialogueBox` | `dialogue_quest` |
| `…/DialogueBox/Margin/Rows/RowMiddle/BobbingMarker` | `dialogue_quest` |
| `/root/Game/DialogueSystem/ChoiceMenu` | `dialogue_quest` |

`ModalDialogGlobal` is an autoload — it is present in **every** scene, including
the main menu, so a global theme touches it permanently.

### Loaded on demand by our code

| Scene | Addon | Entry point |
|---|---|---|
| `basic_settings_menu/settings.tscn` | Basic Settings Menu | `SettingsManager.open_settings()` |
| `maaacks_.../pause_menu.tscn` | Maaacks Menus | referenced by our code |
| `maaacks_.../input_actions_list.tscn` | Maaacks Menus | `input_options_menu.tscn` |
| `maaacks_.../input_actions_tree.tscn` | Maaacks Menus | key rebinding |
| `maaacks_.../key_assignment_window.tscn` | Maaacks Menus | key rebinding |
| `maaacks_.../overlaid_window.tscn` | Maaacks Menus | confirmation dialogs |
| `maaacks_.../confirmation_overlaid_window.tscn` | Maaacks Menus | confirmation dialogs |
| `dialogue_quest/.../dialogue_box.tscn` | DialogueQuest | `DialogueManager` |
| `dialogue_quest/.../choice_menu.tscn` | DialogueQuest | dialogue choices |
| `godot_tree_table/Table.gd` | Tree Table | Inventory list |
| Maaacks `SceneLoader` loading screen | Maaacks Menus | autoload, shown on transitions |

Also enabled but editor-only (no runtime impact): GUT, CustomRunner,
DropShadowCaster2D, TweenAnimation, scatter2d, tree_maps, midi, py4godot,
easy_trajectory, dynamic_water_2d, input_manager, long_scene_manager.

---

## 4. Recommendation

**Do not set `gui/theme/custom` yet.** Current two-anchor scoping is working and
verified. Going global would, in one commit:

- restyle 9 HUD Controls that have **no Figma reference design**
- restyle 16+ third-party scenes we do not control, including the always-live
  `ModalDialogGlobal` autoload and the DialogueQuest dialogue box
- make Phase 6 visual QA ambiguous — a regression could come from our theme or
  from an addon's own assumptions about the default theme

**Preconditions for going global**, in order:

1. Settings screen migrated off `basic_settings_menu` / Maaacks input menus
   (Phase 5 #9), or those scenes given an explicit local `theme` to opt out.
2. HUD decision resolved (plan §6 #8) — a global theme forces the HUD question.
3. DialogueQuest dialogue box either restyled deliberately or opted out.
4. `ModalDialogGlobal` either replaced by our `modal_layer` or opted out.

**Opt-out mechanism:** setting `theme` on an addon scene's root Control stops
inheritance for that subtree, so the migration can be incremental rather than
all-or-nothing.

---

## 5. Re-running this audit

The runtime walk used a throwaway script (removed). The permanent check is:

```bash
godot --headless --path . --script res://SampleProject/UI/verify_game_ui_theme.gd
```

It asserts theme content, token↔theme sync, inheritance under `StateRoot` and
`ModalLayer/Container`, and — critically — that a `Control` outside those anchors
and the Maaacks `pause_menu.tscn` do **not** pick up `GameUITheme`.
