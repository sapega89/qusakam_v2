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
| **NONE** — NO FIGMA DESIGN | Nothing in the file covers it. |
| **OUTDATED** — FIGMA OUTDATED / CONFLICTS WITH APPROVED PRODUCT DECISION | The frame's core layout or content model was rejected by a recorded decision. |

`(prov.)` = provisional, depends on an open question for Sapega (§4).
Dead or superseded runtime surfaces are labelled by what Figma offers for their
**function**, with the live successor named.

---

## 1. Classification

### A. Game Menu + HUD

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Game Menu shell | MATCH | `316:7708` UI/Game Menu Sidebar, `390:6411` UI/Top Bar | Figma sidebar has 9 items, runtime 7 — Healing/Jobs are D6 (open). Blur not reproduced (D1, tech). |
| Inventory | MATCH | `46:193` | Overrides D7 (`EQUIPMENT` tab), #4a (`KEY ITEMS` disabled), D8 (details kept). `FILTER` undefined (D9, open). |
| Equipment | PARTIAL | `58:4` frame has **no content**; design comes from `258:5110` + `258:5111` | Figma shows 8 slots vs 11 real — D20 approved, **Figma needs updating**. |
| Status | MATCH | `58:719` | Character grid / stat-point buttons absent from Figma (D18, open). |
| Skills | MATCH | `58:453` | Overrides D26, D27, D29. |
| World Map | OUTDATED | `94:609`, `68:1900` | Core content rejected: parchment map → MetSys grid (D42); explored % added (D39). Chrome matches. Legend/markers D40/D41 are data gaps. |
| Journal | OUTDATED | `192:1529`, `192:1636`, `192:1754` | Codex model rejected → quest log (D52, D53, D58–D60). |
| Settings | MATCH | `17:280`, `17:409`, `17:632`, `17:756` | Override D49 (no own chrome), D51, Language shows English only (runtime also has Ukrainian). Rows D43–D47 open. |
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
| Shop menu (buy/sell/equipment) | MATCH | `153:1289` buy, `153:1523` sell, `153:1760` buy-confirm | Figma sidebar is Buy / Sell / Equipment — same three modes as `shop_ui.gd`. Selected row renders accent-on-accent (invisible name), the same Figma defect D26 fixed for Skills. |
| Merchant NPC + prompt | MATCH | `164:1302` npc-menu-merchant (Talk / Quest / Buy), `197:1422` gamepad-prompt | Figma routes the shop through an NPC action menu, not a direct "Press E" prompt. |
| Blacksmith | MATCH | `176:1357` npc-menu-blacksmith (Talk / Quest / Craft / Enchant) | Figma's blacksmith is the entry to Crafting/Enchanting. Runtime's blacksmith is only the shop's Equipment mode — **mismatch in role**, see Q4. |

### C. Crafting / Enchanting

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Crafting UI | MATCH | `160:1291` list, `164:2326` detail, `164:2545` confirm, `164:2764` error | Full flow designed. Same accent-on-accent selected row. |
| Crafting station | PARTIAL | `176:1357` blacksmith menu → Craft | No physical station is designed; Figma's answer is "craft at the blacksmith NPC". Resolves the audit's ❓ if Sapega agrees (Q4). |
| `ForgeSystem` | NONE | — | Not a UI surface (8-line stub). |
| Enchanting | PARTIAL | `177:1582` detail, `177:1836` confirm, `177:2108` error | **No enchant list**: `177:1362` "enchant-list" is a copy of the crafting list (header `CRAFT`, same recipes). |

### D. Dialogue

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Dialogue box | MATCH | `36:6` npc-dialog-simple, `127:1087` UI/Character Dialogue | Speaker name + text panel with gold border over gameplay. |
| Dialogue choices | PARTIAL | `258:5108` UI/Dialogue Choices (component) | `36:65` is named "choices" but its layers hold no choice list; the component is not placed in any screen. |
| `DialogueUI.gd` | NONE | — | Dead code. Function covered by `36:6`. |
| Boss / cutscene dialogue | PARTIAL (prov.) | `36:65` conversation-dialog-choices | Cinematic variant: chapter header, two portraits, ornate frame. Whether this is the cutscene surface is unconfirmed (Q5). |

### E. NPC interaction

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Interaction prompt | MATCH | `197:1422` gamepad-prompt above the player in `197:1392` | Audit mapped this to `npc-speech-bubble`; the prompt is actually the button hint. `197:1392` is otherwise an older concept — see §3. |
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
| Item acquired / loot toast | MATCH | `28:5`, `28:25`, `274:5375` / `222:4880` UI/Modal/ItemPickup | Designed as a **small modal with a confirm button**, not a transient toast (Q6). The audit's "needs a design" is wrong. |
| Death / respawn UI | MATCH | `41:83` game-over-screen | "Game Over" + two options over a dungeon backdrop. The audit's "needs a design" is wrong. |
| Demo end screen | NONE | — | — |
| Prologue scene | NONE | — | Dead. |
| Tutorial menu | MATCH | `130:1172` menu-tutorial, `135:1260` tutorial-content | List + content page. |
| Timer display / panel | MATCH | `PLAYTIME` in the top-right of every Game Menu frame | Data gap D2 (no clock). `timer_panel.tscn` is dead. |
| Gold display | MATCH | `GOLD` in the top-right of every Game Menu frame | — |
| Item tooltip | OUTDATED | `222:4743` UI/Tooltip | D29/D8: details live in the shared bottom bar; no second tooltip system. Surface is dead too. |
| `ui_panel.tscn`, `game_title.tscn` | NONE | — | Dead. (`game_title` function is covered by the title block in `258:5140` / `9:26`.) |
| `modal_dialog.tscn` | MATCH | `258:5332` UI/Modal/Confirm | — |
| `yes_no_dialog.tscn` | MATCH | `258:5332` | Dead duplicate of `modal_dialog`. |
| Save point | PARTIAL | `prop/save-pillar` placed in `144:1735`, `197:1392`; prompt `197:1422` | The object and a generic prompt are drawn; no save-point interaction UI. Save itself is `17:5`. |

### G. Main menu / Save / Load

| Surface | Label | Figma evidence | Notes |
|---|---|---|---|
| Main menu | PARTIAL | `9:26` | Figma: New Game / Continue / Settings / Quit Game. Runtime also has **Load Game** — Figma has no entry for it. |
| Load game menu | MATCH | `150:1278` | Slot rows: timestamp, location, level, party portraits, playtime; Empty Slot state. |
| Save game state | MATCH | `17:5`, `258:5162` UI/Save Screen Modal | Includes the "Overwrite Save?" confirm. |
| Splash | MATCH | `258:5141` / `258:5140` | Title + `PRESS ANY BUTTON`. `MainMenu.tscn` already has a hidden `PressAnyButtonContainer`. Display face "Khalahas Heroes" missing (data gap). |

---

## 2. Totals

| Label | Count |
|---|---|
| FIGMA MATCH EXISTS | 34 |
| FIGMA PARTIAL | 8 |
| NO FIGMA DESIGN | 11 |
| FIGMA OUTDATED / CONFLICTS | 3 |
| **Rows** | **56** |

The audit counts 52 *distinct* surfaces; this table has 56 rows because it keeps
the audit's row split (three HUD parts, legacy widgets, dead scenes) so every row
gets a label. 5 of the 11 NONE rows are dead code or non-UI; 5 of the 34 MATCH
rows are dead or superseded widgets whose function Figma covers.

**Real design gaps (NONE on a live surface):** level-up notification, enemy
health bar, combat context display, in-game tutorial hints, objective-updated
notification, demo end screen. Plus the PARTIAL gaps: enchant list, full-screen
NPC dialogue panel, dialogue choices in context, Load Game entry on the main menu,
save-point interaction.

**Corrections to `UI_SURFACE_AUDIT.md` §6 "Still need Figma designs":**
death/respawn screen (`41:83`), item-acquired/loot (`28:5`, `28:25`) and the
generic interaction prompt (`197:1422`) **are designed**. The crafting station is
answered by the blacksmith menu (`176:1357`), pending Q4.

---

## 3. Figma content with no runtime surface

| Node | Frame | Status |
|---|---|---|
| `58:230` | menu-healing | No system. D6 / #10 open (Q1). |
| `58:947` | menu-jobs | No system. D6 / #10 open (Q1). |
| `192:1754` | journal-character-detail | Superseded by D60. |
| `434:6593` | HUD Bag Section | Removed from scope by D33 — "Figma: remove Bag Section". |
| `197:1392` | fishing-village-scene | Concept frame. Its HUD (potion hotbar `258:5349`…, "BAG" label) contradicts D33 and predates `434:6556`. Only the prompt `197:1422` is current. |
| `144:1735` | desert-oasis-scene | Concept frame (HUD is only `✦ MENU`, contradicts `434:6556`). Reference for prop placement only. |
| `164:1446`, `164:1621` | crafting-confirm / crafting-error (duplicates) | Earlier crafting variants left in the enchant row. Delete or rename (Q3). |
| `177:1362` | enchant-list | Mislabelled copy of the crafting list (Q3). |

---

## 4. Questions for Sapega

| # | Question | Affects |
|---|---|---|
| Q1 | Healing and Jobs: are `58:230` / `58:947` planned features or obsolete frames? (D6 / #10) | Game Menu shell, sidebar |
| Q2 | Settings rows without backing (D43–D47) and Language: cut from Figma, or build? | Settings |
| Q3 | Enchant has no list screen — `177:1362` is a crafting copy. Design one? Delete duplicates `164:1446` / `164:1621`? | Enchanting |
| Q4 | Figma puts Craft/Enchant under the **blacksmith NPC**, runtime puts the blacksmith inside the **shop** as an Equipment mode. Which is right? Is the blacksmith the crafting station? | Blacksmith, Crafting station |
| Q5 | Is `36:65` (chapter header, two portraits) the cutscene/boss dialogue design? | Cutscene dialogue |
| Q6 | Item pickup is designed as a modal with a confirm button. Is that intended for every pickup, or should frequent loot be a non-blocking toast? | Loot toast |
| Q7 | Main menu: add a Load Game entry to Figma, or should runtime drop it in favour of Continue? | Main menu |
| Q8 | Are `144:1735` / `197:1392` concept art only, so their HUDs can be ignored? | Scene frames |

Existing open decisions that still apply: D9 (FILTER), D18 (Status grid), D38
(auto-targeting), D56 (quest engine).
