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

## Not yet implemented

World Map · Journal · HUD · Pause · Settings.

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

## ⛔ Blocked — Equipped Skills + Combat Hotbar

**Phase halted at step 3 by design, not by an implementation problem.**

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
