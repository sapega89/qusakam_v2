---
type: plan
status: in-progress
tags: [backlog, game-menu, refactor]
---

# Game Menu — one scene, a script that only shows and hides

Decided by Sapega 2026-10-12: **D116**, **D117** ([[figma_decision_register]] §9).
Replaces the [[BACKLOG]] row "Connect `UIMenuShell` to the Game Menu".

No visual change is intended. The visual reference is the existing
`design/shots/` set (already compared to Figma in [[ui_visual_qa]]); any pixel
difference after a slice is a regression, not a redesign.

## 1. What runs today (audited 2026-10-12)

```
GameMenuState.instantiate(game_menu.tscn)            game_menu_state.gd:11
game_menu.tscn            Control, game_menu.gd (477 lines)
└ BaseMenu                instance of base_menu.tscn, script = null
  ├ Background, MapBackground, MapDim, ScreenOverlay, SidebarBackdrop, "Menu name"
  ├ HBoxContainer
  │ ├ CentralPanel
  │ │ └ GameMenuContent   game_menu_content.tscn
  │ │   └ VerticalMenu    vertical_tab_menu.tscn
  │ │     ├ PanelManager  panel_manager.gd (992 lines)
  │ │     │ └ HBoxContainer
  │ │     │   ├ TabButtons     7 Buttons, one ButtonGroup  ← already in the scene
  │ │     │   └ 7 × <Tab>Panel  each holds one *_component instance
  │ │     ├ FocusRouter   focus_router.gd (116)
  │ │     └ CursorIndicator  cursor_indicator.gd (577)
  │ └ RightPanel → PartyStatusPanel
  └ BottomBar
```

The scene tree is already static. The problem is **four scripts that each
decide which tab is active**:

| Script | How it switches |
|---|---|
| `panel_manager.gd` | discovers buttons/panels 5 ways, `pressed` → hide all PanelContainers, show one |
| `game_menu.gd` | re-discovers the same nodes, keeps its own name→panel dict, hides/shows **both** the PanelContainers and the components inside them, sets `button_pressed` |
| `focus_router.gd` | its own `active_tab_name`; `focus_tabs()` always focuses the **first** button |
| `cursor_indicator.gd` | finds buttons itself, tracks the "current" one |

Dead paths in `game_menu.gd`: `_on_old_*_pressed` (connected nowhere) call
`switch_to_tab("Map" / "Miscellaneous" / "Settings")` — names no tab has.

### B7's real cause
`SidebarTab` styles: `pressed` = `BORDER_STRONG` border, `focus` = `ACCENT`
border (`build_game_ui_theme.gd:321-326`). `focus_router.focus_tabs()` grabs
`first_button` (Inventory) every time, so Inventory wears the focus border while
the active tab wears the pressed border. The `ButtonGroup` exists already —
connecting a shell "for its ButtonGroup" would not have fixed B7.

## 2. Target

> **Revised 2026-10-12:** the frame is **not** copied into `game_menu.tscn` and `menu_shell` is deleted. `base_menu.tscn` is the one shared frame (Game Menu + Shop). It owns an empty `Center/Sidebar` (296 wide, `TopSpacer` 48, theme `MenuSidebar`) and an empty `Center/Content` slot; `game_menu.tscn` puts its 7 tab buttons in `Sidebar` and `ContentRoot` with the 7 panels in `Content`; `shop_menu.tscn` puts Buy/Sell and `ShopPanel` there. The tree below is the first draft.

```
game_menu.tscn            (the reworked MenuShell — the only Game Menu scene)
├ Background / MapDim / ScreenOverlay      from base_menu.tscn
├ MainLayout
│ ├ LeftColumn
│ │ ├ TopBar/TitleLabel
│ │ └ Sidebar             7 Buttons in the .tscn, one ButtonGroup, meta "tab" → panel
│ ├ ContentRoot           7 panels in the .tscn, each one *_component instance
│ └ RightPanel/PartyStatusPanel
└ BottomBar
game_menu.gd              show/hide + Misc modal + ui_cancel. No node discovery.
```

Initial state is authored in the `.tscn`: `InventoryComponent` visible, the other six `visible = false`, `InventoryButton.button_pressed = true`. `_ready()` hides nothing and calls no `switch_to_tab()` (D116).

Rule for the script: it holds `@export` / `%Unique` references and does
`panel.visible = panel == target`. It never searches the tree, never creates a
Control. Components already refresh on `NOTIFICATION_VISIBILITY_CHANGED`
(`equipment_component.gd:427`, `journal_component.gd:215`, …), so show/hide is
enough to drive them.

## 3. Slices

### Slice 1 — the single scene + switch (closes B7)
1. Build the tree in §2 in `game_menu.tscn`, moving `menu_shell.tscn`'s layout
   and `base_menu.tscn`'s chrome into it. `base_menu.tscn` stays — the Shop
   still uses it (`shop_ui.gd:18`).
2. Rewrite `game_menu.gd`: keep `switch_to_tab(name)` (tests and Misc use it),
   Misc modal flow, exit confirm, localized labels, `ui_cancel`. Drop the rest.
3. Focus follows the active tab, not the first button (B7).
4. Delete: `panel_manager.gd`, `game menu_central_panel_manager.gd`,
   `vertical_tab_menu.tscn`, `vertical_menu.tscn`, `game_menu_content.tscn`,
   `menu_shell.gd/.tscn`. `cursor_indicator.gd` + `MenuManager._hide_cursor_indicators`
   only if the `▶` is fully provided by the button `icon` (check against shots).
   `focus_router.gd` folds into `game_menu.gd` or stays as a 1-path node.
5. Tests: new `verify_game_menu.gd` — for every tab: exactly one panel visible,
   exactly one button pressed, focus on the pressed button. Update node lookups
   in `verify_full_regression`, `verify_responsive`, `verify_pause`, `capture_flow`,
   `verify_game_ui_theme` (it renders `menu_shell.tscn`).
6. Screenshots of all 7 tabs vs `design/shots/`.

### Slices 2+ — data rows as scene templates (D117), one screen per slice
Each row type lives in the scene as **one real node** (at least one character
always exists, so the template is also the first real row). More rows =
`template.duplicate()`. No `Label.new()` / `StyleBoxFlat.new()` for row chrome.

| Order | Screen | Code-built today |
|---|---|---|
| 2 | `party_status_panel` ✅ done 2026-10-12 (D127) — `%Card` template, theme `PortraitFrame` / `LevelBadge` / `HpBar` / `SpBar` / `CardSelect` | 0 nodes, 0 styleboxes |
| 3 | `stats_component` | 13 nodes, 4 styleboxes |
| 4 | `equipment_component` | 12 nodes, 4 styleboxes |
| 5 | `skills_component` | 13 nodes, 1 stylebox |
| 6 | `options_component` | 15 nodes, 1 stylebox |
| 7 | `journal_component` ✅ done 2026-10-12 ([[prologue_journal_plan]]) · `inventory_component`, `bottom_bar` | 0 / 1 / 4 nodes |

Out of this plan: `skill_hotbar` and `player_vitals_panel` (Combat HUD, not the
Game Menu) — same rule would apply, separate decision.

## 4. Open

- [[BUGS]] B8 says the legacy menu lacks a dim overlay; `base_menu.tscn` has
  `MapDim` + `ScreenOverlay`. Re-check B8 after slice 1 before claiming it fixed.
- Figma MCP is not authenticated in this environment; slice 1 compares against
  `design/shots/` instead of a fresh Figma pull.
