# UI Visual QA

Checklist per screen. Figma is the visual source of truth; existing gameplay code
is the behavioural source of truth.

Capture method: Godot 4.6, `--rendering-driver opengl3`, viewport forced to
1920×1080, viewport texture saved to PNG.

---

## Inventory — `menu-inventory` `46:193`

**Status:** implemented and validated (Phase 5).
**Reference:** `.figma_tmp/inventory.png` · **Build:** `.figma_tmp/inventory_render.png`,
`.figma_tmp/inventory_empty.png` (empty-category state)

### Checklist

| # | Item | Figma | Build | Verdict |
|---|---|---|---|---|
| 1 | Overall proportions | 320 / flex / 400 over 1016 + 64 bar | same | ✅ |
| 2 | Sidebar width | 320 (296 content + 24 right pad) | 320 (296 + 24 separation) | ✅ |
| 3 | Sidebar item height | 45 | 45 | ✅ |
| 4 | Sidebar top padding | 24 | 24 (`TopSpacer`) | ✅ |
| 5 | Sidebar item gap | 16 | 16 | ✅ |
| 6 | Top bar | h 50, px 24, Bold 28 "MENU" | same (`TopBarTitle`) | ✅ |
| 7 | Centre panel | surface bg, **1px accent border**, padding 48, gap 24 | same (`CenterPanel`) | ✅ |
| 8 | Tabs | Bold 18, px 20 py 10, gap 8 | same (`TabButton`) | ✅ |
| 9 | Tab selected state | accent text + 2px accent bottom border | same | ✅ |
| 10 | Tab unselected | `text-secondary` | same | ✅ |
| 11 | **KEY ITEMS disabled** | n/a in Figma (design shows enabled) | visible, dimmed, non-selectable | ✅ *(by instruction)* |
| 12 | FILTER button | 1px accent, radius 3, px 12 py 6, Regular 14 accent | same (`FilterButton`) | ✅ |
| 13 | Column headers | px 16, Bold 14, secondary, "ITEM NAME"/"ON HAND" | same (`ColumnHeader`) | ✅ |
| 14 | Header rule | 1px full-width line | same | ✅ |
| 15 | Row padding | px 16 py 12, gap 12 | same | ✅ |
| 16 | Row gap | 4 | 4 | ✅ |
| 17 | Icon slot | 36×36, `#2a2a35`, 1px border | same; border drops when selected | ✅ |
| 18 | Item name | Medium 18 primary | same (`ListRowTitle`) | ✅ |
| 19 | Count | SemiBold 16 primary, `×N` | same (`ListRowCount`) | ✅ |
| 20 | Row selected | accent fill + 2px accent border, text stays white | same | ✅ |
| 21 | Fonts | Cormorant Garamond 400/500/600/700 | same (one variable font) | ✅ |
| 22 | Text hierarchy | 8 roles | all mapped to theme variations | ✅ |
| 23 | Colours | all bound Figma variables | `UITokens` 1:1 | ✅ |
| 24 | Party panel | w 400, p 24, gap 24, 1px border | same (`SidePanel`) | ✅ |
| 25 | Party card | w 330, p 12, gap 16, 1px accent | same (`CardPanel`) | ✅ |
| 26 | Portrait | 56×56, 1px accent | same | ⚠️ colour swatch, see D4 |
| 27 | Level badge | accent bg, px 6 py 2, Bold 11 | same | ✅ |
| 28 | Stat bars | h 6, w 180, HP `#2ecc71`, SP `#3498db` | same | ⚠️ empty, see D3 |
| 29 | Bottom bar | h 64, px 60, surface, LB/A/B | same | ✅ |
| 30 | Scrolling | list clipped, scrolls | `ScrollContainer`, vertical only | ✅ |
| 31 | Empty category | not designed | centred "No items in this category." | ✅ *(added)* |
| 32 | Background | map art, blur 3px, dim + overlay | map art, dim + overlay, **no blur** | ⚠️ D1 |

### Deviations

| # | Deviation | Reason | Fix path |
|---|---|---|---|
| **D1** | **No 3px background blur.** Figma blurs the map behind the panels. | Godot has no built-in Control blur. Pre-blurred static texture was ruled out. The map already sits under `surface` 56% + `overlay` 56%, so blur is near-imperceptible at 1080p. | `BackBufferCopy` + screen-texture shader on `MapDim`. Single node, no structural change. |
| **D2** | **PLAYTIME reads `00:00:00`.** | `TimerDisplay.gd` binds to a `GameTimer` node that does not exist in any scene; `TimeManager` is a pause manager, not a clock. No playtime value exists to show. | Needs a real playtime clock. Out of Inventory scope. |
| **D3** | **HP/SP show `—/—` with empty tracks.** | `CharacterAttributes` has only strength/intelligence/dexterity/constitution. There is **no per-character HP/SP**, and level is a single global `XPManager.get_level()`. Figma shows 4 characters each with their own values. | Per-character vitals model. Deliberately **not** faked. |
| **D4** | **Portraits are colour swatches**, not art. | `GameCharacter.avatar_color` is the only visual the data model provides; no portrait assets exist. | Add portrait textures to `GameCharacter`. |
| **D5** | **Item icons are blue placeholders.** | `ItemDatabase.get_item_icon()` falls back to `_get_placeholder_icon()`; real per-item icons are absent. | Export icons from Figma `🎨 Icons & Assets`. |
| **D6** | **Sidebar has 7 items, Figma has 9**, in a different order. | Figma adds Healing and Jobs, neither of which has any Godot system. Changing the tab set was explicitly out of Inventory scope. | Shell phase; see plan §2. |
| **D7** | **Tab reads `EQUIPMENT`, Figma reads `WEAPONS`.** | Approved decision: Figma's five categories leave `armor` (4 items) with no tab. `EQUIPMENT` binds `type in ["weapon","armor"]`. | Intentional; confirm the Figma label follows. |
| **D8** | **Item details are a tooltip**, not a panel. | The Figma inventory frame has **no** detail panel, but the previous build showed name/description. Losing that would remove functionality. | Confirm intended detail surface. |
| **D9** | **`FILTER` button is inert.** | No prototype reaction and no defined behaviour anywhere in the file. | Needs a spec. |
| **D10** | Off-scale type sizes **11 / 18 / 28** and weight **Medium 500** used. | The frame itself uses them; the documented scale (12·14·16·20·24·36, 4 weights) does not contain them. Frame wins. | Reconcile the UI KIT doc with the frames. |

### Functional verification — 27 assertions, all passing

`godot --headless --path . --script res://SampleProject/UI/verify_inventory.gd`

Opening · closing/back · unpause on close · 5 category tabs with Figma labels ·
KEY ITEMS visible-but-disabled · category switching · EQUIPMENT contains only
weapon+armor · disabled tab refuses selection · empty-category message · row
count matches item count · default selection · details exposed · selection
updates · `set_equipment_selection_mode` preserved · slot filter correct ·
`InventoryManager` save/load round-trip · counts survive reload.

---

## Status — `menu-status` `58:719`

**Status:** implemented and validated (Phase 5.2).
**Reference:** `.figma_tmp/status.png` · **Build:** `.figma_tmp/status_render.png`

### Checklist

| # | Item | Figma | Build | Verdict |
|---|---|---|---|---|
| 1 | Column split | 320 / 940 / 640 portrait | same (centre flexes, portrait 640) | ✅ |
| 2 | Centre padding | 48 | 48 | ✅ |
| 3 | Section gap | 32 | 32 | ✅ |
| 4 | Avatar | 96×96, **2px** border | same | ⚠️ colour swatch, D4 |
| 5 | Name | Bold **48** primary | same (`StatusName`) | ✅ |
| 6 | Level | Bold **22** accent | same (`StatusLevel`) | ✅ |
| 7 | Meta row | Regular 14 secondary + SemiBold 16; JP in accent | same | ✅ |
| 8 | Divider | 1px, h 12 | same | ✅ |
| 9 | Header rule | 1px full width | same | ✅ |
| 10 | Job captions | Regular **13** secondary uppercase | same (`SectionCaption`) | ✅ |
| 11 | Job boxes | surface, 1px border, p 12, SemiBold **18** | same (`BoxPanel`, `JobName`) | ✅ |
| 12 | Weapon slots | 40×40 boxes, gap 12, row h 46 | same | ⚠️ D13 |
| 13 | Section headers | SemiBold 14 **accent** | same (`SectionHeader`) | ✅ |
| 14 | Attribute columns | 2 × flex, gap 40 | same | ✅ |
| 15 | Meter | label + Bold **20** value + " / max"; track h **4**, accent fill | same (`MeterValue`) | ✅ |
| 16 | Attribute rows | py 8, 1px bottom border, icon 16 + gap 10, Regular 16 label, Bold **18** value | same (`AttrLabel`/`AttrValue`) | ✅ |
| 17 | Row order | HP·PAtk·PDef·Acc·Crit / SP·EAtk·EDef·Spd·Eva | same | ✅ |
| 18 | Action cards | surface, 1px, p **18**, gap 8; caption 13 accent + 1px accent divider + Bold 20 title | same (`ActionCard`) | ✅ |
| 19 | Bottom bar | h 64, px 60 | same | ✅ |
| 20 | Background | map + dim | same | ⚠️ D1 (no blur) |

### Deviations (Status)

| # | Deviation | Reason |
|---|---|---|
| **D11** | **`JP Obtained` shows `—`.** | No Job Points system exists anywhere in the project. Not fabricated. |
| **D12** | **`Max. SP` shows `—` with an empty meter.** | Same missing SP model as the party panel (D3). |
| **D13** | **Weapon-type slots show one `—` box.** | Derived from actually-equipped weapon slots; nothing is equipped by default. Renders real state, not a fixed pair of icons. |
| **D14** | **`PRIMARY JOB` / `SECONDARY JOB` show `—`.** | The file was **never implemented** (see `design/investigation_pathfinder_classes.md`). Phase 5.4 created `pathfinder_classes.json` as **schema-only infrastructure** using the class ids CharacterManager already declares; names/descriptions are intentionally empty, so Status renders `—` rather than a blank. Authoring the content is a game-design task. |
| **D15** | **`Unique Actions & Talents` cards are empty shells.** | No Path Action / Talent system exists. Figma structure kept, content not invented. |
| **D16** | **Right 640 column is empty.** | Character portrait art does not exist and portraits are an agreed data gap — the Figma portrait was deliberately **not** imported, since it depicts a different character. |
| **D17** | **Attribute-row icons are plain squares.** | Icon set not yet exported from Figma `🎨 Icons & Assets` (same as D5). |
| **D18** | **No character-selection grid.** | Figma's Status frame has none; the previous build had an 8-slot grid. Selection is expected to come from the party panel. Open decision (plan §6 #6). |
| **D19** | **Party panel is hidden while Status is open.** | Figma replaces the 400px party column with a 640px portrait on this screen. Implemented via the `ui_party_panel` group; belongs in the shell phase. |

### Functional verification — 20 assertions, all passing

`godot --headless --path . --script res://SampleProject/UI/verify_status.gd`

Open via tab switch · valid `game_manager` · name from `CharacterManager` ·
level from `XPManager` · EXP-to-next shown · JP/SP placeholders · 4+4 attribute
rows · real Max HP · **Phys. Atk. equals `StatCalculator` output** · `level_up`
refreshes live · party panel hides and restores · close/unpause.

---

## Equipment — `UI/Equipment Panel` `258:5110` + `UI/Attributes Panel` `258:5111`

**Status:** implemented and validated (Phase 5.3).
**Reference:** `.figma_tmp/eq_panel.png`, `.figma_tmp/eq_attrs.png` ·
**Build:** `.figma_tmp/equipment_render.png`
(The `menu-equipment` frame `58:4` itself is an empty shell — see plan §3.2.)

### Checklist

| # | Item | Figma | Build | Verdict |
|---|---|---|---|---|
| 1 | Panel split | 1020 / 580 (≈1.76:1) | same via stretch ratio | ✅ |
| 2 | Eyebrow | "CURRENT CHARACTER", 13 accent | same (`PanelEyebrow`) | ✅ |
| 3 | Character name | Bold ~24 + small avatar | same (`BigValue`) | ⚠️ avatar is a colour swatch, D4 |
| 4 | Right heading | "Category" accent + "Manage Hero Loadout" | same (`PanelHeading`) | ✅ |
| 5 | Rules above/below list | 1px | same | ✅ |
| 6 | Slot row | icon 40 + caption + item name + accent dot | same | ⚠️ icons D17 |
| 7 | Caption style | secondary uppercase | same (`SlotCaption`) | ✅ |
| 8 | Equipped name | Bold 20 primary | same (`SlotItemName`) | ✅ |
| 9 | Empty state | "(empty)", muted | same (`SlotItemEmpty`) | ✅ |
| 10 | Accent dot | only when equipped | same | ✅ |
| 11 | OPTIMIZE | accent-filled | same (`PrimaryButton`) | ✅ |
| 12 | UNEQUIP ALL | accent outline + ✕ | same (`FilterButton`) | ✅ |
| 13 | Attributes header | accent | same (`PanelHeading`) | ✅ |
| 14 | Attribute grid | 2 cols, label + value + green `(+N)` | same | ✅ |
| 15 | Delta colour | green | `HP_FILL` `#2ecc71` (`StatDelta`) | ✅ |
| 16 | Character art | full illustration | empty framed area | ⚠️ D16 |
| 17 | Scrolling | 8 rows fit | 11 rows, vertical scroll | ✅ |

### Deviations (Equipment)

| # | Deviation | Reason |
|---|---|---|
| **D20** | **11 slot rows, Figma shows 8.** | ✅ **Approved — keep all 11.** `player_state.equipment` defines 11 slots; Figma omits polearm, axe and staff. Working gameplay capability is not hidden to match a frame. **→ FIGMA NEEDS UPDATE:** `UI/Equipment Panel` (258:5110) should gain rows for POLEARMS, AXES and STAVES. |
| **D21** | **Slot icons are plain squares.** | Icon set not exported yet (same as D5/D17). |
| **D22** | **No per-slot unequip.** | Figma offers only `UNEQUIP ALL`; the previous build had no per-slot unequip either. Selecting a slot and picking a different item replaces it. |
| **D23** | **Attributes panel art area is empty.** | Portrait art is an agreed data gap (D16). Frame kept so the layout matches. |
| **D24** | **`Max. SP` shows `—` without a delta.** | No SP model (D12). |
| **D25** | **Party panel stays visible.** | The Figma Equipment frame is empty, so it gives no guidance on the right column. Left as-is rather than guessed. |

### Functional verification — 32 assertions, all passing

`godot --headless --path . --script res://SampleProject/UI/verify_equipment.gd`

Open/close · unpause · **11 rows match `player_state.equipment` exactly** ·
keyboard-focusable rows + bottom-bar hint · empty vs equipped row state ·
equipping raises Phys. Atk. by exactly the item's `attack` · `player_state`
updated (save-visible) · replacement swaps rather than duplicates · incompatible
item refused · **Status reflects the change with no sync code** · unequip-all
clears every slot and reverts stats · optimize picks the stronger sword ·
inventory counts unchanged · state round-trip rehydrates the character.

---

## Skills — `menu-skills` `58:453`

**Status:** implemented and validated (Phase 5.6).
**Reference:** `.figma_tmp/skills.png` ·
**Build:** `.figma_tmp/skills_empty.png` (production), `.figma_tmp/skills_populated.png` (test fixtures)

Two visual passes were captured, as required: the real empty production database,
and the same screen driven by test-only fixtures.

### Checklist

| # | Item | Figma | Build | Verdict |
|---|---|---|---|---|
| 1 | Layout | sidebar 320 + center-content flex, padding 48, gap 32 | same | ✅ |
| 2 | Profile header | avatar + name + class + JP OBTAINED | same (+ SP, see D27) | ✅ |
| 3 | Columns wrapper | 2 equal columns, gap **48** | same | ✅ |
| 4 | Column panel | surface bg, 1px border, padding **32**, gap 16 | same (`TreePanel`) | ✅ |
| 5 | Column title | Bold 28 accent | same (`TreeTitle`) | ⚠️ renders `—`, D14 |
| 6 | Subtitle | "Primary/Secondary Class Tree" | same | ✅ |
| 7 | NEXT SKILL COST | caption + value, right aligned | same, derived from cheapest unlearned | ✅ |
| 8 | Section labels | "Job Skills" / "Support Skills", Regular 16 secondary | same (`SectionLabel`) | ✅ |
| 9 | Row metrics | px 16, py 10, icon→text gap 12, 1px border | same (`SkillRow`) | ✅ |
| 10 | Learned row | check marker + Medium 18 primary | accent marker + primary | ⚠️ D28 |
| 11 | Locked row | empty 14px box + Medium 18 secondary | same | ✅ |
| 12 | Prereq-hidden row | lock glyph + `???` | empty marker + `???` | ⚠️ D28 |
| 13 | Selected row | accent fill, Bold 18, JP cost right | same | ⚠️ D26 (colour) |
| 14 | Details surface | `UI/Tooltip` panel inside the column | bottom-bar context line | ⚠️ D29 |
| 15 | Bottom bar | h 64, px 60 | same | ✅ |
| 16 | Empty state | not designed | "No skills available yet.", JP still shown | ✅ *(added)* |
| 17 | Focus state | — | 2px accent focus border | ✅ |

### Deviations (Skills)

| # | Deviation | Reason |
|---|---|---|
| **D26** | **Selected-row JP cost uses dark-on-accent, not accent-on-accent.** | ✅ **Approved — keep.** Figma sets accent text on an accent fill (`58:593` on `bg-accent`), which is invisible. Using `ON_ACCENT` for legibility. **→ FIGMA NEEDS CORRECTION.** |
| **D27** | **SP is NOT shown on the Skills screen.** | ✅ **Approved — removed.** SP stays a real gameplay resource in the data model, but it belongs to the combat HUD, not the progression screen. Re-add only if an approved Figma revision places it here. |
| **D28** | **Row markers are squares, not check-circle / lock glyphs.** | Those icons are not exported yet (same gap as D5/D17/D21). Learned = filled accent square, locked = outlined, hidden = muted outline. |
| **D29** | **Skill details render in the bottom bar, not the in-column tooltip panel.** | ✅ **Approved — keep.** One shared context surface for mouse, keyboard and gamepad, matching Inventory (D8). No second tooltip system. The Figma `UI/Tooltip` sits inside the secondary column only and cannot serve a primary-column selection. |
| **D30** | **No skill-tree connectors.** | None exist in Figma either — the frame is two flat lists. Confirmed via `get_design_context`; see `design/skills_ui_mapping.md`. **No `ui_position` / `tree_row` field was needed.** |
| **D31** | **No unlock confirmation modal.** | Figma specifies none for Skills, so none was invented. Unlock is immediate via `SkillManager`. |
| **D32** | **Production screen is empty.** | `skills.json` intentionally has no content. The screen states this honestly rather than showing fabricated skills. |

### Functional verification — 44 assertions, all passing

`godot --headless --path . --script res://SampleProject/UI/verify_skills_ui.gd`

Opens/closes · empty production DB does not crash · columns generated from data ·
**a new skill appears without editing the `.tscn`** · no fixture name is hardcoded
in the scene · row states match `SkillManager` verdicts (learned / affordable /
not enough JP / prerequisite / level) · focus updates details identically to click ·
JP and SP costs shown · refusal reasons come from `SkillManager`, not re-implemented ·
unlock through UI deducts exact JP and refreshes immediately · duplicate unlock
refused · **UI source contains no `player_state` or `unlocked_skills` writes** ·
`job_points_changed` / `sp_changed` refresh live · save/load preserves presentation ·
traversal `Player.abilities` unaffected · party panel restored on leave.

---

## World Map — `menu-world-map` `94:609`

**Status:** restyled and validated (Phase 5.10). MetSys behaviour untouched.
Full element mapping: `design/world_map_mapping.md`.

| # | Item | Figma | Build | Verdict |
|---|---|---|---|---|
| 1 | Map viewport | `center-content` 1600×1016 | same, MetSys MapView | ✅ |
| 2 | Title block | Bold **44** accent uppercase + 32px rules + Regular 18 sub, centred, gap 2/16 | same (`MapTitle`/`MapSubtitle`) | ✅ |
| 3 | Background | illustrated parchment | shared shell `MapBackground` | ✅ |
| 4 | Player marker | — | `MetSys.add_player_location()`, real coords | ✅ |
| 5 | Explored % | **absent from Figma** | kept + restyled (`EXPLORED 020%`) | ⚠️ D39 |
| 6 | Legend | 208×196 panel, 5 categories | **not built** | ⚠️ D40 |
| 7 | Named markers | 13 fixed-position markers | **not built** | ⚠️ D41 |
| 8 | Bottom bar | shared | shared, hints truthful | ✅ |
| 9 | Local styles | — | duplicate `StyleBoxFlat_bg` removed | ✅ |

### Deviations (World Map)

| # | Deviation | Reason |
|---|---|---|
| **D39** | **Explored percentage kept although Figma omits it.** | Working feature (`MetSys.get_explored_ratio()`); removing it would delete functionality. Restyled with theme tokens into an `EXPLORED` panel bottom-left. |
| **D40** | **Legend not built.** | Its five categories (City/Oasis/Ruins/Camp/Cave) describe the named markers, which have no backing data. A legend explaining absent symbols would mislead. **NEEDS DESIGN DECISION.** |
| **D41** | **13 named location markers not built.** | Figma places them at fixed pixel positions. The project has **no named-location dataset** — MetSys stores a grid of room cells, not points of interest with display names or world coordinates. Building them means inventing both the data and a world→screen projection, which §2 forbids. **NEEDS DESIGN DECISION.** |
| **D42** | **Illustrated map vs MetSys grid.** | Figma draws a hand-illustrated world; MetSys renders discovered room cells procedurally. The illustration cannot show real exploration state. Grid kept as the live map, illustration kept as background art. **NEEDS DESIGN DECISION** to resolve properly. |

### Fixed during this phase

`_input()` compared raw `event.keycode == KEY_LEFT/RIGHT/UP/DOWN`, bypassing the
rebinding system. Replaced with `ui_left/right/up/down` actions; panning is
otherwise identical and asserted by test.

### Functional verification — 33 assertions, all passing

`godot --headless --path . --script res://SampleProject/UI/verify_world_map.gd`

Opens via tab · previous screen hides · MapView and player marker created ·
centring and percentage APIs intact · percent matches `MetSys.get_explored_ratio()` ·
offset centres on the **real** player cell · no hardcoded `KEY_*` · pans on
`ui_right` · hints truthful and free of unimplemented actions · Figma chrome
present · duplicate local style gone · menu close/reopen loses no map state ·
MetSys exploration data unchanged · map survives cycling every tab.

---

## Not yet implemented

Journal · Pause · Settings.

### Pre-existing gaps surfaced during Phase 5

Fixing `ServiceLocatorHelper` (see below) gave every `BaseMenuComponent` a real
`game_manager` for the first time, which exposed calls that were previously
silently skipped:

| Call site | Missing on `GameManager` | Status |
|---|---|---|
| `equipment_component.gd:407`, `stats_component.gd:183,210` | `get_active_character()` | ✅ delegate added |
| `stats_component.gd:68` | `characters` | ✅ delegate added |
| inventory/equipment equip flow | `player_state`, `active_character`, `active_character_id` | ✅ delegates added |
| `stats_component.gd` | `get_all_characters()` | ✅ delegate added |
| `equipment_component.gd` | `calculate_max_health()` + 8 siblings | ✅ **Phase 5.1** — thin delegates to `StatCalculator` for the active character |
| `stats_component.gd` | `get_class_data()` | ✅ **Phase 5.1** — delegate to `CharacterManager` |
| `stats_component.gd` | `switch_character()`, `get_current_player()` | ✅ **Phase 5.1** — delegates |
| `stats_component.gd` | `add_stat_point()` | ❌ **deliberately not added** — this project excludes the stat-point pool entirely (`"Исключены … stat_points"` in `CharacterManager`/`PlayerStateManager`), so spending would have no budget. Figma's Status frame has no spend buttons either. |

**Result: the menu now opens with zero script errors.** Verified across
`verify_inventory.gd` and `verify_status.gd`.

### Phase 5.1 — UI data contract

`GameManager` gained **thin delegates only**; no formula or class definition was
duplicated:

| Delegate | Owner it forwards to |
|---|---|
| `calculate_max_health/physical_damage/magic_damage/physical_defense/magic_defense/attack_speed/dodge_chance/accuracy/critical_chance` | `StatCalculator` (statics), resolved for the active character |
| `get_class_data()` | `CharacterManager` → `pathfinder_classes.json` |
| `switch_character()`, `get_all_characters()`, `get_active_character()`, `characters`, `active_character`, `active_character_id` | `CharacterManager` |
| `player_state` | `PlayerStateManager` |
| `get_current_player()` | `GameGroups.PLAYER` group lookup |

Two private helpers, `_active_attributes()` and `_active_equipment_stats()`,
exist purely so the nine stat delegates don't repeat the lookup.

`verify_inventory.gd` asserts `game_manager.calculate_max_health()` is
**identical** to a direct `StatCalculator` call — a duplicated formula would fail
that check.

---

## Root-cause fix logged during Phase 5

`ServiceLocatorHelper.get_service_locator()` used
`Engine.has_singleton("ServiceLocator")`. **Godot 4 autoloads are not registered
as Engine singletons** — they are nodes under `/root`. The check was therefore
always `false` and the helper always returned `null`, so every
`BaseMenuComponent` subclass (Inventory, Equipment, Status, Journal) ran with
`game_manager == null`. That is why the inventory never listed any items.

Fixed by resolving through `Engine.get_main_loop().root.get_node_or_null(^"ServiceLocator")`,
keeping the old singleton path as a fallback. One function; all callers benefit.

---

## Regression status

| Check | Result |
|---|---|
| Asset import | no errors |
| Headless boot | identical to pre-Phase-4 baseline (only the pre-existing `MusicManager: Music config file not found`) |
| Theme self-check (28 assertions) | ALL PASS |
| Inventory suite (27 assertions) | ALL PASS |
| Menu open/close/unpause | pass |
| Third-party UI isolation | pass — addon scenes do not inherit `GameUITheme` |
| GUT suite | ⚠️ **pre-existing failure.** Segfaults with 19 `An instance of a Double was expected` errors. Verified against a clean `git stash` of all Phase 4–5 work: **identical 19 errors and same segfault**, so this is a GUT/Godot 4.6 incompatibility, not a regression. |


---

## Systemic finding — `Engine.has_singleton("ServiceLocator")`

Godot 4 autoloads are **not** Engine singletons, so this check is always `false`.
The codebase contains **94 such call sites**, every one of them a silently dead
branch. Phase 5.3 fixed only the three on the equipment path:

| File | Why it had to be fixed |
|---|---|
| `ServiceLocatorHelper.gd` | (Phase 5.1) every `BaseMenuComponent` had a null `game_manager` |
| `CharacterManager.gd` | its `game_manager` was null, so `_sync_player_state_from_character()` returned early and **equipment never reached the save data** |
| `EquipmentManager.gd` | dependency resolution |
| `Character.gd` | `item_database` was null, so `get_equipment_stats()` returned all zeros and **equipping changed no stat at all** |

A related defect, `game_manager.has("…")` (`Object` has no `has()` in Godot 4),
was fixed at 8 call sites — including **both** in `PlayerDataModule`, the save
module, where it was aborting player-data save/load outright.

**The remaining ~90 `Engine.has_singleton` sites are untouched.** Fixing them
wholesale would activate ~90 dormant code paths simultaneously; each needs its
own verification. Recommended as a dedicated pass.


---

## Combat HUD — `Game Scene / Combat HUD` `434:6556`

**Status:** hotbar + vitals implemented and validated (Phase 5.7).
**Build:** `.figma_tmp/hud_hotbar.png`

The phase was previously halted because the HUD did not exist. Figma has since
added it; all five blocking questions resolved — see `design/combat_hud_mapping.md`.

### Checklist

| # | Item | Figma | Build | Verdict |
|---|---|---|---|---|
| 1 | Hotbar position | bottom-centre, 24px bottom margin | same (anchor bottom-centre, offsets −111/−24) | ✅ |
| 2 | Hotbar panel | surface bg, **1px accent border**, padding 10, gap 12 | same | ✅ |
| 3 | Slot count | **4** | 4, from `SkillManager.SLOT_COUNT` | ✅ |
| 4 | Slot size | 48×48, icon 28 centred | same | ✅ |
| 5 | Bind badge | Bold 11, px6 py1, below slot, gap 4 | same (`BindBadge`) | ✅ |
| 6 | Ready/usable state | 2px accent border + glow, accent badge w/ dark text | same | ✅ |
| 7 | Equipped normal | 1px `#3a3a42`, `#2a2a35` badge | same | ✅ |
| 8 | Cooldown | icon + `rgba(17,17,24,0.75)` overlay, remaining time Bold 16 accent | same, time from `SkillManager` | ✅ |
| 9 | Unavailable | whole group at 40% opacity | same | ✅ |
| 10 | Empty slot | placeholder icon box | same, dimmed placeholder | ✅ |
| 11 | Vitals panel | 360×162 at (24,24), surface + 1px border, padding 16, gap 12 | same | ✅ |
| 12 | Vitals header | name Bold 18 accent uppercase + accent LV badge | same | ✅ |
| 13 | HP / SP / XP rows | label 30 · bar 200×8 · value 80, gap 6 | same | ✅ |
| 14 | Row fills | HP `#2ecc71`, SP `#3498db`, XP accent (muted text) | same | ✅ |
| 15 | BAG section | present in frame | **intentionally absent** — see D33 | ✅ |

### Deviations (Combat HUD)

| # | Deviation | Reason |
|---|---|---|
| **D33** | **BAG removed from scope.** | ✅ **Design decision.** This is a metroidvania with a dedicated Inventory screen; there will be no separate consumable bag/quickbar. `Bag Section` (`434:6593`) is an **obsolete Figma artifact** and is deliberately not implemented — no slots, bindings, save state or logic, and nothing invented in its place. Verified absent from all code, scenes and data. **→ FIGMA: remove Bag Section from the Combat HUD.** |
| **D34** | ✅ **Resolved.** Quest Info Panel and Currency & Settings implemented. | — |
| **D35** | ✅ **Resolved.** All HUD overlaps cleared — see "Legacy widget disposition" below. | — |
| **D36** | **Skill-slot icons remain placeholder boxes.** | Per-skill icon art does not exist in Figma either — `UI/Skills/Slot` ships a plain `#2a2a35` box, and the one real glyph in the HUD (`icon/skills/steal`) belongs to a skill that has no production definition. Shared UI glyphs **are** now imported (below). |
| **D37** | **No controller bindings for slots.** | Figma shows numeric badges `1–4` only; keyboard actions `skill_slot_1…4` added. Controller mapping is undesigned — not invented. |
| **D38** | **No runtime target selection.** | `use_slot()` forwards an explicit target. Auto-targeting remains **GAME DESIGN DECISION REQUIRED**; no nearest-enemy heuristic invented, since none exists elsewhere in combat. |

### Visual completion pass (Phase 5.8)

**Implemented to match Figma:** Player Vitals Panel (HP/SP/XP), Quest Info Panel,
Currency & Settings, MENU entry, Skill Hotbar — all four slot states.

**Shared UI glyphs imported** from Figma into `SampleProject/Assets/UI/Icons/`
and wired up, closing the long-running icon gap (D5/D17/D21/D28):

| Glyph | Source node | Used by |
|---|---|---|
| `check_circle.svg` | `icon/ui/check-circle` `106:661` | Skills — learned row |
| `lock.svg` | `icon/ui/lock` `106:664` | Skills — locked / `???` row |
| `chevron.svg` | `chevron` `382:8126` | Sidebar active-tab marker |
| `quest_marker.svg` | `Quest Icon Box` `434:6581` | HUD quest panel |

**Legacy widget disposition** — bindings preserved, nothing deleted blindly:

| Widget | Action | Why |
|---|---|---|
| `PlayerHealthBar`, `PlayerXPBar` | suppressed via `modulate.a = 0`, node kept | `HealthBar.gd` force-sets `visible = true` (lines 174, 339) and `Player.gd:267` **recreates the node if missing** — so scene-level hiding cannot work and deletion would regenerate it |
| `CoinCounter` | suppressed via `modulate.a = 0` | superseded by Currency Display, same `coins_changed` binding |
| `ObjectiveHUD` | **node removed** | it animates its own `modulate` via tween, so suppression was impossible. `CombatHudTop` replaces it and subscribes to the *same* `Game.objective_updated` signal; no code referenced the node |
| `UI/HBoxContainer` collectible counter | hidden | not present in the Figma HUD |

### Resolution validation

| Resolution | Result |
|---|---|
| 1920×1080 | ✅ reference |
| 1600×900 | ✅ identical composition |
| 1280×720 | ✅ identical composition |

**Root finding:** `project.godot` had **no `[display]` section at all**, so no
stretch policy existed and the UI would not scale below the design resolution.
An earlier capture appeared to show an off-centre quest panel; measuring the
actual rects proved the viewport had never changed — a harness artifact, not a
layout bug. Added the standard policy:

```
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

All three resolutions now resolve to a logical 1920×1080 canvas scaled to the
window, so every anchor and margin holds. This affects **all** screens, not just
the HUD — it is the first stretch policy the project has ever had.

### Functional verification — 62 assertions, all passing

`godot --headless --path . --script res://SampleProject/UI/verify_hotbar.gd`

4 slots from Figma · slot validation · only unlocked **active** skills equip ·
passive refused · locked refused · unknown refused · invalid slot refused ·
**duplicates move rather than duplicate** · swap · unequip · loadout separate
from progression · empty slot does nothing and spends nothing · equipped slot
invokes `SkillManager` · exact SP consumed · damage via the existing pipeline ·
cooldown blocks reuse, spends nothing, expires, restores ready · insufficient SP
blocks and starts no cooldown · save/load round-trip · **legacy saves without
`equipped_skills` load safely** · hotbar renders manager state incl. cooldown
overlay · **hotbar source contains no `player_state`, no `sp_cost`, no `damage`,
no key polling** · traversal `Player.abilities` unaffected · Equipment stats and
normal attack intact.

---

## ✅ Resolved — the earlier hotbar block

**Historical record.** The phase was halted at step 3 because the HUD did not
exist. Figma has since added `Game Scene / Combat HUD` `434:6556` and all five
questions are answered; the phase shipped. Original finding kept below.

The brief states: *"Use the number of active skill slots defined by the approved
Figma HUD. Do not invent a slot count. If the current Figma design does not
define a hotbar or slot count, stop and report."*

**The Figma file does not define a combat skill hotbar.**

### Evidence

| Check | Result |
|---|---|
| `Game Scene` section (`144:1802`) | **empty** — zero frames |
| `desert-oasis-scene` (`144:1735`) — the prototype's return target from every menu | one UI element only: the `✦ MENU` pill |
| `UI/Skills/Slot` component (`222:4839`, states Default/Active/Locked/Cooldown/Disabled) | exists in the kit, **0 instances anywhere in the prototype** |
| Only HUD slot row in the whole file — `HUD-Top-Left` (`197:1437`) in `fishing-village-scene` | label reads **"BAG"**; 3 × `UI/Potion Slot` 44×44 at 56px pitch, each showing a potion with `×5` |
| Repo search for existing hotbar/quickslot code | none |

The one slot row that exists is a **consumable quick-bag**, not a skill bar.
Rendered and visually confirmed.

### What this blocks

Slot count gates everything downstream: the `equipped_skills` model shape (§2),
the loadout API's valid-slot validation (§4), the hotbar UI (§6), and the number
of input actions (§8). Building any of it would mean inventing the count.

### Decisions required

1. **Does the game have a combat skill hotbar at all?** The design currently
   shows a consumables bag instead.
2. **How many active skill slots?** `UI/Skills/Slot` exists with a `Cooldown`
   state, which implies intent — but it was never placed.
3. **Where does it sit** relative to the BAG row, health/XP bars and the
   `✦ MENU` button?
4. **Input bindings** — `project.godot` defines only `move_*`, `jump`, `attack`.
   No skill actions exist and Figma specifies none.
5. **SP HUD placement** — D27 moved SP off the Skills screen on the
   understanding it lives on the combat HUD, which is not yet designed.

Until these are answered in Figma, the phase cannot proceed without guessing.


---

# RESPONSIVE REGRESSION

Project-wide stretch policy (added in Phase 5.8): **base 1920×1080,
`canvas_items`, `keep`**. The logical canvas is therefore always 1920×1080 and
the window scales it uniformly — composition is resolution-independent by
construction, and the meaningful risks are controls escaping the canvas,
zero-size containers, clipped text and broken centring.

Audited with `SampleProject/UI/verify_responsive.gd`, which **measures real
control rects** rather than comparing screenshots (an earlier pixel comparison
produced a false "off-centre" result that turned out to be a capture artifact).

Checks per screen: canvas size · anchors · non-zero sizes · every visible
descendant inside the viewport · text clipping (labels with no wrap and no
overrun handling) · scroll containers vertical-only with real height · modal
centring · sidebar left-anchored · bottom bar full-width and flush to the bottom
· hotbar horizontally centred.

| Screen | 1920×1080 | 1600×900 | 1280×720 | 2560×1440 | 1920×1200 (16:10) | Verdict |
|---|---|---|---|---|---|---|
| Game Menu shell | ✅ | ✅ | ✅ | ✅ | ✅ | **PASS** |
| Inventory | ✅ | ✅ | ✅ | ✅ | ✅ | **PASS** |
| Equipment | ✅ | ✅ | ✅ | ✅ | ✅ | **PASS** |
| Status | ✅ | ✅ | ✅ | ✅ | ✅ | **FIXED** |
| Skills | ✅ | ✅ | ✅ | ✅ | ✅ | **FIXED** |
| Modals | ✅ | ✅ | ✅ | ✅ | ✅ | **PASS** |
| Combat HUD | ✅ | ✅ | ✅ | ✅ | ✅ | **PASS** |

## FIXED — Status and Skills lost 400px of width

Both screens hide the party column while open. They were hiding
`PartyStatusPanel`, the panel *inside* the column — but its parent `RightPanel`
carries `custom_minimum_size = 400`, so the container kept reserving the space
and both screens rendered into **1200px instead of 1600px**, leaving a dead
strip on the right.

Fix is structural, not positional: the `ui_party_column` group now sits on
`RightPanel` itself, so hiding it lets the `HBoxContainer` reflow. Measured
before `1200×966` → after `1600×966`.

This was a composition defect present at *every* resolution, surfaced by
measuring rects during the responsive pass.

## No resolution-specific positioning was introduced

All fixes use anchors, containers, size flags and group visibility. There are no
per-resolution offsets anywhere in the UI.

## Notes

- **16:10 (1920×1200)** letterboxes under `keep`, as intended; all controls stay
  within the 1920×1080 canvas.
- **2560×1440** is the same 16:9 ratio and scales up cleanly.
- The sidebar VBox hugs its content (`296×451`) rather than filling the column;
  the full-height look comes from `SidebarBackdrop` behind it. Matches Figma.

## NEEDS DESIGN DECISION

None arising from this pass.

---

# WORLD MAP — approved decisions

Recorded after the World Map phase was approved. Full mapping:
`design/world_map_mapping.md`.

| ID | Decision |
|---|---|
| **D39** | **KEEP** the explored percentage, even though Figma shows no such element. It is real, working `MetSys.get_explored_ratio()` data; restyled with theme tokens, not removed. |
| **D40** | **DO NOT** implement the map legend until real marker data exists. A legend describing symbols that are not on screen would be actively misleading. |
| **D41** | **DO NOT** invent named location markers or their coordinates. Figma's 13 fixed-position markers have no backing dataset. |
| **D42** | **KEEP** the real MetSys exploration map. Do not replace it with a static parchment illustration. The runtime map is authoritative for gameplay state; Figma is authoritative for the surrounding UI/chrome, **not** for invented map data. |

D40 and D41 stay open until a location dataset (id, display name, category,
map coordinates) exists. D39 and D42 are settled and need no revisit.

---

# PAUSE — architecture verification

**Conclusion: the tabbed Game Menu *is* the pause UI. No separate Pause screen
exists in Figma, and none was created.**

Pause flow, unchanged: `UIManager.open_game_menu()` → `GameMenuState` →
`get_tree().paused = true`; the menu runs at
`PROCESS_MODE_WHEN_PAUSED` so it keeps processing while the tree is frozen.

Regression suite: `SampleProject/UI/verify_pause.gd` — **30 assertions, all
passing**. It pins the contract so a second pause system cannot be added by
accident.

## Defects found and fixed

Each was a latent bug in existing code, surfaced by writing the verification —
not a consequence of the Figma work.

| # | File | Defect | Fix |
|---|---|---|---|
| 1 | `game_menu.gd` | Pause close compared `event.keycode == KEY_ESCAPE` directly, so remapping `ui_cancel` did nothing and a gamepad could never close the menu. | Use `event.is_action_pressed(&"ui_cancel")`. Same class of bug as the World Map's raw `KEY_*` panning. |
| 2 | `game_menu.gd` | The Misc → Settings route called `change_scene_to_file(OptionsMenuScene)`, which **unloaded the running game** to show a settings panel that already lives inside the menu (`MiscPanel/OptionsComponent`). | `switch_to_tab("Misc")`. Gameplay and pause state survive. |
| 3 | `game_menu.gd` | `@onready` paths for `focus_router` and `misc_button` omitted the real `BaseMenu/HBoxContainer/CentralPanel/` prefix, so both were always `null`. The focus router had therefore never run, and the Misc button's `pressed` signal was never connected. (`vertical_menu` was unaffected — it has a runtime fallback at lines 64–75.) | Resolve by `find_child(...)`. |
| 4 | `focus_router.gd` | `tabs_container_path` / `panels_container_path` are authored relative to the **menu root**, but were resolved with `get_node_or_null()` on the router itself — a sibling. Every lookup returned null, so `focus_tabs()`, `focus_content()` and both caching passes were silent no-ops. | Added `_menu_node()`, which resolves from `get_parent()`. |
| 5 | `focus_router.gd` | `focus_tabs()` forced `FOCUS_ALL` on **every** child and grabbed focus on `get_child(0)` — which is `TopSpacer`, a 24px invisible `Control`. Focus also failed outright while the menu was still hidden, since `grab_focus()` is a no-op on a node that is not visible in tree. | Target the first `Button` only; leave spacers unfocusable; await `visibility_changed` before grabbing. |
| 6 | `UIManager.gd` | `is_ui_active()` / `is_gameplay_input_allowed()` treated any non-empty `current_state_name` as "UI open". After the first close the state is `"NullState"`, so gameplay input read as permanently blocked. Latent only — neither method has a caller yet. | Treat `""` and `"NullState"` alike. |

Net effect: keyboard and gamepad users can now navigate the pause menu at all
(#3, #4, #5 compounded into complete focus failure), `ui_cancel` is rebindable
(#1), and opening Settings from pause no longer destroys the session (#2).

## Dead code

`Scripts/UI/PauseMenu.gd` is dead: no `.tscn` instantiates it, no script
references `class_name PauseMenu`, and it has no runtime owner — the only
mention anywhere is Godot's generated
`.godot/global_script_class_cache.cfg`. Removed in a separate commit;
`verify_pause.gd` §8 guards against a second pause system reappearing.

---

# SETTINGS — audit only, implementation not started

Full mapping: `design/settings_mapping.md`.

The audit is complete for all four Figma settings frames and the existing Godot
settings system. Implementation was **not** started, because the audit turned up
a scope question that is the user's to answer, not mine to assume:

**8 of the 19 settings rows Figma specifies have no backing system at all**, and
6 of the 12 Controls rows name input actions that do not exist.

| Tab | Backed | Unsupported |
|---|---|---|
| Audio | Master, Music, Sound Effects | Ambient (no such bus) |
| Display | VSync, Restore Defaults; Display Mode partially (Windowed ↔ Fullscreen only) | Resolution, Frame Rate Limit, Screen Brightness + its preview |
| Gameplay | Language (`LocalizationManager`, and it has **two** locales where Figma shows one); Auto-Save has a live flag but no persistence key | Text Speed, Screen Shake, Damage Numbers |
| Controls | move ×4, jump, attack, Pause (`ui_cancel`) | Dash, Special Ability, Interact/Examine, Open Map, Inventory — and Figma omits the four real `skill_slot_*` binds |

Persistence stores exactly five keys (`master_volume`, `music_volume`,
`sfx_volume`, `fullscreen`, `vsync`); audio buses are Master/Music/SFX only.

## NEEDS DESIGN DECISION (Settings)

| ID | Question |
|---|---|
| **D43** | Resolution, Frame Rate Limit, Screen Brightness: build the backing systems, or cut the rows from Figma? |
| **D44** | Ambient volume: add an Ambient bus and route ambient audio to it, or cut the row? |
| **D45** | Text Speed, Screen Shake, Damage Numbers: real features to build, or cut? |
| **D46** | Display Mode: keep the two real states, or add borderless (needs the persisted `fullscreen` bool to become a mode enum)? |
| **D47** | Six Controls rows name non-existent actions. Cut them, or are Dash / Special Ability / Interact real planned mechanics? Figma also needs the four real `skill_slot_*` binds added. |
| **D48** | The Controls tab only works because it instances the third-party maaacks `InputOptionsMenu`, which `ui_theme_scope_audit.md` deliberately isolates from `GameUITheme`. Wrap it in the themed shell and accept unstyled rows (recommended), or own the rebinding UI? |

Answering D43–D48 makes Settings a straightforward build: the shell and row
archetypes are only three repeated patterns (stepper, segmented toggle, stepper
slider), all expressible with existing theme tokens.

---

# COMBAT HUD — live-data and theme fixes (post code review)

Three verified defects from the code review, all fixed. Suite:
`SampleProject/UI/verify_combat_hud.gd` — **46 assertions, all passing**.
Capture: `design/shots/combat_hud_1920.png`.

## 1. HP data source

`player_vitals_panel` read `player.get_node_or_null("HealthComponent")` then
`"current_health" in health`. **`Player.tscn` has no `HealthComponent`** — only
`default_enemy.tscn` does — so both guards failed and `_current_hp()` returned
`gm.calculate_max_health()`. **The HP bar was always full.**

The authoritative source is the player node itself: `Player.gd extends
CombatBody2D`, which owns `current_health` / `Max_Health` and clamps all damage
against them. The panel now binds directly to that node, holds no copy of the
value, and shows `— / —` with an empty bar when the node cannot be resolved
rather than faking a full bar.

`gm.calculate_max_health()` is deliberately **not** used for the bar maximum:
gameplay clamps against `Max_Health`, so using anything else would let the HUD
and gameplay disagree.

## 2. Live refresh

The panel connected only `EventBus.sp_changed` and was otherwise populated once
in `_ready()` — while `Game.tscn` had hidden the legacy `PlayerHealthBar` and
`PlayerXPBar` in the same phase. Net effect: **no HP or XP feedback anywhere
during gameplay.**

Now event-driven from each real owner, with no per-frame polling:

| Row | Signal | Owner |
|---|---|---|
| HP | `health_changed(hp, max, animate)` | player node (`CombatBody2D`) |
| SP | `EventBus.sp_changed` | `SkillManager` |
| XP | `xp_gained` | `XPManager` |
| Level badge / XP threshold | `level_up` | `XPManager` |
| Rebind after respawn | `EventBus.player_respawned` | — |

`EventBus.player_health_changed` was **not** used: `CombatBody2D` emits it
inside `if Engine.has_singleton("EventBus")`, which is always false for Godot 4
autoloads (the known project-wide issue), and `heal_damage()` never emits it at
all. The node signal `health_changed` is emitted unconditionally on every
mutation, so it is the reliable path.

**One gameplay fix was required:** `Player._on_level_up()` raised `Max_Health`
and `current_health` without emitting `health_changed`, breaking the
`CombatBody2D` contract that every other mutation honours. Added the emit —
otherwise a level-up maximum increase would never reach the HUD.

## 3. Theme inheritance

`SkillHotbar`, `PlayerVitalsPanel` and `CombatHudTop` were instanced directly
under `Game.tscn → UICanvas`, which carries no theme, so every
`theme_type_variation` (`VitalsName`, `BindBadge`, `CooldownLabel`,
`VitalsValue`, …) silently fell back to default Godot styling.

Fixed with a **scoped wrapper**, not a global theme: a new
`UICanvas/CombatHUD` `Control` (full-rect, `mouse_filter = ignore`) carries
`GameUITheme`, and the three HUD scenes are reparented into it. The legacy
`UICanvas` widgets (`CoinCounter`, `TutorialHintDisplay`,
`CombatContextDisplay`, hidden bars) stay outside and keep their own look, so
no unreviewed screen changed appearance. `project.godot` still sets no
`gui/theme/custom`.

### Testing note — `has_theme_*()` is not a valid probe

`ThemeDB.get_default_theme().has_font_size("font_size", "VitalsName")` returns
**true** for a type the theme has never heard of, because the default theme
answers from its fallback. An isolation assertion built on `has_theme_*()`
passes everywhere and proves nothing. The suite compares **resolved values**
against `UITokens` instead: the HUD resolves `SIZE_ROW_TITLE` (18) and `ACCENT`,
while the third-party MetSys `Minimap` resolves 16 and a different colour.

## Visual check

`design/shots/combat_hud_1920.png` at 1920×1080: vitals panel top-left with the
accent name, `LV.1` badge, HP **78/100** (green, damaged — the fix, visibly not
full), SP 38/50 (blue), XP muted; quest panel top-centre; currency and menu
top-right; 4-slot hotbar bottom-centre with bind badges 1–4. Fonts resolve to
Cormorant Garamond from the theme.

**No new visual differences from the approved Figma HUD.** Empty skill slots are
expected — `skills.json` ships no production skills by design.

---

# SETTINGS — implemented (Phase 5.13)

Mapping: `design/settings_mapping.md`. Suite: `SampleProject/UI/verify_settings.gd`
— **62 assertions, all passing**. Captures: `design/shots/settings_{display,audio,game,controls}_1920.png`.

**Product decision applied:** only settings with a real backing system are shown.
Deferred Figma rows are omitted entirely rather than rendered as dead controls,
so the screen has fewer rows than Figma by design.

## Implemented

| Tab | Rows | Backing |
|---|---|---|
| Display | Display Mode (Windowed / Fullscreen), VSync (Enable / Disable) | `SettingsModule` keys `fullscreen`, `vsync` → `DisplayServer` |
| Audio | Master Volume, Music, Sound Effects | `master_volume` / `music_volume` / `sfx_volume` → `AudioServer` buses Master/Music/SFX |
| Game | Language | `LocalizationManager.available_languages` — **English and Ukrainian**, read from the manager, never hardcoded |
| Controls | full rebinding list | third-party maaacks `InputOptionsMenu`, unchanged |

Plus Restore Default Settings (existing reset) and Exit to Main Menu (existing
dual-mode behaviour).

## Deferred — rendered nowhere (D43–D47)

Resolution, Frame Rate Limit, Screen Brightness + its preview box, Ambient
volume, Text Speed, Screen Shake, Damage Numbers, and the "Borderless Window"
display mode. The suite asserts none of these strings appears on any tab.

## Architecture

- **One settings system.** The screen reads and writes
  `SaveSystem.settings_module.settings` directly; the suite asserts it is the
  same object the save system owns. No parallel manager, no duplicate
  persistence.
- **No scene change.** Settings is the `Misc` tab of the Game Menu. Verified:
  `current_scene` is unchanged, the tree stays paused, and the menu instance is
  the same one — the Pause-phase fix that removed `change_scene_to_file` holds.
- **Immediate application.** Volume changes hit `AudioServer` on the same frame
  (asserted via `db_to_linear(get_bus_volume_db(...))`); display changes go
  through the existing `_apply_display_settings()`.
- **Persistence.** Every change calls `save_game_settings()`. The round trip is
  asserted: change → save → clobber in memory → `load_game_settings()` → value
  restored, and the UI re-reads it. Empty and partial legacy payloads both load
  safely.

## Controls tab — scoped, not rewritten

The maaacks `InputOptionsMenu` remains the behavioural source of truth; our
script contains no `action_add_event` / `action_erase_events` (asserted). It is
nested inside the Settings screen, so it **inherits `GameUITheme` by scope** —
which is the visual integration that was asked for. The theme is still not
project-global, so addon UI elsewhere (e.g. the MetSys `Minimap` in `Game.tscn`)
is untouched; `verify_combat_hud` asserts that separately.

## New shared theme entries

Seven Label variations (`SettingsSystem`, `SettingsTitle`, `SettingsEyebrow`,
`SettingsHeading`, `SettingsRowLabel`, `SettingsValue`, `SettingsHint`) and
three Button variations (`SettingsSegment` / `SettingsSegmentOn`,
`SettingsStepper`, `SettingsSidebarTab`). Theme is now **96 types**. The scene
carries no one-off colour overrides and no embedded fonts (asserted).

**Fixed while here:** the shared `HSlider` track stylebox had zero vertical
content margins, so the track collapsed and rendered invisible on every slider
in the project. Now 4px top/bottom, matching Figma's 8px track.

## Deviations

| # | Figma | Implemented | Why |
|---|---|---|---|
| D49 | Standalone page with its own top section ("OPTIONS" + ornament) and its own bottom bar | Content + settings icon rail only; the Game Menu's existing top bar and shared bottom bar are reused | Settings lives inside the tabbed menu. Rendering a second set of chrome would double the top and bottom bars. |
| D50 | Slider thumb is a rotated diamond | Default round grabber on the themed track | Needs a thumb texture asset; cosmetic only. |
| D51 | No party panel on the settings frames | Party panel stays visible (shared menu chrome) | Hiding it means a third screen competing for `ui_party_panel`, which the code review already flagged as an ordering bug between Status and Skills. Not worth the risk for a cosmetic gain. |

## Note — settings controls were never wired before

The previous `options_component.tscn` had sliders and checkboxes but **only two
signal connections in the whole scene** (back / exit-to-main-menu). Nothing
connected `value_changed` or `toggled`, so no control in the old Settings screen
did anything. This phase wires them for the first time; there was no working
behaviour to preserve there, only the dual-mode and close paths, which are
carried over verbatim.

## Tech debt — documented, not fixed

`Player._initialize_health_bar()` calls `call_deferred("_initialize_health_bar")`
when `get_tree().current_scene` is null, with no retry bound — it recurses until
the stack dies. Harmless in the real game (`current_scene` is always set) and
worked around in test harnesses by assigning `current_scene`. Out of scope for
UI work; recorded here so it is not rediscovered.
