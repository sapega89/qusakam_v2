# Inventory — implementation diff plan (Phase 5)

**Figma:** `menu-inventory` `46:193`, center panel component `UI/Inventory Center Panel` `355:6423`, right panel `UI/Party Status Panel` `104:490`.
**Godot:** `Scenes/Menus/Game/inventory_component.tscn` + `Scripts/Menus/Game/inventory_component.gd`.

## Measured spec (from `get_design_context`, not eyeballed)

| Region | Spec |
|---|---|
| main-layout | h 1016; columns **320 / flex / 400** |
| left-column | bg surface; TopBar h 50, px 24, title **Bold 28**; sidebar border 1 `#3a3a42`, pr 24 py 24, item gap 16 |
| Sidebar Tab | h 45, pl 16 pr 28 py 12, gap 8, 12px pointer slot, SemiBold 16 |
| **Center panel** | bg surface, **border 1 accent**, padding **48**, gap **24** |
| tabs row | justify-between; tabs gap 8; tab px 20 py 10, **Bold 18**; selected = accent text + **2px accent bottom border**; else text-secondary |
| FILTER button | border 1 accent, **radius 3**, px 12 py 6, gap 8, icon 16, Regular 14 accent |
| column headers | px 16, **Bold 14** text-secondary, "ITEM NAME" / "ON HAND" |
| header rule | 1px line, full width |
| list container | gap **4**, fills remaining height, clipped |
| **ListRow** | px 16 py 12 gap 12; icon **36×36** `#2a2a35`; name **Medium 18** primary; count **SemiBold 16** primary `×N` |
| ListRow normal | bg **`color/background`**; icon border 1 `#3a3a42` |
| ListRow selected | bg **accent**; border **2** accent; icon has no border; text stays primary |
| Party panel | w 400, bg surface, border 1 `#3a3a42`, p 24, gap 24 |
| header-meta | PLAYTIME/GOLD **Bold 11** uppercase secondary; values **Bold 24** (gold value accent) |
| party card | w 330, bg surface, border 1 accent, p 12, gap 16; portrait 56 border 1 accent |
| card info | name **Bold 20**; level badge bg accent px 6 py 2 **Bold 11** |
| stat bars | label **Bold 12** uppercase secondary + value **Regular 12** primary; track h **6** w 180; HP `#2ecc71`, SP `#3498db` |
| Bottom Bar | h 64, px **60**, bg surface, justify-between |
| Background | map image, **blur 3px**, + `color/surface` dim + `color/overlay` |

### Off-scale type sizes

The frame uses **11, 18, 28** px, none of which are in the documented scale
(12·14·16·20·24·36), plus weight **Medium (500)** which is not in the documented
4 weights. The frame wins (Figma is the visual source of truth); these are added
to `UITokens` as explicitly-marked measured values.

## File diff

### Modify — `UI/Tokens/UITokens.gd`
Add `WEIGHT_MEDIUM = 500`; `SIZE_MICRO = 11`, `SIZE_ROW_TITLE = 18`, `SIZE_TOPBAR = 28`;
`ICON_SLOT = 36`, `PORTRAIT = 56`, `BAR_HEIGHT = 6`, `BAR_WIDTH = 180`,
`PARTY_PANEL_WIDTH = 400`, `PARTY_CARD_WIDTH = 330`;
`HP_FILL`, `SP_FILL`, `ICON_SLOT_BG = #2a2a35`.

### Modify — `UI/build_game_ui_theme.gd`
New variations: `TopBarTitle` (Bold 28), `ListRowTitle` (Medium 18),
`ListRowCount` (SemiBold 16), `MicroLabel` (Bold 11), `StatLabel` (Bold 12),
`StatValue` (Regular 12), `CardName` (Bold 20), `BigValue` (Bold 24).
Change `TabButton` to **Bold 18** to match the frame. Add `CenterPanel`
(surface + 1px accent) and `FilterButton` (1px accent, radius 3) panel/button variations.

### New — `UI/Components/item_row.tscn` / `.gd`
`UIItemRow`: icon + name + count, `set_item()`, `set_selected()`, emits
`selected(index)` and `activated(index)`. Focusable; keyboard and mouse.

### New — `UI/Components/party_status_panel.tscn` / `.gd`
`UIPartyStatusPanel`: PLAYTIME + GOLD header, rule, party cards from
`CharacterManager.get_all_characters()` (capped at 4 per Figma).

### Rewrite — `inventory_component.tscn`
Replaces the internal `PanelManager` + 4 `PanelContainer`s + 4 `Table`s with:
`CenterPanel → [TabsRow, ColumnHeaders, Rule, ScrollContainer → ItemList]`.
Root stays a `Control` named `InventoryComponent` so `game_menu.gd`'s
`_collect_content_panels()` mapping keeps working.

### Rewrite — `inventory_component.gd`

**Preserved verbatim (behavioral source of truth):**
`set_equipment_selection_mode()`, `_equip_item()`, `_filter_by_equipment_slot()`,
`_get_slot_for_item()`, `_get_slot_display_name()`, `_is_equipment_tab_open()`,
`_try_auto_equip()`, `_load_inventory_items()` (InventoryManager + ItemDatabase),
signals `item_equipped` / `request_tab`, refresh on visibility change.

**Removed (dead once the Table goes):**
`_setup_all_tables()`, `_update_item_list_from_active_panel()`,
`_create_filter_buttons()` (dynamic `MainVBox`/`FilterContainer`), `_on_panel_changed()`,
`_find_nodes()` / `_validate_scene_structure()` search heuristics,
`Table.set_table()` / `CLICK_ROW_INDEX` / `DOUBLE_CLICK` wiring.

**Changed — filtering:**
```
ALL          → no filter
CONSUMABLES  → ItemDatabase.get_items_by_type("consumable")
MATERIALS    → ItemDatabase.get_items_by_type("material")
EQUIPMENT    → get_items_by_type("weapon") + get_items_by_type("armor")
KEY ITEMS    → get_items_by_type("key_item")  → empty ⇒ tab disabled
```
Replaces the hardcoded `match current_filter` arms. No new index is built —
`ItemDatabase.items_by_type` already exists and is populated at load.

### Modify — `Scenes/Menus/Game/base_menu.tscn`
Additive only: blurred map background + dim, `bottom_bar.tscn`, RightPanel content
replaced by `party_status_panel.tscn`, left column width 320.

### Modify — `Scenes/UI/vertical_tab_menu.tscn`
`theme_type_variation = &"SidebarTab"` on the 7 tab buttons + sizing. **No** tab
added or removed — Healing/Jobs are out of Inventory scope.

## Out of scope (explicit)

Equipment, Status, Skills, World Map, Journal, HUD, Pause, Settings content.
Sidebar item set unchanged. `InventoryManager` untouched. No project-global theme.

## Known data gaps (reported, not faked)

1. **KEY ITEMS** — no `key_item` items exist ⇒ tab rendered **disabled**, per instruction.
2. **Per-character HP/SP does not exist.** `CharacterAttributes` has only
   strength/intelligence/dexterity/constitution; HP is computed globally via
   `GameManager.calculate_max_health()` and level is a single global
   `XPManager.get_level()`. Figma shows 4 characters each with their own HP/SP/Lv.
   ⇒ real values rendered for the **active** character; others show `—/—` with an
   empty track rather than fabricated numbers.
3. **No "party" concept** in `CharacterManager` — only `get_all_characters()` (7
   defaults) and one active. Cards are the first 4, active first. Needs a decision.
