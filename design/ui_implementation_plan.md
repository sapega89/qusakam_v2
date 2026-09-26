# UI Implementation Plan — Figma → Godot

**Figma file:** `zZet0eKcVhXSwQUNZsrOlO` ("Untitled")
**Branch:** `feature/figma-ui-pipeline`
**Status:** Phase 1–3 complete (audit + mapping). No Godot scenes modified.

Figma is the visual source of truth. Existing Godot gameplay code is the behavioral
source of truth.

---

## 0. Figma file structure

| Page | Node ID | Contents |
|---|---|---|
| 🎮 Prototype | `144:1774` | 9 sections, ~50 screen frames, 68 prototype links |
| 🎨 Icons & Assets | `106:586` | Icon/asset source |
| UI KIT / DESIGN SYSTEM | `222:4288` | Token docs + ~60 components |

There is **no page named "DEV SPEC"**. The closest equivalents are the three
`Documentation / *` frames on the UI KIT page (Colors, Typography, Spacing,
Shape Tokens). This plan treats those as the dev spec.

### Prototype sections

| Section | Node ID | Frames |
|---|---|---|
| Splash & Main Menu | `144:1775` | 2 |
| Save / Load | `144:1776` | 3 |
| Settings | `144:1798` | 4 |
| Modals & Popups | `144:1799` | 5 |
| Dialogues | `144:1800` | 2 |
| **Game Menu** | `144:1801` | **24** (all 9 target screens live here) |
| Game Scene | `144:1802` | 0 — **empty section** |
| NPC Interaction | `164:1301` | 6 |

---

## 1. Design tokens (Phase 4 input)

Confirmed via `get_variable_defs` on `46:193` — these are **real bound Figma
Variables**, not loose hexes.

### Colors

| Figma variable | Value | Godot theme usage |
|---|---|---|
| `color/background` | `#111118` | Root `ColorRect`, screen backdrop |
| `color/surface` | `#111118` @ 56% | `StyleBoxFlat.bg_color` — panels, list rows |
| *Surface Hover* (doc only, no var) | `#111118` @ 30% | Button/row hover stylebox |
| `color/accent` | `#D4AF37` | Selected row bg, focus border, values, titles |
| `color/border` | `#3A3A42` | `StyleBoxFlat.border_color` default |
| `color/border-strong` | `#D4AF37` | Border on hover/selected |
| `color/text-primary` | `#FFFFFF` | `font_color` |
| `color/text-secondary` | `#A1A1A1` | `font_color` on secondary labels |
| *Text Muted* (doc only) | `#666666` | Disabled-ish captions |
| *Disabled* (doc only) | `#404040` | `font_disabled_color` |
| `color/overlay` | `#000000` @ 56% | Modal dim layer |
| `UI/Blur Overlay` | `FOREGROUND_BLUR` r=6 | See §6 NEEDS DECISION |

> Note the doc frame lists Text Secondary as `#A0A0A0` but the bound variable
> resolves to `#A1A1A1`. **Use the variable** (`#A1A1A1`) — variables are what the
> screens actually render.

### Shape

| Token | Value | Godot |
|---|---|---|
| `shape/radius-sm` | `0` | `corner_radius_* = 0` — **sharp corners everywhere** |
| `shape/border-default` | `1` | `border_width_* = 1` |
| `shape/border-selected` | `2` | `border_width_* = 2` on selected stylebox |

Effects documented (no variables): Inner Shadow (inset panels), Drop Shadow
(elements above background), Panel Glow (modals/windows). Godot `StyleBoxFlat`
supports shadow_color/shadow_size only — inner shadow has no direct equivalent.

### Typography — **Cormorant Garamond**, sizes 12·14·16·20·24·36

| Role | Weight · Size | Usage | Godot theme type |
|---|---|---|---|
| Display | Bold 36 | Hero, splash | `Label/font_sizes/font_size` variation |
| Title | Bold 24 | Screen titles ("INVENTORY") | Title label variation |
| Heading | SemiBold 20 | Section headers, item names | Heading variation |
| Label | SemiBold 16 | Tabs, buttons, nav | `Button/font_sizes/font_size` |
| Body | Regular 16 | Main readable text | `Label` default |
| Small | Regular 14 | Secondary text, descriptions | Small variation |
| Value | SemiBold 14 | Numeric values, stats | Value variation |
| Caption | Bold 12 | Metadata, tags ("LV. 23") | Caption variation |

> ⚠️ **Blocker:** Cormorant Garamond is **not in the repo**. `find` over the
> project returns no `.ttf`/`.otf` outside `.godot/` editor cache. The splash
> also uses a display face for "Khalahas Heroes" which is likewise absent.
> See §6 NEEDS DECISION #1.

### Spacing

`2xs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · 2xl 32 · 3xl 48`

Semantic: Panel Padding **16** · List Row Padding **12** · Icon-to-Text Gap **8**
· Section Gap **24** · Screen Margin **48**.

---

## 2. Global layout shell

Every Game Menu frame shares one shell. This is the single most valuable finding:
**it already matches the existing Godot node structure.**

```
Figma menu-* frame (1920×1080)
├── world-map-base           (instance, full-bleed illustrated map)
├── map-dim-overlay          (darkening rect)
├── main-layout              (0,0 1920×1016)
│   ├── left-column          (320 wide)
│   │   ├── UI/Top Bar       (320×50)   "MENU"
│   │   └── UI/Game Menu Sidebar (320×966)  9 nav items
│   └── center/right content (1600 wide)
└── Bottom Bar               (1920×64)  hint text + button prompts
```

| Figma shell part | Existing Godot node | Verdict |
|---|---|---|
| `world-map-base` + `map-dim-overlay` | `base_menu.tscn → Background` (`ColorRect`) | **Adapt** — swap ColorRect for TextureRect + dim |
| `UI/Top Bar` "MENU" | `base_menu.tscn → "Menu name"` (`Label`) | **Adapt** — restyle |
| `UI/Game Menu Sidebar` | `vertical_tab_menu.tscn → PanelManager/HBoxContainer/TabButtons` | **Adapt** — restyle + add 2 items |
| center content | `vertical_tab_menu.tscn → *Panel` (`PanelContainer` ×7) | **Adapt** |
| right column (party) | `base_menu.tscn → HBoxContainer/RightPanel` | **Adapt** — see §3 Inventory |
| `Bottom Bar` | — | **Create** |

### Sidebar item delta

| # | Figma sidebar | Godot `TabButtons` child | Action |
|---|---|---|---|
| 1 | World Map | `WorldMapButton` | reorder |
| 2 | Journal | `JournalButton` | reorder |
| 3 | Inventory | `InventoryButton` | reorder |
| 4 | **Healing** | — | **create** |
| 5 | Equipment | `EquipmentButton` | reorder |
| 6 | **Jobs** | — | **create** |
| 7 | Skills | `SkillsButton` | reorder |
| 8 | Status | `StatusButton` | reorder |
| 9 | Miscellaneous | `MiscButton` | rename label |

`game_menu.gd` hardcodes the tab↔panel↔button name maps in four places
(`_apply_localized_labels`, `_collect_content_panels`, `_update_visibility`,
`_update_button_states`). Adding Healing/Jobs means editing all four.

---

## 3. Screen-by-screen mapping

### 3.1 Inventory — `menu-inventory` `46:193`

| | |
|---|---|
| **Figma frame** | `menu-inventory` (`46:193`) |
| **Godot scene** | `SampleProject/Scenes/Menus/Game/inventory_component.tscn` |
| **Godot script** | `SampleProject/Scripts/Menus/Game/inventory_component.gd` (869 ln) |
| **Data source** | `GameManager.inventory_manager` → `get_items_dict()`, `get_item_count()`; `ItemDatabase.get_item_*()` |
| **Verdict** | **Adapt** — logic is sound, layout must change orientation |

**Required changes**

1. **Filter tabs rotate vertical → horizontal.** Godot has a `VBoxContainer`
   (`TabButtons`) on the left; Figma has a horizontal tab row above the list.
   Node type stays `Button` + `ButtonGroup`; container becomes `HBoxContainer`.
2. **Filter categories change.** Godot `FilterType` enum is
   `ALL / ARMOR / WEAPON / MISC`; Figma tabs are
   `ALL / CONSUMABLES / MATERIALS / WEAPONS / KEY ITEMS`. This is an **enum and
   panel change**, not cosmetic — `_apply_filter()` match arms must be rewritten
   and a 5th panel added. **Decision: adopt Figma's five** (see §6 #4), with two
   caveats found by auditing the data — see the vocabulary table below.
3. **List widget.** Godot uses the `godot_tree_table` addon `Table` with
   `header_row = ["Name", "On Hand"]`. Figma shows the same two columns
   (`ITEM NAME` / `ON HAND`) but as styled rows with a 32px icon square,
   selected row = solid `color/accent` with dark text. The `Table` addon is not
   themable to that spec. See §6 NEEDS DECISION #5.
4. **Right party panel.** Figma shows 4 character cards (portrait, name, level
   badge, HP bar, SP bar) plus a PLAYTIME/GOLD header. Godot `base_menu.tscn`
   `RightPanel` has `TimerDisplay` + `GoldDisplay` + a **single** character's
   `CharacterSprite`/HP/MP/Level. PLAYTIME→`TimerDisplay` and GOLD→`GoldDisplay`
   map 1:1. The single-character block must become a 4-card list.
5. **FILTER button** (top-right of tab row) — no Godot equivalent. **Create**
   or omit; see NEEDS DECISION #4.

**New reusable components required:** `UI/Inventory/ItemRow`, `UI/Tab`,
`UI/Party Character Card`, `UI/Bottom Bar`, `UI/Top Bar`.

#### Actual item vocabulary (audited from `Resources/Data/items.json`, 27 items)

`type`: `material` ×14 · `consumable` ×5 · `armor` ×4 · `weapon` ×3 · `currency` ×1
`category`: ore ×4 · metal ×4 · healing ×4 · sword ×3 · wood ×2 · armor ×2 ·
stone · mana · plant · crystal · hide · helmet · shield · currency

| Figma tab | Binds to | Items | Status |
|---|---|---|---|
| ALL | — | 27 | ✅ |
| CONSUMABLES | `type == "consumable"` | 5 | ✅ |
| MATERIALS | `type == "material"` | 14 | ✅ |
| WEAPONS | `type == "weapon"` | 3 | ✅ |
| KEY ITEMS | — | **0** | ❌ **no `key_item` type exists** |

**Two gaps this creates:**

1. **`KEY ITEMS` has no backing data.** No item in `items.json` has
   `type == "key_item"`. The nearest thing is the single `currency` item.
   Options: add a `key_item` type to the JSON schema, bind the tab to
   `currency`, or ship the tab disabled/empty.
2. **`armor` (4 items) loses its tab.** Godot has a dedicated ARMOR filter;
   Figma has none. Those 4 items would be reachable only under ALL. Either add
   armor to WEAPONS (rename → "EQUIPMENT"), or keep a 6th tab off-design.

> **Implementation note:** `ItemDatabase` already builds `items_by_type` and
> `items_by_category` dictionaries at load time (`ItemDatabase.gd:60-70`).
> The new filter should read those instead of `_apply_filter()`'s current linear
> scan over `all_items` with hardcoded `match` arms.

---

### 3.2 Equipment — `menu-equipment` `58:4`

| | |
|---|---|
| **Figma frame** | `menu-equipment` (`58:4`) — ⚠️ **content frame is empty** |
| **Godot scene** | `equipment_component.tscn` (387 B — empty shell) |
| **Godot script** | `equipment_component.gd` (743 ln, builds all UI at runtime) |
| **Data source** | `GameManager.player_state.equipment`, `active_character.update_equipment_bonuses()`, `calculate_max_health/physical_damage/physical_defense/magic_damage/magic_defense/attack_speed/dodge_chance` |
| **Verdict** | **Rebuild layout from components** — the screen frame has no design |

**Critical finding:** `menu-equipment`'s child `CenterRightContent` (`58:33`) is a
1600×1016 frame with **zero children**. The rendered screenshot confirms: sidebar
+ map background only. The equipment design exists **only** as standalone
components on the UI KIT page:

- `UI/Equipment Panel` (`258:5110`, 1020×1016)
- `UI/Attributes Panel` (`258:5111`, 580×1016)
- `UI/Equipment/Slot` (`222:4703`, states: Empty/Default/Hover/Equipped/Disabled)

Implementation must compose those two panels into `CenterRightContent`'s
footprint. See §6 NEEDS DECISION #2.

**Required changes**

1. **Move UI out of GDScript into `.tscn`.** `create_equipment_ui()` builds
   ~200 lines of `Panel.new()` / `VBoxContainer.new()`. Replace with a real scene
   tree; keep `update_display()`, `update_equipped_rows()`, `update_attributes()`,
   `_on_optimize_pressed()`, `_on_unequip_all_pressed()`, `_open_inventory_for_slot()`.
2. **Attribute names already match Figma** — Max HP, Phys. Atk., Phys. Def.,
   Accuracy, Critical / Max SP, Elem. Atk., Elem. Def., Speed, Evasion.
   `menu-status` renders exactly these ten. No rename needed.
3. `Accuracy`, `Critical`, `Max. SP` are **hardcoded placeholders** in
   `update_attributes()` (`"88"`, `"80"`, `"40"`). Figma shows real values. Not a
   UI task — flagged, not fixed.

**New reusable components required:** `UI/Equipment/Slot`, `UI/ListRow`,
`UI/Attributes Panel` rows, `UI/ProgressBar`.

---

### 3.3 Status — `menu-status` `58:719`

| | |
|---|---|
| **Figma frame** | `menu-status` (`58:719`) — fully designed |
| **Godot scene** | `stats_component.tscn` (15 KB, real tree) |
| **Godot script** | `stats_component.gd` |
| **Data source** | `CharacterManager`, `XPManager`, `GameManager.calculate_*` |
| **Verdict** | **Adapt layout, keep data binding** |

**Required changes**

1. **Character selection moves.** Godot has an 8-slot `CharacterGrid` of
   `Button`+`AvatarRect` in the left panel. Figma `menu-status` has **no**
   character grid — it shows one character with a header (portrait, name, `Lv.46`,
   `To Next Level: 23 EXP`, `JP Obtained: 928 JP`). Selection presumably happens
   via the party panel. See §6 NEEDS DECISION #6.
2. **New sections with no Godot equivalent:** `PRIMARY JOB` / `SECONDARY JOB` /
   `WEAPON TYPES` chips, and `Unique Actions & Talents` (PATH ACTION + TALENT
   cards). Both require a Jobs system that does not exist.
3. **Attributes** — two-column layout with Max HP / Max SP as accent progress
   bars, then 8 stat rows. Godot `stats_component.gd` already binds these.
4. **Full-height character art** on the right (920px column). Godot has a
   `ColorRect` placeholder (`CharacterSprite`).
5. **Stat-point spend buttons** (`StrengthButton` etc.) exist in Godot but are
   **absent from the Figma design**. Do not remove — see NEEDS DECISION #6.

---

### 3.4 Skills — `menu-skills` `58:453`

| | |
|---|---|
| **Figma frame** | `menu-skills` (`58:453`) — fully designed |
| **Godot scene** | — (a bare `Label` reading "Skills" in `game_menu_content.tscn`) |
| **Godot script** | — |
| **Data source** | **none — no SkillManager exists** |
| **Verdict** | **Create from scratch** |

Figma design: character header (portrait, name, class, `JP OBTAINED: 928 JP`),
then two class-tree columns — `SHADOW BLADE` (Primary Class Tree) and `THIEF`
(Secondary Class Tree). Each column has `Job Skills` and `Support Skills`
sections of rows with a check/lock icon, learned = accent check, locked = dim,
selected = solid accent. Selected row shows a description box beneath.
Each column header carries `NEXT SKILL COST` in JP.

**Blocker:** requires a skill/JP data model. See §6 NEEDS DECISION #3.

**New reusable components required:** `UI/Skills/SkillRow` (Default/Hover/
Selected/Locked/Disabled), `UI/Skills/Slot`, `UI/Skills Sidebar` (`258:5112`).

---

### 3.5 World Map — `menu-world-map` `94:609`

| | |
|---|---|
| **Figma frame** | `menu-world-map` (`94:609`) |
| **Godot scene** | `metsys_map_component.tscn` |
| **Godot script** | `metsys_map_component.gd` |
| **Data source** | `MetSys.make_map_view()`, `add_player_location()`, `get_explored_ratio()`, `get_current_flat_coords()` |
| **Verdict** | **Fundamental mismatch — see NEEDS DECISION #7** |

Figma shows a **hand-drawn illustrated parchment map** (`UI/World Map Base`,
`68:1900`) with named location markers (`UI/Map/Marker` — Default/Active/
Selected/Visited/Locked), a `UI/Legend Panel` (`258:5080`) listing City/Oasis/
Ruins/Camp/Cave, a compass rose, a scale bar, and a `CURRENT LOCATION` pill.

Godot's MetSys draws a **procedural grid of room cells** from `MetSysSettings.tres`
and pans with arrow keys. These are not the same artifact. The Figma map has no
grid, no room cells, no explored-percentage readout.

`update_percent()` (`"%03d%%"`) has no home in the Figma design.

---

### 3.6 Journal — `journal-main-story` `192:1529`

| | |
|---|---|
| **Figma frames** | `journal-main-story` (`192:1529`), `journal-side-stories` (`192:1636`), `journal-character-detail` (`192:1754`) |
| **Godot scene** | `journal_component.tscn` (657 B) |
| **Godot script** | `journal_component.gd` — **two `pass` bodies, fully stubbed** |
| **Data source** | **none wired** (DialogueQuest is the candidate) |
| **Verdict** | **Create from scratch** |

Figma: header `QUEST JOURNAL / Main Story`, a right-aligned `‹ All Chapters ›`
stepper, and a row of 4 chapter cards. Each card has a vertical gold sword/bookmark
graphic, a `HERO` badge, character name and class. Three frames = three tabs
(Main Story / Side Stories / Character Detail), linked in the prototype only
`journal-side-stories → journal-main-story`.

**New reusable components required:** `UI/Quest List Panel` (`258:5113`),
`UI/Quest Detail Panel` (`258:5114`), `UI/Badge` (`222:4746`).

---

### 3.7 HUD — ⚠️ **no Figma design**

| | |
|---|---|
| **Figma frame** | Section `Game Scene` (`144:1802`) is **empty (0 frames)**. Closest: `desert-oasis-scene` (`144:1735`) in the NPC Interaction section |
| **Godot scene** | `SampleProject/Game.tscn → UICanvas` |
| **Godot scripts** | `HealthBar.gd`, `XPBar.gd`, `CoinCounter.gd`, `LevelUpNotification.gd`, `CombatContextDisplay.gd`, `TutorialHintDisplay.gd`, `ObjectiveHUD.gd` |
| **Data source** | EventBus signals |
| **Verdict** | **Do not touch — Figma shows less, not more** |

`desert-oasis-scene` renders the gameplay view with **exactly one UI element**: a
`✦ MENU` pill button in the top-right corner. No health bar, no XP bar, no coin
counter, no objective tracker.

Godot `Game.tscn/UICanvas` currently instantiates **seven** HUD widgets. Taking
Figma literally would delete all of them — which CLAUDE.md forbids
("Do not remove existing functionality unless explicitly instructed").

**Recommendation:** treat HUD as out of scope for the Figma pass; add only the
`✦ MENU` button. See §6 NEEDS DECISION #8.

---

### 3.8 Pause — `menu-miscellaneous` `58:1246`

| | |
|---|---|
| **Figma frame** | `menu-miscellaneous` (`58:1246`) |
| **Godot scene** | `misc_menu_modal.tscn` |
| **Godot script** | `game_menu.gd::_on_misc_button_pressed()` + `modal_templates.gd` |
| **Data source** | `UIManager.get_modal_layer()`, `SaveSystem` |
| **Verdict** | **Adapt — near-exact match already** |

Figma shows an inline submenu list overlaying the center panel:
`← Settings · Tutorial · Return to Title · Quit the Game`.

`game_menu.gd` **already implements exactly these four**, wired to
`settings_selected`, `tutorial_selected`, `exit_main_menu_selected`,
`exit_game_selected`, with confirm modals from `modal_templates.gd`
(`confirm_exit_to_main_menu()`, `confirm_exit_game_unsaved()`). The only change
is visual: Godot renders it as a floating modal, Figma as an inline list anchored
in the center panel.

**There is no separate "Pause" screen in Figma.** Pause == this menu.
`SampleProject/Scripts/UI/PauseMenu.gd` is dead code — no `.tscn` instantiates it,
no script references `class_name PauseMenu`. See §6 NEEDS DECISION #9.

---

### 3.9 Settings — `settings-display` `17:280` (+3 siblings)

| | |
|---|---|
| **Figma frames** | `settings-display` `17:280`, `settings-audio` `17:409`, `settings-gameplay` `17:632`, `settings-controls` `17:756` |
| **Godot scene** | `options_component.tscn` (9 KB) + `input_options_menu.tscn` |
| **Godot script** | `options_component.gd` / `base_options_component.gd` + `SettingsManager.gd` |
| **Data source** | `GameSettings.gd`, `SettingsModule.gd` (save), Basic Settings Menu addon |
| **Verdict** | **Adapt — different shell, same rows** |

Figma uses a **full-screen shell distinct from the game menu**: breadcrumb
`KHALAHAS HEROES · CONFIGURATION`, title `OPTIONS`, a 56px-wide **icon-only**
left rail (4 tabs: display / audio / gameplay / controls — `UI/Settings Tab`
`117:214`, `UI/Settings Sidebar` `117:834`), a scrollable row list, and a
`Restore Default Settings` button (`UI/Restore Button` `258:5399`).

Row patterns to build: label + `‹ value ›` stepper, label + Enable/Disable
segmented pair (selected = accent fill), label + `− slider + value`.

`options_component.gd` is **dual-mode** (`mode = "main_menu" | "game_menu"`) with
different back-button behavior. That logic must survive the restyle.

**New reusable components required:** `UI/Settings Tab`, `UI/Settings Section
Header` (`218:4264`), `UI/Settings Top Section` (`217:1618`), `UI/Restore Button`,
stepper row, segmented toggle row, slider row.

---

## 4. Figma component → Godot control map

| Figma component | Node ID | Godot reusable scene (to create) | Theme dependency |
|---|---|---|---|
| `UI/Button` (2 types × 6 states) | `222:4628` | `Button` + theme variations `PrimaryButton`/`SecondaryButton` | normal/hover/pressed/focus/disabled StyleBoxFlat |
| `UI/Tab` (5 states) | `222:4639` | `Button` toggle_mode + `TabButton` variation | selected stylebox, accent underline |
| `UI/Sidebar Tab` | `386:6642`, `248:75` | `Scenes/UI/Components/sidebar_tab.tscn` | active/inactive stylebox |
| `UI/Menu Item` | `248:62` | reuse `Button` + `MenuItem` variation | active/inactive |
| `UI/Panel` | `222:4640` | `PanelContainer` + `Panel` stylebox | surface + 1px border |
| `UI/Window` | `222:4642` | `PanelContainer` + `Window` stylebox | surface + glow |
| `UI/ListRow` (5 states) | `222:4681` | `Scenes/UI/Components/list_row.tscn` | row styleboxes |
| `UI/Inventory/ItemRow` (3 states) | `222:4827` | `Scenes/UI/Components/item_row.tscn` | row styleboxes |
| `UI/Inventory/Slot` (5 states) | `222:4692` | `Scenes/UI/Components/inventory_slot.tscn` | slot styleboxes |
| `UI/Equipment/Slot` (5 states) | `222:4703` | `Scenes/UI/Components/equipment_slot.tscn` | slot styleboxes |
| `UI/Skills/SkillRow` (5 states) | `222:4734` | `Scenes/UI/Components/skill_row.tscn` | row styleboxes |
| `UI/Skills/Slot` (5 states) | `222:4839` | `Scenes/UI/Components/skill_slot.tscn` | slot styleboxes |
| `UI/ProgressBar` | `222:4757` | `ProgressBar` + theme | bg + fill stylebox |
| `UI/ResourceBar` (HP/SP/XP/Stamina) | `222:4767` | **reuse** `Scenes/UI/health_bar.tscn`, `xp_bar.tscn` | 4 fill colors |
| `UI/Scrollbar` | `222:4768` | `VScrollBar` theme | grabber + bg stylebox |
| `UI/Tooltip` | `222:4743` | `PanelContainer` + `TooltipPanel` stylebox | surface + border |
| `UI/Badge` | `222:4746` | `Scenes/UI/Components/badge.tscn` | accent bg, caption font |
| `UI/IconButton` (4 states) | `222:4805` | `Button` + `IconButton` variation | square styleboxes |
| `UI/BackButton` | `222:4806` | `Button` + `BackButton` variation | — |
| `UI/HexButton` (yes/no/close) | `222:4840` | **reuse** `Scenes/UI/yes_no_dialog.tscn` | confirm modal |
| `UI/Modal/Confirm` | `258:5332` | **reuse** `modal_dialog.tscn` + `modal_templates.gd` | window stylebox |
| `UI/Modal/ItemPickup` | `222:4880` | properUI Toast or new | window stylebox |
| `UI/Bottom Bar` (gamepad/keyboard) | `121:1073` | `Scenes/UI/Components/bottom_bar.tscn` | caption font |
| `UI/Action Button` (A/B) | `276:467` | `Scenes/UI/Components/action_hint.tscn` | accent circle |
| `UI/NavigationHint` | `222:4794` | part of bottom bar | — |
| `UI/Top Bar` | `390:6411` | part of menu shell | title font |
| `UI/Game Menu Sidebar` | `316:7708` | **adapt** `vertical_tab_menu.tscn` TabButtons | sidebar tab styleboxes |
| `UI/Party Status Panel` | `68:1177` | **adapt** `right_panel_component.tscn` | panel stylebox |
| `UI/Party Character Card` | `324:6127` | `Scenes/UI/Components/party_card.tscn` | panel + resource bars |
| `UI/Party Effect Card` | `324:6790` | `Scenes/UI/Components/effect_card.tscn` | panel stylebox |
| `UI/CharacterSelector` | `222:4786` | `Scenes/UI/Components/character_selector.tscn` | — |
| `UI/Map/Marker` (5 states) | `222:4785` | `Scenes/UI/Components/map_marker.tscn` | marker styleboxes |
| `UI/Legend Panel` | `258:5080` | `Scenes/UI/Components/map_legend.tscn` | panel stylebox |
| `UI/Settings Tab` | `117:214` | `Scenes/UI/Components/settings_tab.tscn` | icon tab styleboxes |
| `UI/Diamond Divider` | `217:3017` | `Scenes/UI/Components/diamond_divider.tscn` | — |
| `UI/Potion Slot` | `258:5348` | `Scenes/UI/Components/potion_slot.tscn` | slot stylebox |

**Reuse-first wins** (no new scene needed): `UI/ResourceBar`→`health_bar.tscn`/
`xp_bar.tscn`, `UI/Modal/Confirm`→`modal_dialog.tscn`, `UI/HexButton`→
`yes_no_dialog.tscn`, playtime→`timer_display.tscn`, gold→`gold_display.tscn`.

---

## 5. Shared theme plan (Phase 4)

**Target:** `SampleProject/Resources/UI/ui_theme.tres`

**Current state: the file is empty.** It contains exactly:

```
[gd_resource type="Theme" format=3]

[resource]
```

Zero type entries, zero styleboxes, zero fonts. `project.godot` has **no `[gui]`
section**, so `gui/theme/custom` is unset. Only 9 scenes reference any theme, and
all current styling is per-node `theme_override_*`.

Phase 4 is therefore **create**, not normalize.

### ✅ Phase 4 delivered (2026-09-26)

The theme lives at **`res://SampleProject/UI/Themes/GameUITheme.tres`**, not at
the old `Resources/UI/ui_theme.tres` (which remains an empty stub — see
Deviations). It is **not** project-global; `project.godot` is unchanged.

Applied at two anchors, which together cover all our menu UI and nothing else:

| Anchor | Covers |
|---|---|
| `ui_root.tscn → UILayer/StateRoot` | every `UIManager` state |
| `modal_layer.tscn → ModalLayer/Container` | every modal |

Project-wide scoping is deliberately deferred — see
`design/ui_theme_scope_audit.md` for the measured impact (9 HUD Controls and
16+ third-party scenes would be restyled with no reference art).

Contents:

- `default_font` = Cormorant Garamond (`SampleProject/Assets/Fonts/`), `default_font_size = 16`
- `Label`, `Button`, `PanelContainer`, `ProgressBar`, `VScrollBar`, `HScrollBar`,
  `LineEdit`, `HSlider`, `TabBar`, `PopupPanel` base entries
- Theme type variations: `TitleLabel`, `HeadingLabel`, `SmallLabel`, `ValueLabel`,
  `CaptionLabel`, `PrimaryButton`, `SecondaryButton`, `TabButton`, `SidebarTab`,
  `IconButton`, `SurfacePanel`, `WindowPanel`, `TooltipPanel`
- StyleBoxFlat set per state: normal / hover / pressed / focus / disabled, all
  `corner_radius = 0`, `border_width = 1` (2 when selected)

---

## 6. NEEDS DECISION

### ✅ Resolved (2026-09-26)

| # | Decision | Consequence |
|---|---|---|
| 1 | **Add Cormorant Garamond** (SIL OFL) to `SampleProject/Assets/Fonts/` | Theme typography builds against real metrics. The "Khalahas Heroes" display face is still missing — affects splash only, not the 9 screens. |
| 4 | **Adopt Figma's five inventory categories** | `FilterType` becomes `ALL/CONSUMABLES/MATERIALS/WEAPONS/KEY_ITEMS`. ⚠️ Audit found `KEY ITEMS` has **zero** backing items and `armor` (4 items) loses its tab — see §3.1. Both need a follow-up call before the enum is rewritten. |
| 5 | **Replace the `godot_tree_table` `Table` addon** with a themed `VBoxContainer` of `item_row.tscn` | `_refresh_display()`, `set_table()`, `_setup_all_tables()` and the `CLICK_ROW_INDEX`/`DOUBLE_CLICK` wiring are rewritten. Equip flow (`_on_item_double_clicked` → `_equip_item`) must be preserved verbatim. |
| 11 | **Scoped theme, not project-global.** `GameUITheme.tres` applied at `StateRoot` + `ModalLayer/Container` | Our menus inherit; addons and HUD untouched. Project-wide deferred until the preconditions in `ui_theme_scope_audit.md` §4 are met. |
| 4a | **`KEY ITEMS` tab stays visible but disabled** until key-item content exists | No fake items added to `items.json`. Theme's `TabButton/disabled` state covers the look. |
| 4b | **WEAPONS → EQUIPMENT**, bound to `type in ["weapon", "armor"]` | All 7 weapon+armor items get a tab. One Figma label deviates — logged in Deviations. |
| 2b | **Filtering reads `ItemDatabase.items_by_type`** instead of the linear scan | No duplicated index. `_apply_filter()`'s hardcoded `match` arms go away in Phase 5. |

### Open

| # | Question | Why it blocks | Recommendation |
|---|---|---|---|
| 2 | **`menu-equipment` has no content design** (`CenterRightContent` is empty). Compose from `UI/Equipment Panel` + `UI/Attributes Panel`, or wait for the frame? | Equipment is #2 in the implementation order. | Compose from the two components; confirm the intended split (1020 + 580 of 1600). |
| 3 | **Skills has no data model.** No `SkillManager`, no skill/JP resources, no class trees. | Screen #4 cannot bind to anything. | Either supply a skill spec, or I build the UI against a placeholder `Resource` shape and wire it later. |
| 4c | **The `FILTER` button** (top-right of the Inventory tab row) has no defined behavior — no prototype reaction, no Godot equivalent. | Unknown scope. | Omit for now; add when its behavior is specified. |
| 6 | **Status: the 8-slot character grid and the stat-point spend buttons are absent from Figma.** Keep them, or drop? | CLAUDE.md forbids removing functionality without instruction. | Keep both; relocate the grid into the party panel. Confirm. |
| 7 | **World Map: MetSys grid vs. illustrated parchment map.** These are different artifacts. Replace MetSys rendering with a static map + markers, or keep MetSys and restyle only the frame? | Screen #5. Affects `metsys_map_component.gd`, `MetSysSettings.tres`, and room discovery. Also `update_percent()` has nowhere to go in the Figma design. | Keep MetSys for gameplay (room tracking, minimap) and build the Figma map as a **separate presentational screen**. Needs your call. |
| 8 | **HUD: Figma shows only a `✦ MENU` button** — no health/XP/coins/objectives. Godot has 7 HUD widgets. | Literal implementation deletes working features. | Out of scope; add only the MENU button. Confirm. |
| 9 | **`Scripts/UI/PauseMenu.gd` is dead code** (no `.tscn`, no references). Delete it? | Otherwise it stays as a misleading second pause implementation. | Delete in a separate cleanup commit, not during a screen pass. |
| 10 | **Two new sidebar items — Healing and Jobs — have no Godot systems.** In scope for this pass? | Adding them touches 4 hardcoded maps in `game_menu.gd`. | Add the sidebar buttons as disabled placeholders now; build the screens later. |
| 12 | **`UI/Blur Overlay`** is a `FOREGROUND_BLUR` effect. Godot has no built-in Control blur. | The menu's map background is blurred behind panels in every frame. | Use a `BackBufferCopy` + blur shader, or pre-blur the map texture. Pre-blurred texture is cheaper. |

---

## 7. Proposed implementation order (Phase 5)

Order per the brief, with blockers noted:

| # | Screen | Blocked by |
|---|---|---|
| 0 | **Shared theme + shell** (Phase 4) | #12 only — #1 and #11 resolved, ready to start |
| 1 | Inventory | #4a, #4b |
| 2 | Equipment | #2 |
| 3 | Status | #6 |
| 4 | Skills | #3 |
| 5 | World Map | #7 |
| 6 | Journal | — (design exists; needs a quest data source) |
| 7 | HUD | #8 |
| 8 | Pause | #9 |
| 9 | Settings | — (cleanest mapping of the nine) |

Phase 4 must land before screen 1 — otherwise every screen re-hardcodes styling,
which CLAUDE.md forbids.

---

## 8. Phase 4 deliverables (2026-09-26)

| File | Purpose |
|---|---|
| `SampleProject/Assets/Fonts/CormorantGaramond.ttf` | Variable font (SIL OFL), 400–700 |
| `SampleProject/Assets/Fonts/OFL.txt` | License |
| `SampleProject/UI/Tokens/UITokens.gd` | `class_name UITokens` — all Figma tokens as constants |
| `SampleProject/UI/Themes/GameUITheme.tres` | Generated theme, 27 types |
| `SampleProject/UI/build_game_ui_theme.gd` | Regenerates the theme from tokens |
| `SampleProject/UI/verify_game_ui_theme.gd` | 28-assertion self-check |
| `SampleProject/UI/Components/menu_shell.tscn` / `.gd` | Common menu shell (`class_name UIMenuShell`) |
| `SampleProject/UI/Components/bottom_bar.tscn` / `.gd` | Figma `UI/Bottom Bar` (`class_name UIBottomBar`) |
| `Scenes/UI/ui_root.tscn` *(modified)* | `StateRoot.theme = GameUITheme` |
| `Scenes/UI/modal_layer.tscn` *(modified)* | `Container.theme = GameUITheme` |

Regenerate after editing tokens:

```bash
godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd
godot --headless --path . --script res://SampleProject/UI/verify_game_ui_theme.gd
```

### Theme type variations available to screens

`DisplayLabel` `TitleLabel` `HeadingLabel` `UILabel` `SmallLabel` `ValueLabel`
`CaptionLabel` `AccentLabel` `MutedLabel` · `PrimaryButton` `TabButton`
`SidebarTab` `IconButton` · `WindowPanel` `PlainPanel` `InsetPanel`

### Deviations from Figma

| # | Figma | Implemented | Why |
|---|---|---|---|
| 1 | `UI/Blur Overlay` — `FOREGROUND_BLUR` radius 6 | Translucent `ColorRect` at `color/overlay` (#000 @ 56%) | Godot has no built-in Control blur. The map already sits under a heavy dim, so radius-6 blur is close to imperceptible at 1080p. **Static pre-blurred texture was explicitly ruled out.** If the blur proves necessary, upgrade to `BackBufferCopy` + screen-texture shader on `DimOverlay` — no other node changes. |
| 2 | Inner Shadow (inset panels) | `InsetPanel` = darker bg + 1px border | `StyleBoxFlat` has outer shadow only. |
| 3 | Panel Glow (modals/windows) | `WindowPanel` = accent 1px border + drop shadow | Same limitation. |
| 4 | Sidebar active item: `›` chevron prefix | 4px accent left border | Chevron is a glyph asset not yet exported from `🎨 Icons & Assets`. |
| 5 | Action badges are circles; `shape/radius-sm = 0` | Badges keep a circular radius | Matches `UI/Action Button` (276:467). The one intentional exception to radius-0, marked in `bottom_bar.gd`. |
| 6 | Inventory tab `WEAPONS` | `EQUIPMENT` | Decision 4b — covers `weapon` + `armor` so 4 armor items stay reachable. |
| 7 | "Khalahas Heroes" display face (splash) | not sourced | Affects splash only, not the 9 screens. |

### Known follow-up

`SampleProject/Resources/UI/ui_theme.tres` is still the original **empty** Theme
stub, and `CLAUDE.md` still points at it as "the common theme". Both should be
updated to reference `GameUITheme.tres` — left alone here to keep the Phase 4
diff scoped.
