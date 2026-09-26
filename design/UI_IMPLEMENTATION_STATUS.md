# UI Implementation Status — **COMPLETE**

Branch `feature/figma-ui-pipeline` · final UI commit `3ef9bee9`

Every Figma UI surface has been implemented against the shared theme. No UI
screen remains outstanding. What is still open is **content, product decisions
and non-UI technical debt** — listed at the end so it is not mistaken for
unfinished UI work.

---

## Surfaces

| # | Surface | Figma frame | Godot | Status |
|---|---|---|---|---|
| 0 | Shared theme + tokens | design system | `UI/Tokens/UITokens.gd`, `UI/Themes/GameUITheme.tres` (98 types) | ✅ |
| 1 | Game Menu shell | `UI/Top Bar`, `UI/Game Menu Sidebar` | `game_menu.tscn` | ✅ |
| 2 | Inventory | `menu-inventory` `46:193` | `inventory_component` | ✅ |
| 3 | Equipment | `menu-equipment` `58:4` | `equipment_component` | ✅ |
| 4 | Status | `menu-status` `58:719` | `stats_component` | ✅ |
| 5 | Skills | `menu-skills` `58:453` | `skills_component` | ✅ |
| 6 | World Map | `menu-world-map` `94:609` | `metsys_map_component` | ✅ |
| 7 | Journal | `journal-main-story` `192:1529` | `journal_component` | ✅ quest-log shell |
| 8 | Settings | `settings-*` `17:280` +3 | `options_component` | ✅ backed rows only |
| 9 | Misc submenu | `menu-miscellaneous` `58:1246` | `misc_menu_modal` | ✅ |
| 10 | Combat HUD | `Game Scene / Combat HUD` `434:6556` | `skill_hotbar`, `player_vitals_panel`, `combat_hud_top` | ✅ |
| 11 | Pause | — (no separate frame) | the tabbed Game Menu | ✅ verified, not built |
| 12 | Modals | `UI/Modal` | `modal_layer` | ✅ |

---

## Principles held throughout

- **Figma is the visual source of truth; existing Godot code is the behavioural
  source of truth.** No gameplay system was rewritten to fit a design.
- **Nothing fabricated.** Every element on screen is backed by a real system.
  Figma rows without backing are omitted and recorded as deferred, never
  rendered as dead controls.
- **One theme.** All styling flows from `UITokens.gd` → `GameUITheme.tres`.
  The theme is *not* project-global; it is scoped to `StateRoot`, `ModalLayer`
  and `UICanvas/CombatHUD`, so third-party addon UI stays isolated.
- **Test fixtures never reach production.** Synthetic data lives only in the
  verify scripts; asserted for Skills, the hotbar and the Journal.

---

## Test suites — 16, all passing

`core_wiring` · `inventory` · `status` · `equipment` · `skills` ·
`skills_combat` · `skills_ui` · `hotbar` · `world_map` · `journal` ·
`misc_modal` · `pause` · `combat_hud` · `settings` · `responsive` ·
`full_regression`

```bash
godot --headless --path . --script res://SampleProject/UI/verify_<name>.gd
```

Responsive coverage: 1920×1080, 1600×900, 1280×720, 2560×1440, 1920×1200 across
the shell, all seven tabs, all four Settings tabs and modals.

`verify_game_ui_theme` segfaults on shutdown after its final section. All 17 of
its assertions pass first and it behaves identically on clean `main` —
pre-existing, unrelated to UI.

---

## Defects found and fixed along the way

Bugs in existing code, surfaced by writing the verifications:

| Area | Defect |
|---|---|
| ServiceLocator | `Engine.has_singleton("ServiceLocator")` is always false for Godot 4 autoloads — broke manager access, equipment stats and player-data saving |
| Pause | `ui_cancel` was a raw `KEY_ESCAPE` compare; Settings used `change_scene_to_file`, unloading the running game |
| Focus | `FocusRouter` resolved its exported paths from itself instead of the menu root, so every method was a silent no-op; `focus_tabs()` also focused an invisible spacer. Keyboard/gamepad navigation had never worked in the pause menu |
| Combat HUD | HP read from a `HealthComponent` that does not exist on `Player`, so the bar was always full; the panel never refreshed after `_ready()`; the HUD sat outside the themed subtree |
| `Player` | Level-up raised `Max_Health` without emitting `health_changed` |
| Theme | `HSlider` track had zero content margins — invisible on every slider in the project |
| ModalLayer | `show_custom_modal()` never set the layer visible and never wired close signals |
| Navigation | Exit to Main Menu pointed at a non-existent scene path |

---

## NOT UI work — still open

### Product / content decisions
| ID | Open question |
|---|---|
| D40, D41 | World Map legend and named markers need a location dataset |
| D43–D47 | Settings: Resolution, Frame Rate Limit, Screen Brightness, Ambient volume, Text Speed, Screen Shake, Damage Numbers — build the systems or cut the rows |
| D48 | Controls tab: keep the third-party maaacks widget or own the rebinding UI |
| D53–D55 | Journal: Figma's banner characters are not project characters; no backstory prose or portraits exist |
| D56 | The quest engine has no authored data and is never instanced — ship or delete |
| D57 | `pathfinder_classes.json` class display names are still empty |
| — | `skills.json` ships empty by design; production skill content is unwritten |
| — | Skill targeting: `use_skill()` takes an explicit target, no auto-targeting heuristic was invented |
| — | Controller bindings for the 4 skill slots are undefined in Figma |

### Technical debt
- **139** `Engine.has_singleton(...)` sites remain. One of them makes
  `EventBus.player_health_changed` dead; the HUD works because it uses the node
  signal instead.
- `Player._initialize_health_bar()` recurses through `call_deferred` forever when
  `get_tree().current_scene` is null.
- `ModalLayer` has no public close method — modals close only via their own
  signals.
- Nine stray `.tmp` files are committed under `SampleProject/`
  (`MainMenu.tscn*.tmp`, `Maps/Canyon.tscn*.tmp`, `Sprites/download (1).jpg*.tmp`).

### Figma updates needed
- Equipment frame shows fewer slots than the 11 real ones.
- Controls frame lists six actions that do not exist and omits the four real
  `skill_slot_*` binds.
- Journal frames use placeholder characters and a codex layout that the product
  decision replaced with a quest log.
- Settings Game tab shows one language; `LocalizationManager` ships two.

Full deviation list (D1–D64) and per-screen QA: `design/ui_visual_qa.md`.
