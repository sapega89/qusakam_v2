# UI Navigation Map — Figma prototype → Godot

**Figma file:** `zZet0eKcVhXSwQUNZsrOlO`
**Source:** all 68 `reactions` on page `🎮 Prototype` (`144:1774`), read via Plugin API.
**Rule applied:** nothing here is invented. Where the prototype is silent, the row
is marked `NEEDS DECISION` rather than filled with a plausible guess.

Every reaction in the file is `trigger: ON_CLICK`, `action: NODE`,
`navigation: NAVIGATE`. There are **no** hover, drag, key, back, swap, or overlay
reactions in the prototype — so keyboard/gamepad navigation, modal open/close, and
"back" behavior are entirely undefined by the prototype and must come from the
existing Godot implementation.

---

## 1. Entry & main menu

| Source | Action | Destination | Godot signal / method |
|---|---|---|---|
| `UI/Splash Screen` (whole frame) | click | `main-menu` | `SceneTransition` → `MainMenu.tscn`; already handled by `get_tree().set_meta("show_title_screen", true)` |
| `main-menu` › `menu-item-New Game` | click | `desert-oasis-scene` | `MainMenu.gd` → new game → `Game.tscn` |
| `main-menu` › `menu-item-Continue` | click | `load-game-screen` | `UIManager.open_load_game()` → `LoadGameState` |
| `main-menu` › `menu-item-Settings` | click | `settings-display` | `UIManager.open_options()` → `OptionsState` |
| `UI/Save Screen Modal` › `hex-yes` | click | `desert-oasis-scene` | `SaveSystem.save_game()` then `modal_closed("confirm")` |

> `main-menu` has no prototyped **Quit** link. `NEEDS DECISION` — Godot's
> `MainMenu.gd` has a quit path; the prototype simply doesn't exercise it.

---

## 2. Opening and closing the game menu

| Source | Action | Destination | Godot signal / method |
|---|---|---|---|
| `desert-oasis-scene` › `menu-hint` (`✦ MENU`) | click | **`menu-equipment`** | `MenuManager.toggle_game_menu()` → `UIManager.open_game_menu()` → `change_state("GameMenuState")` |
| `menu-inventory` › `hint-item` | click | `desert-oasis-scene` | `game_menu.gd::close_menu()` → `MenuManager.close_game_menu()` |
| `menu-equipment` › `hint-item` | click | `desert-oasis-scene` | same |
| `menu-healing` › `hint-item` | click | `desert-oasis-scene` | same |
| `menu-skills` › `hint-item` | click | `desert-oasis-scene` | same |
| `menu-status` › `hint-item` | click | `desert-oasis-scene` | same |
| `menu-jobs` › `hint-item` | click | `desert-oasis-scene` | same |
| `menu-miscellaneous` › `hint-item` | click | `desert-oasis-scene` | same |
| `menu-world-map` › `hint-item` | click | `desert-oasis-scene` | same |
| `menu-tutorial` › `hint-item` | click | `desert-oasis-scene` | same |

**⚠️ `NEEDS DECISION` — the menu opens on Equipment, not Inventory.**
The prototype's only entry into the menu lands on `menu-equipment`. Godot
hardcodes `current_tab_name = "Inventory"` in `game_menu.gd::_ready()`, and the
implementation order in the brief starts with Inventory.

This is very likely a **prototyping artifact**: `menu-equipment` is the only frame
whose sidebar carries the nav hotspots (see §3), so it serves as the wiring hub.
Do not change Godot's default tab on this evidence alone. Confirm the intended
landing tab.

---

## 3. Sidebar navigation — **only wired on one frame**

All sidebar links live on `menu-equipment`, on five sibling nodes all named
`bg-shape`:

| Source | Action | Destination | Godot signal / method |
|---|---|---|---|
| `menu-equipment` › `bg-shape` | click | `journal-main-story` | `game_menu.gd::switch_to_tab("Journal")` |
| `menu-equipment` › `bg-shape` | click | `menu-inventory` | `switch_to_tab("Inventory")` |
| `menu-equipment` › `bg-shape` | click | `menu-healing` | **no Godot tab exists** — see plan NEEDS DECISION #10 |
| `menu-equipment` › `bg-shape` | click | `menu-skills` | `switch_to_tab("Skills")` |
| `menu-equipment` › `bg-shape` | click | `menu-status` | `switch_to_tab("Status")` |

Mechanism in Godot (already implemented, reuse as-is):
`Button.pressed` → `FocusRouter::_on_tab_pressed(name)` → `set_active_tab()`;
`game_menu.gd::_update_visibility()` shows the matching `*Panel` `PanelContainer`
and hides the rest; `_update_button_states()` drives `button_pressed` via the
shared `ButtonGroup`.

### Sidebar destinations NOT prototyped

| Sidebar item | Frame exists? | Link exists? |
|---|---|---|
| World Map | ✅ `menu-world-map` `94:609` | ❌ **`NEEDS DECISION`** |
| Jobs | ✅ `menu-jobs` `58:947` | ❌ **`NEEDS DECISION`** |
| Miscellaneous | ✅ `menu-miscellaneous` `58:1246` | ❌ **`NEEDS DECISION`** |
| Equipment (self) | ✅ `menu-equipment` `58:4` | ❌ (hub frame, no self-link) |

Four of nine sidebar items have designed frames but no prototype link. The
frames are clearly meant to be reachable — treat the missing links as prototype
incompleteness, not as "these tabs are disabled". Confirm.

---

## 4. Miscellaneous submenu

| Source | Action | Destination | Godot signal / method |
|---|---|---|---|
| `menu-miscellaneous` › `sub-settings` | click | `settings-display` | `misc_menu_modal` → `settings_selected` → `game_menu.gd::_on_misc_settings_selected()` |
| `menu-miscellaneous` › `sub-tutorial` | click | `menu-tutorial` | `tutorial_selected` → `_on_misc_tutorial_selected()` |
| `menu-miscellaneous` › `sub-return-to-title` | click | `main-menu` | `exit_main_menu_selected` → `_on_misc_exit_main_menu_selected()` → confirm modal → `change_scene_to_file("MainMenu.tscn")` |
| `menu-miscellaneous` › `misc-sub-menu` | click | `menu-tutorial` | duplicate/overlapping hotspot — same as `sub-tutorial` |

**`Quit the Game` is drawn in the design but has no reaction.** Godot already
implements it (`exit_game_selected` → `_on_misc_exit_game_selected()` →
`confirm_exit_game_unsaved()` → `get_tree().quit()`). Keep the Godot behavior.

**Confirmation modals are not prototyped.** `game_menu.gd` shows a confirm modal
before both Return to Title and Quit; the Figma prototype navigates directly.
`NEEDS DECISION` — recommend keeping the confirm modals (data-loss guard), using
`UI/Modal/Confirm` (`258:5332`) for the visual.

---

## 5. Tutorial

| Source | Action | Destination | Godot signal / method |
|---|---|---|---|
| `menu-tutorial` › `UI/ListRow` | click | `tutorial-content` | `TutorialManager` — `tutorial_menu.tscn` exists (421 B stub) |
| `tutorial-content` › `hint-item` | click | `menu-tutorial` | back — `ui_cancel` |

Note `game_menu.gd::_on_misc_tutorial_selected()` currently calls
`get_tree().change_scene_to_file(TutorialMenuScene)` — a **full scene change**,
which drops the game menu entirely. The prototype treats tutorial as a screen
*within* the menu flow (back returns to `menu-tutorial`, and `hint-item` returns
to the game scene). `NEEDS DECISION` — recommend converting to a `UIManager`
state rather than a scene change.

---

## 6. Journal

| Source | Action | Destination | Godot signal / method |
|---|---|---|---|
| `journal-side-stories` › `Face-B` | click | `journal-main-story` | none — Journal is a stub |

Only one of three journal frames is linked. `journal-character-detail`
(`192:1754`) has **no inbound and no outbound** reactions. The `‹ All Chapters ›`
stepper visible in `journal-main-story` has no reactions either.
`NEEDS DECISION` — journal tab/stepper navigation is undefined.

---

## 7. Settings

| Source | Action | Destination | Godot signal / method |
|---|---|---|---|
| `settings-display` › `hint-item` | click | `main-menu` | `options_component.gd::close_options_menu()` (main_menu mode) |
| `settings-audio` › `hint-item` | click | `main-menu` | same |
| `settings-gameplay` › `hint-item` | click | `main-menu` | same |
| `settings-controls` › `hint-item` | click | `main-menu` | same |

**⚠️ The four settings tabs are not linked to each other.** The icon rail
(display / audio / gameplay / controls) has no reactions on any frame — you can
enter a settings page but not switch tabs within the prototype.
`NEEDS DECISION` — recommend a `TabBar`-driven swap, matching the existing
`options_component.tscn` structure.

**⚠️ Back always goes to `main-menu`, never to the game menu.** But
`menu-miscellaneous › sub-settings` enters settings *from* the game menu. Taking
the prototype literally, entering settings mid-game and pressing back would drop
you to the title screen and lose the session.

`options_component.gd` already solves this with its dual `mode` field
(`"main_menu"` vs `"game_menu"`) and `_setup_mode()`. **Keep the Godot behavior**;
treat the prototype's uniform `→ main-menu` as a prototyping shortcut.

---

## 8. NPC interaction (out of the 9-screen scope, recorded for completeness)

| Source | Action | Destination |
|---|---|---|
| `desert-oasis-scene` › `npc/merchant` | click | `npc-menu-merchant` |
| `desert-oasis-scene` › `npc/blacksmith` | click | `npc-menu-blacksmith` |
| `desert-oasis-scene` › `npc/local-resident` | click | `npc-speech-bubble` |
| `npc-menu-merchant` › `menu-item-talk` | click | `npc-dialogue-full` |
| `npc-menu-merchant` › `menu-item-quest` | click | `conversation-dialog-choices` |
| `npc-menu-merchant` › `menu-item-buy` | click | `crafting-list` |
| `npc-menu-blacksmith` › `menu-item-talk` | click | `npc-dialogue-full` |
| `npc-menu-blacksmith` › `menu-item-quest` | click | `npc-dialogue-full` |
| `npc-menu-blacksmith` › `menu-item-craft` | click | `crafting-list` |
| `npc-menu-blacksmith` › `menu-item-enchant` | click | `enchant-list` |
| `npc-speech-bubble` › `close-hint` | click | `desert-oasis-scene` |
| `npc-dialogue-full` › `continue-hint` | click | `desert-oasis-scene` |
| `conversation-dialog-choices` › `ESC` | click | `fishing-village-scene` |

Godot equivalent: `DialogueManager` + DialogueQuest (`DQD` format). Note
`menu-item-buy` on the merchant lands on `crafting-list`, not `shop-buy` — almost
certainly a prototype mis-link, since `shop-buy` (`153:1289`) exists and has its
own sell/buy toggle. `NEEDS DECISION`.

---

## 9. Shop / Crafting / Enchant (out of scope, recorded)

| Source | Action | Destination |
|---|---|---|
| `shop-buy` › `Frame` | click | `shop-sell` |
| `shop-sell` › `Frame` | click | `shop-buy` |
| `crafting-list` › `Frame` | click | `crafting-detail` |
| `crafting-detail` › `Frame` | click | `crafting-detail` (self) |
| `crafting-confirm` › `Frame` | click | `crafting-detail` |
| `crafting-error` › `Frame` | click | `crafting-detail` |
| `enchant-list` › `Frame` | click | `crafting-detail` |
| `enchant-detail` › `Frame` | click | `crafting-detail` |
| `enchant-confirm` › `Frame` | click | `crafting-detail` |
| `enchant-error` › `Frame` | click | `crafting-detail` |

Every enchant frame routes back to `crafting-detail` rather than
`enchant-detail`. Consistent enough to look like copy-paste during prototyping.
Godot has `Scenes/Shop/shop_menu.tscn`. Not in the 9-screen scope.

---

## 10. Input model — **undefined by the prototype**

The `UI/Bottom Bar` component (`121:1073`) has two variants, `input=gamepad` and
`input=keyboard`, and every menu frame renders hints:

- Game menu: `LB Select` · `A Confirm` · `B Return`
- Settings: `LB Navigate` · `A Apply` · `B Back`

These are **labels only** — no `ON_KEY_DOWN` reactions exist anywhere in the file.

Existing Godot behavior to preserve (do not redesign):

| Input | Current handler | Behavior |
|---|---|---|
| `Escape` | `game_menu.gd::_input()` | closes menu, `set_input_as_handled()` |
| `ui_right` / `ui_accept` | `focus_router.gd::_unhandled_input()` | tabs → content focus |
| `ui_left` / `ui_cancel` | `focus_router.gd::_unhandled_input()` | content → tabs focus |
| arrow keys | `metsys_map_component.gd::_input()` | pans the map |
| `Enter` | `inventory_component.gd::_unhandled_input()` | equip selected item |

`NEEDS DECISION` — the Figma bottom bar implies a **two-level** model
(`B` = back one level, i.e. content→sidebar→close). `focus_router.gd` already
implements exactly that via `ui_cancel`. Recommend wiring the bottom bar as a
display of `focus_router.focus_mode` and leaving the input logic untouched.

---

## 11. Summary of navigation gaps

| # | Gap | Severity |
|---|---|---|
| 1 | Menu entry lands on Equipment, not Inventory | Low — likely artifact |
| 2 | World Map / Jobs / Miscellaneous unreachable from sidebar | **High** — 3 of 9 tabs |
| 3 | Settings tabs not linked to each other | **High** |
| 4 | Settings back → `main-menu` even when entered from game menu | **High** — would lose the session |
| 5 | Confirm modals absent before Return to Title / Quit | Medium — keep Godot's |
| 6 | `Quit the Game` has no reaction | Low — Godot implements it |
| 7 | Journal: 1 of 3 frames linked; chapter stepper dead | Medium |
| 8 | `journal-character-detail` fully orphaned | Medium |
| 9 | Merchant `Buy` → `crafting-list` instead of `shop-buy` | Low — out of scope |
| 10 | Enchant frames all return to `crafting-detail` | Low — out of scope |
| 11 | No keyboard/gamepad reactions anywhere | Low — Godot has it |
| 12 | Tutorial is a full scene change in Godot, a nested screen in Figma | Medium |

For gaps 2–4, the recommendation is the same: **treat the existing Godot
navigation as authoritative** (it is the behavioral source of truth) and use
Figma only for the visual treatment of those transitions.
