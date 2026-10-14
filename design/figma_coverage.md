# Figma Coverage — every runtime UI surface

Phase 3 of the Figma coverage audit. Every surface in `UI_SURFACE_AUDIT.md` is
classified against Figma file `zZet0eKcVhXSwQUNZsrOlO`, using
`figma_inventory.md` (what exists in Figma) and `figma_decision_register.md`
(which Figma content approved decisions override).

Evidence: section screenshots of all 8 prototype sections, close-ups of
`177:1362` and `153:1289`, and layer metadata. Captured 2026-09-26.

## Labels

| Label | Rule used |
|---|---|
| **MATCH** — FIGMA MATCH EXISTS | A frame or component covers the surface's layout. Element-level approved overrides are listed in Notes but do not change the label. |
| **PARTIAL** — FIGMA PARTIAL | Design exists but is incomplete for this surface: component only, frame empty, missing states or entries. |
| **MATCH (by reuse)** | No dedicated frame. The designer approved deriving it from an existing, designed pattern (counted as MATCH). |
| **NONE** — NO FIGMA DESIGN | Nothing in the file covers it. |
| **OUTDATED** — FIGMA OUTDATED / CONFLICTS WITH APPROVED PRODUCT DECISION | The frame's core layout or content model was rejected by a recorded decision. |

`(prov.)` = provisional. None remain after the designer answers in §4.
Dead or superseded runtime surfaces are labelled by what Figma offers for their
**function**, with the live successor named.

---

## 1. Classification

### A. Game Menu + HUD

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Game Menu shell | MATCH | `316:7708` UI/Game Menu Sidebar, `390:6411` UI/Top Bar | Figma sidebar has 9 items, runtime 7 — Healing/Jobs are planned (D65), runtime gap. Blur not reproduced (D1, tech). |
| Inventory | MATCH | `46:193` | Overrides D7 (`EQUIPMENT` tab), #4a (`KEY ITEMS` disabled), D8 (details kept). `FILTER` cycles ALL → CONSUMABLES → MATERIALS → EQUIPMENT → KEY ITEMS (D9) — **implemented (slice 5)**; KEY ITEMS stays selectable with its empty state (replaces #4a). |
| Equipment | PARTIAL | `58:4` frame has **no content**; design comes from `258:5110` + `258:5111` | Figma shows 8 slots vs 11 real — D20 approved, **Figma needs updating**. |
| Status | MATCH | `58:719` | Figma has no character grid; the old 8-slot grid was runtime-only (D18: switching planned for later; Status shows the active character only). |
| Skills | MATCH | `58:453` | Overrides D26, D27, D29. |
| World Map | OUTDATED | `94:609`, `68:1900` | Core content rejected: parchment map → MetSys grid (D42); explored % added (D39). Chrome matches. Legend/markers D40/D41 are data gaps. |
| Journal | OUTDATED | `192:1529`, `192:1636`, `192:1754` | Codex model rejected → quest log (D52, D53, D58–D60). |
| Settings | MATCH | `17:280`, `17:409`, `17:632`, `17:756` | Override D49 (no own chrome), D51, Figma Language lists English only — must add Ukrainian (D67). Unbacked rows are planned, to be built (D66). |
| Misc submenu | MATCH | `58:1246` | D62 adopted Figma copy; D63, D64 overrides. |
| Combat HUD — vitals | MATCH | `434:6558` | — |
| Combat HUD — hotbar | MATCH | `437:6405` in `434:6556`, `222:4839` UI/Skills/Slot | Controller binds undesigned (D37). Bag Section `434:6593` obsolete (D33). |
| Combat HUD — top bar | MATCH | `434:6580` Quest Info, `434:6586` Currency & Settings | — |
| Bottom bar | MATCH | `121:1073` UI/Bottom Bar | — |
| Party panel | MATCH | `68:1177` UI/Party Status Panel | SP / portrait gaps (D3, D4). |
| Modal layer | MATCH | `258:5332` UI/Modal/Confirm, instance `274:5336` | The 5 modal frames are now identified — see §F rows for pickup and game-over. |

### B. Shop / Merchant / Blacksmith

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Shop menu (buy/sell/equipment) | MATCH | `153:1289` buy, `153:1523` sell, `153:1760` buy-confirm | Figma sidebar is Buy / Sell / Equipment — same three modes as `shop_ui.gd`. Selected row renders accent-on-accent (invisible name), the same Figma defect D26 fixed for Skills. **Implemented (slice 2):** rebuilt on `BaseMenu` with `ShopService` + `ShopRow`; Buy/Sell tabs, 6-category column, buy confirm, dark-on-accent selected row. Not placed on a map (D81). Equipment tab and Party Equipment Effects pending (Q17, Q15). |
| Merchant NPC + prompt | MATCH | `461:6479` UI/Interaction/Prompt, `164:1302` npc-menu-merchant (Talk / Quest / Buy) | Approach prompt → NPC action menu (D74). **Prompt implemented (slice 1a):** the "Press E" label is replaced by the shared prompt "Shop"; NPC menu comes in slice 2. **NPC menu implemented (slice 2):** `NpcActionMenu` — Buy always, Talk only with a dialogue set, Quest hidden (D56). |
| Blacksmith | MATCH | `176:1357` npc-menu-blacksmith (Talk / Quest / Craft / Enchant) | **D69: separate NPC**, entry to Crafting/Enchanting. Runtime's blacksmith-as-shop-Equipment-mode is wrong and must change. **Implemented (slice 3):** separate `Blacksmith` NPC on shared `NpcBase`, Figma art `npc/blacksmith`; Craft appears once the crafting screen exists (slice 4), Enchant hidden (D82), Quest hidden (D56). Not placed on a map (D81). |

### C. Crafting / Enchanting

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Crafting UI | MATCH | `160:1291` list, `164:2326` detail, `164:2545` confirm, `164:2764` error | Full flow designed. Same accent-on-accent selected row. |
| Crafting station | MATCH | `176:1357` blacksmith menu → Craft | The station is the blacksmith NPC (D69). No physical station object. |
| `ForgeSystem` | NONE | — | Not a UI surface (8-line stub). |
| Enchanting | PARTIAL | `177:1582` detail, `177:1836` confirm, `177:2108` error | **No enchant list**: `177:1362` is a crafting-list copy. D68: a dedicated Enchanting page will be designed. |

### D. Dialogue

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Dialogue box | MATCH | `36:6` npc-dialog-simple, `127:1087` UI/Character Dialogue | Speaker name + text panel with gold border over gameplay. |
| Dialogue choices | PARTIAL | `258:5108` UI/Dialogue Choices (component) | `36:65` is named "choices" but its layers hold no choice list; the component is not placed in any screen. |
| `DialogueUI.gd` | NONE | — | Dead code. Function covered by `36:6`. |
| Boss / cutscene dialogue | MATCH | `36:65` conversation-dialog-choices | **D70: special story scenes only.** Ordinary NPC talk uses `36:6`. |

### E. NPC interaction

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Interaction prompt | MATCH | `461:6479` UI/Interaction/Prompt (UI KIT) | **Approved generic prompt (D74).** Editable `Action Text` + swappable `Input Badge`; states Default / Focused / Disabled. Not yet placed in any prototype frame. **Implemented (slice 1a):** `UI/Components/interaction_prompt.tscn` + `InteractableComponent`, improved variant D84 (hug width, 16 px), `interact` action E / gamepad A. |
| NPC action menu | MATCH | `164:1302`, `176:1357` | `npc-interaction-menu` with `UI/Menu Item` rows. |
| NPC speech bubble | MATCH | `164:1318` | Speaker, line, tail, `B Close` hint. |
| Full-screen NPC dialogue | PARTIAL | `164:1334` | Frame holds only a dim overlay and a `Continue` hint — the dialogue panel is missing. |

### F. Notifications, HUD extras, flow screens

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Level-up notification | NONE | — | — |
| Level-up flash FX | NONE | — | VFX, not UI. |
| Coin counter | MATCH | `434:6586` (successor) | Superseded widget; the live `combat_hud_top` already implements the design. Remove, don't restyle. |
| Legacy health bar | MATCH | `434:6558` (successor) | Same — superseded. |
| Legacy XP bar | MATCH | `434:6558` (successor) | Same — superseded. |
| Enemy health bar | NONE | — | — |
| Combat context display | NONE | — | — |
| Tutorial hints (in-game) | NONE | — | `135:1260` is the menu's tutorial page, not an in-game hint. |
| ObjectiveHUD | MATCH | `434:6580` (successor) | Orphan; superseded by Quest Info Panel. |
| Objective notifications | NONE | — | Quest tracker exists, no "objective updated" toast. |
| Item acquired / loot toast | MATCH | State 1 `461:6479` (example "Pick up" `461:6486`); state 2 `28:5`, `28:25`, `274:5375` / `222:4880` UI/Modal/ItemPickup | **D71 flow fully covered (D74):** nearby prompt, then the confirmation modal. **Implemented (slice 1a):** `Objects/ItemPickup.tscn` (prompt "Pick up" → InventoryManager → modal). Not placed in any map: no production pickup exists yet (Q2). The modal uses the shared modal family (D79) — larger than the compact Figma card and without its caption/name hierarchy. |
| Death / respawn UI | MATCH | `41:83` game-over-screen | "Game Over" + two options over a dungeon backdrop. The audit's "needs a design" is wrong. **Implemented (slice 5):** `GameOverScreen` shown by `Player.die()`; Resume loads the last slot (Q6), falls back to the old respawn when no save exists; Return to title. |
| Demo end screen | NONE | — | — |
| Prologue scene | NONE | — | Dead. |
| Tutorial menu | MATCH | `130:1172` menu-tutorial, `135:1260` tutorial-content | List + content page. |
| Timer display / panel | MATCH | `PLAYTIME` in the top-right of every Game Menu frame | Data gap D2 (no clock). `timer_panel.tscn` is dead. |
| Gold display | MATCH | `GOLD` in the top-right of every Game Menu frame | — |
| Item tooltip | OUTDATED | `222:4743` UI/Tooltip | D29/D8: details live in the shared bottom bar; no second tooltip system. Surface is dead too. |
| `ui_panel.tscn`, `game_title.tscn` | NONE | — | Dead. (`game_title` function is covered by the title block in `258:5140` / `9:26`.) |
| `modal_dialog.tscn` | MATCH | `258:5332` UI/Modal/Confirm | — |
| `yes_no_dialog.tscn` | MATCH | `258:5332` | Dead duplicate of `modal_dialog`. |
| Save point | MATCH | `461:6479` (example "Save" `461:6490`) → Save Slot Selection in SAVE mode | Prompt `[A] Save` opens the shared slot screen (D75). See §G flow. **Implemented (slice 1b):** auto-save on touch removed (Q5); prompt "Save" opens SAVE mode. |

### G. Main menu / Save / Load

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Main menu | MATCH | `9:26` | Figma: New Game / Continue / Settings / Quit Game. **D72: Continue only** — the runtime `load_game` button must go. Continue opens Save Slot Selection in LOAD mode (D75). **Implemented (slice 1c):** Figma layout + forest art from `9:26`, `UI/Menu Item` active/inactive styles, Load Game removed, Continue disabled without saves. |
| Load game menu | MATCH | `150:1278` (LOAD mode of Save Slot Selection) | Not a separate screen — merged into Save Slot Selection (D75). **Implemented (slice 1b):** shared `LoadGameMenu` + `SaveSlotCard` restyled to Figma; LOAD empty slots disabled/unfocusable, occupied loads directly; SAVE overwrite → Game Saved / Save Failed. |
| Save game state | MATCH | `17:5` (SAVE mode of Save Slot Selection), `258:5162` overwrite confirm | Not a separate screen — merged into Save Slot Selection (D75). **Implemented (slice 1b):** shared `LoadGameMenu` + `SaveSlotCard` restyled to Figma; LOAD empty slots disabled/unfocusable, occupied loads directly; SAVE overwrite → Game Saved / Save Failed. |
| Splash | MATCH | `258:5141` / `258:5140` | Title + `PRESS ANY BUTTON`. `MainMenu.tscn` already has a hidden `PressAnyButtonContainer`. Display face "Khalahas Heroes" missing (data gap). **Implemented (slice 1c):** existing title state restyled to `258:5140`. |
| Save confirmation (save succeeded) | MATCH (by reuse) | Derived from the overwrite-confirm modal `258:5162` / `UI/Modal/Confirm` `258:5332` (D76) | No dedicated frame. Same modal family: "Game Saved" / "Your progress has been saved successfully." / single OK action. Spec in §G flow. **Implemented (slice 1b):** `ModalTemplates.game_saved()`. |

#### Save / Load flow — one shared surface (D75)

**Save Slot Selection** is ONE runtime surface with two entry points. There are
no separate Save and Load menus.

| Flow step | Coverage | Figma evidence |
|---|---|---|
| Save Point Interaction Prompt | MATCH | `461:6479` — `[A] Save` example `461:6490` |
| Save Slot Selection | MATCH | `150:1278` load-game-screen (LOAD) · `17:5` save-game-screen (SAVE) |
| Main Menu → Continue → Save Slot Selection, **LOAD mode** | MATCH | `9:26` → `150:1278` |
| Save Point → Save Slot Selection, **SAVE mode** | MATCH | `461:6479` → `17:5` |
| Load an occupied slot (LOAD mode) — loads directly, **no confirmation** (D78) | MATCH | `150:1278` |
| Empty slot in LOAD mode — visible, **disabled, unselectable, no focus** (D77) | MATCH | `150:1278` slot 4 empty card |
| Overwrite confirmation (**SAVE mode only**, occupied slot) | MATCH | `258:5162` UI/Save Screen Modal → `UI/Modal/Confirm` |
| Save confirmation (save succeeded) | MATCH (by reuse) | Derived from `258:5162` / `258:5332` (D76) |
| Save failure error | MATCH (by reuse) | Same modal family (D76); error precedent `UI/Craft Error Modal` `217:2983` |

This flow table restates rows already counted above; it adds nothing to the totals.

**What the existing Figma frames show**

| Aspect | Finding |
|---|---|
| Frames | `load-game-screen` `150:1278` and `save-game-screen` `17:5`. Same composition: `UI/Save Load Top Section` `217:1597` + `UI/Save Load List Area` `217:3038` + `UI/Bottom Bar`. |
| Mode variants | **No variant property.** Mode is set by the Top Section's `title` text property ("Load Game" / "Save Game"). Both frames share the same list component, so the design already treats them as one surface. |
| Slot structure | 4 cards (1790×176) in a scrollable list with a scrollbar. Each card: cursor column, large slot-number watermark, left block (timestamp, region, location), right block (lead character level + name, 1–3 party avatars, playtime with clock icon). |
| Occupied slot | Slots 1–3, e.g. "9/23/2026 00:05 · Sunken Ruins · Crystal Sanctum · Lv. 26 Kael · 011:05". |
| Empty slot | Slot 4: "Empty Slot / No save data available". |
| Selected slot | Slot 1: gold `#D4AF37` card border, gold avatar borders and the cursor pointer; other slots use white borders. Hand-built, not a component state. No hover or disabled state. |
| Overwrite confirmation | Present, SAVE mode only: `258:5162` dims the screen and shows `UI/Modal/Confirm` "Overwrite Save? — This will replace the existing save data" with Yes / No. |
| Back / cancel | Bottom bar `B Return` in both modes. `258:5162` shows keyboard hints `W/S Navigate · Enter Save · ESC Back`. In the modal, **No** cancels. |
| Timestamp / playtime / location | All present: `save-date`, `region-name` + `location-name`, `time-value`. |
| Save-success confirmation | No dedicated frame. **Approved derived from the overwrite-confirm modal (D76)** — spec below. |

**Figma gaps in this flow** (they do not block the MATCH):
1. LOAD-mode instruction text reads "Select a slot to **save** your game." — copied from SAVE mode.
2. ~~No LOAD-mode rule for empty slots~~ — **resolved (D77):** disabled and unselectable, may stay visible. Figma has no separate disabled look; the empty card is used as-is.
3. ~~No load confirmation~~ — **resolved (D78):** intentional; selecting an occupied slot loads directly.
4. Save-success has no dedicated frame; it is derived by reuse (D76).

**Implementation deviations (slice 1b):** the LOAD instruction reads "to load" (Figma copy error fixed);
letter-spacing on the caption/title is not reproduced; party portraits and region name are omitted
(no data, Q3); the overwrite/success modals use the shared modal family (larger than the compact
Figma panel, same as Q14). Shots: `design/shots/save_load_*_1920.png`.

**Save Success confirmation — derived spec (D76)**

Reuse the overwrite-confirm modal family. Do not create a new visual style.

| Element | Source | Value |
|---|---|---|
| Scrim | `258:5162` `modal-scrim-layer` | Same full-screen dim |
| Panel | `UI/Modal/Confirm` `258:5332` | Same shape, size, spacing, divider, typography |
| Title | Panel title text | **Game Saved** |
| Body | Panel body text | **Your progress has been saved successfully.** |
| Action | `UI/HexButton` `type=yes` `222:4841` | Single primary action **OK** (or "Continue"). No secondary action. |
| Focus / navigation | As the overwrite confirm | The one button starts focused; confirm closes. |

Flow: Save Point → Save Slot Selection (SAVE) → save succeeds → **Game Saved** →
confirm → close the Save UI → return to gameplay. **Never shown when saving fails.**

Save failure uses a separate error state in the same modal family (precedent:
`UI/Craft Error Modal` `217:2983` — title, divider, description, single close action).

Implementation notes (not implemented):
- `UI/HexButton` has no label text property (its only property is `type`). "OK" needs a
  text override in Figma, or a label property added to the component.
- Runtime already has this modal family: `ModalLayer.show_modal({title, description,
  confirm_text: "OK", allow_cancel: false})` via `modal_dialog.gd`. **No new modal scene is
  needed in Godot (D79).**
- `SaveSystem.save_player_data()` returns `false` on a write failure but emits no signal;
  the success/failure branch must use that return value.

---

## 2. Totals

| Label | Count |
|---|---|
| FIGMA MATCH EXISTS | 39 (1 by reuse) |
| FIGMA PARTIAL | 4 |
| NO FIGMA DESIGN | 11 |
| FIGMA OUTDATED / CONFLICTS | 3 |
| **Rows** | **57** |

The audit counts 52 *distinct* surfaces; this table has 57 rows because it keeps
the audit's row split (three HUD parts, legacy widgets, dead scenes) and adds the
save-success confirmation. 5 of the 11 NONE rows are dead code or non-UI; 5 of the 39 MATCH
rows are dead or superseded widgets whose function Figma covers.

**Real design gaps (NONE on a live surface):** level-up notification, enemy
health bar, combat context display, in-game tutorial hints, objective-updated
notification, demo end screen. Plus the PARTIAL gaps:
enchant list, full-screen NPC dialogue panel, dialogue choices in context.

**Corrections to `UI_SURFACE_AUDIT.md` §6 "Still need Figma designs":**
death/respawn screen (`41:83`) and the item-pickup confirmation modal (`28:5`,
`28:25`) **are designed**. The crafting station is
answered by the blacksmith NPC menu (`176:1357`, D69).

---

## 3. Figma content with no runtime surface

| Node | Frame | Status |
|---|---|---|
| `58:230` | menu-healing | Planned feature (D65). Authoritative; no runtime system yet. |
| `58:947` | menu-jobs | Planned feature (D65). Authoritative; no runtime system yet. |
| `192:1754` | journal-character-detail | Superseded by D60. |
| `434:6593` | HUD Bag Section | Removed from scope by D33 — "Figma: remove Bag Section". |
| `197:1392` | fishing-village-scene | **Concept art / mood reference only (D73).** HUD overlay not authoritative — do not implement. |
| `144:1735` | desert-oasis-scene | **Concept art / mood reference only (D73).** HUD overlay not authoritative — do not implement. |
| `164:1446`, `164:1621` | crafting-confirm / crafting-error (duplicates) | Earlier crafting variants left in the enchant row. May be deleted if true duplicates (D68). |
| `177:1362` | enchant-list | Crafting-list copy, not final. To be replaced by a dedicated Enchanting page (D68). |

---

## 4. Designer answers (2026-09-26)

Recorded as D65–D79 in `figma_decision_register.md` §4.

| # | Answer | Decision |
|---|---|---|
| Q1 | Healing and Jobs are planned features — keep the frames | D65 |
| Q2 | Build every deferred setting and the Dash / Special Ability / Interact actions; Figma Language must list English + Ukrainian | D66, D67 |
| Q3 | Enchanting is planned; a dedicated Enchanting page will be designed; true duplicate crafting frames may be deleted | D68 |
| Q4 | Blacksmith is a separate NPC (Talk / Quest / Craft / Enchant), not a Shop mode | D69 |
| Q5 | `36:65` is for special story scenes only, not default NPC dialogue | D70 |
| Q6 | Pickup = nearby interact prompt, then a confirmation modal | D71 |
| Q7 | Main menu uses Continue only; slot selection via Continue | D72 |
| Q8 | Both scene frames are concept art / mood references only; their HUD overlays must not be implemented | D73 |

Closed or deferred later: D9 (FILTER cycle), D38 (auto-targeting, deferred), D47 part
(skill-slot binds, deferred). D18 (Status grid) and D56 (quest engine) deferred. **No open questions remain.**

---

## Runtime UI Completion — status after slice 8 (2026-09-27)

Plan: `runtime_ui_completion_plan.md`. Coverage labels above are unchanged by implementation; this table tracks runtime status. Tests: 23 `verify_*.gd` scripts, all passing.

| Surface | Before | Now | Slice |
|---|---|---|---|
| Interaction prompt | ❌ one hard-coded label | ✅ shared `UI/Interaction/Prompt` + `interact` action | 1a |
| Item pickup | ❌ | ✅ `ItemPickup` (prompt → inventory → modal); not placed on maps (Q2) | 1a |
| Save / Load (two scenes) | 🟡 old style, broken per-slot saves | ✅ shared slot selection, per-slot player data, overwrite / success / failure modals | 1b |
| Save point | auto-save on touch | ✅ prompt "Save" → SAVE mode | 1b |
| Main menu + Splash | 🟡 | ✅ Figma 9:26 / 258:5140, Continue only | 1c |
| Shop | 💀 unreachable, lists were stubs | ✅ rebuilt, buy/sell work; not placed on maps (D81) | 2 |
| Merchant NPC | 💀 | ✅ Figma art, prompt + NPC menu | 2 |
| Blacksmith NPC | 💀 shop mode | ✅ separate NPC (D69); Craft waits for slice 4 | 3 |
| Crafting | ❌ | ⛔ blocked on gold costs (Q11) and station scope (Q22) | 4 |
| Game Over | ❌ instant respawn | ✅ Figma 41:83; Resume / Return to title | 5 |
| Inventory FILTER | inert | ✅ cycles five categories (D9) | 5 |
| Dialogue box / choices / story scenes | 🟡 addon style | audited — waiting for D83 decision (Q24–Q27) | 6–7 |
| Enchanting | ❌ | out of scope (D82) | — |
