# Figma Decision Register

Phase 2 of the Figma coverage audit. Collects every recorded product decision
that bears on whether a Figma frame is still authoritative, so Phase 3 can tell
**"Figma is outdated"** apart from **"the code is wrong"**.

Consolidated from existing docs only. No new decisions are made here.

- **Primary source:** `ui_visual_qa.md` (D1–D64, deviation tables, "Remaining
  Figma deviations", "Still open").
- **Also:** `journal_audit.md` (D52–D57), `ui_implementation_plan.md` §6 (numbered
  #1–#12), `settings_mapping.md`, `UI_IMPLEMENTATION_STATUS.md`.

## How Phase 3 uses this

| Kind | Meaning | Effect on Figma coverage label |
|---|---|---|
| **OVERRIDE** | Approved decision: runtime intentionally differs from Figma | Frame/element → **FIGMA OUTDATED / CONFLICTS** (cite the ID) |
| **GAP** | Figma is right; data, art or a system is missing in the game | Does **not** make Figma outdated. Coverage stays MATCH/PARTIAL. |
| **OPEN** | No decision yet | Provisional label + entry in *Questions for Sapega* |
| **TECH** | Implementation limit (engine, asset), not a product call | Does not affect the label |

---

## 1. Figma elements an approved decision makes obsolete

These are the direct inputs for the **OUTDATED / CONFLICTS** label.

| ID | Screen | Figma node | Figma shows | Approved runtime | Source |
|---|---|---|---|---|---|
| D7 / #4b | Inventory | `46:193` | `WEAPONS` tab | `EQUIPMENT` tab (weapon + armor) | ui_implementation_plan §6 |
| #4a | Inventory | `46:193` | `KEY ITEMS` tab | Visible but disabled until content exists | ui_implementation_plan §6 |
| D8 | Inventory | `46:193` | No item detail surface | Item details kept (bottom bar, see D29) | ui_visual_qa |
| D20 | Equipment | `58:4`, `258:5110` | 8 slot rows | All 11 real slots — **Figma needs updating** | ui_visual_qa |
| D26 | Skills | `58:453` (`58:593`) | Accent text on accent fill | Dark-on-accent | ui_visual_qa |
| D27 | Skills | `58:453` | SP on progression screen | SP removed (HUD only) | ui_visual_qa |
| D29 | Skills | `58:453` | In-column tooltip panel | Shared bottom-bar details | ui_visual_qa |
| D33 | Combat HUD | `434:6593` (Bag Section) | Consumable bag / quickbar | **Removed from scope — Figma: remove Bag Section** | ui_visual_qa |
| D39 | World Map | `94:609` | No explored % | Explored % kept | ui_visual_qa |
| D42 | World Map | `94:609`, `68:1900` | Illustrated parchment map | Real MetSys grid | ui_visual_qa |
| D49 | Settings | `17:280` … `17:756`, `217:1618` | Standalone page with own top/bottom bars | Tab inside Game Menu, shared chrome | ui_visual_qa |
| D51 | Settings | `17:280` … `17:756` | No party panel | Party panel stays visible | ui_visual_qa |
| — | Settings | `17:632` | Language: English only | English + Ukrainian (`LocalizationManager`) | settings_mapping |
| D52 | Journal | `192:1529`, `192:1636` | Character codex | Quest log | journal_audit |
| D53 / D58 | Journal | `192:1529` | Four banner characters (Khalahas, Lyra Ashveil, Valen, Selene) | Not project characters; quest entry list | journal_audit |
| D59 | Journal | `192:1529` | `◇ All Chapters ◇` stepper | Omitted — no chapter model | ui_visual_qa |
| D60 | Journal | `192:1754` | Character-detail page | Quest detail pane — **whole frame superseded** | ui_visual_qa |
| D61 | Journal | `192:*` | Page over illustrated map art | Solid `#111118` background | ui_visual_qa |
| D62 | Misc modal | `58:1246` | — | Figma copy adopted (`Return to Title` / `Quit the Game`) — Figma **wins** here | ui_visual_qa |
| D63 | Misc modal | `58:1246` | No dimming scrim | Shared modal blocker kept | ui_visual_qa |
| D64 | Misc modal | `58:1246` | Rows in Inter | Cormorant Garamond (kit wins over outlier frame) | ui_visual_qa |

## 2. Data / art gaps — Figma stays authoritative

These do **not** make Figma outdated; the game is behind the design.

| ID | Screen | Gap |
|---|---|---|
| D2 | Party panel | No playtime clock (`GameTimer` missing) |
| D3, D12, D24 | Party / Status / Equipment | No per-character HP/SP model |
| D4, D16, D23, D55 | Party / Status / Equipment / Journal | No portrait art |
| D5, D17, D21, D28, D36 | Inventory / Status / Equipment / Skills / HUD | Icons not exported from `🎨 Icons & Assets` |
| D11 | Status | No Job Points system |
| D13 | Status | Nothing equipped by default (renders real state) |
| D14, D57 | Status / Journal | Class display names empty in `pathfinder_classes.json` |
| D15, D54 | Status / Journal | No Path Action / Talent system (Figma structure kept) |
| D32 | Skills | `skills.json` intentionally empty |
| D40 | World Map | Legend blocked on a location dataset (**DO NOT** build until it exists) |
| D41 | World Map | 13 named markers blocked on the same dataset |
| — | Splash | "Khalahas Heroes" display face not in project (#1) |

## 3. Implementation limits (TECH) — no effect on labels

| ID | Screen | Note |
|---|---|---|
| D1, #12 | Game Menu | 3px background blur not reproduced (no Control blur in Godot) |
| D10 | Inventory | Frame uses off-scale sizes 11/18/28 + Medium 500 — UI KIT doc and frames disagree |
| D19, D25 | Status / Equipment | Party panel visibility handled per screen |
| D22 | Equipment | No per-slot unequip; Figma has only `UNEQUIP ALL` (matches Figma) |
| D30, D31 | Skills | No tree connectors / unlock modal — none in Figma either (matches Figma) |
| D34, D35 | Combat HUD | Resolved |
| D37 | Combat HUD | Keyboard binds added; controller binds undesigned in Figma |
| D48 | Settings | Controls tab reuses the maaacks `InputOptionsMenu` |
| D50 | Settings | Round slider grabber — diamond thumb needs an asset |

## 4. Designer decisions — 2026-09-26

Answers from Sapega to the questions in `figma_coverage.md` §4. They resolve
D6, #10, D43–D47 and Q1–Q8. **Figma stays authoritative for all of them.** The game is
behind the design, so these are **GAP** entries, not overrides.

| ID | Resolves | Decision | Consequence |
|---|---|---|---|
| **D65** | Q1, D6, #10 | **KEEP Healing and Jobs.** Planned future features, not obsolete frames. | `58:230`, `58:947` are authoritative. The 7-vs-9 sidebar is a runtime gap. |
| **D66** | Q2, D43–D47 | **BUILD all deferred settings:** Resolution, Frame Rate Limit, Screen Brightness, Ambient volume, Text Speed, Screen Shake, Damage Numbers, Borderless mode. Input actions Dash, Special Ability, Interact are planned. **Do not delete these rows from Figma.** | Settings rows are runtime gaps. |
| **D67** | Q2 | **Figma language options must list English and Ukrainian.** | Figma update (`17:632`). |
| **D68** | Q3 | **KEEP Enchanting** as a planned system. It needs a **dedicated Enchanting page design**. The current `enchant-list` (`177:1362`) is not final. Duplicate `crafting-confirm` / `crafting-error` frames may be cleaned up if they are true duplicates. | Designer action. Enchanting stays PARTIAL. |
| **D69** | Q4 | **The Blacksmith is a SEPARATE NPC** with its own menu (Talk / Quest / Craft / Enchant). It is **not** an Equipment mode inside the Shop. | `176:1357` is authoritative. Runtime `shop_ui._on_blacksmith_pressed()` → `_switch_mode("equipment")` contradicts it. The blacksmith is the crafting/enchanting entry point. |
| **D70** | Q5 | **`conversation-dialog-choices` (`36:65`) is for SPECIAL STORY SCENES only.** Do not use the ornate two-portrait layout as the default NPC dialogue. | Default NPC dialogue = `36:6`. |
| **D71** | Q6 | **Item pickup has two UI states:** (1) a nearby/interact prompt letting the player choose to pick the item up, then (2) a pickup confirmation modal after pickup. | State 1 = `461:6479` (D74). State 2 = `28:5` / `28:25` / `274:5375`. |
| **D72** | Q7 | **Main menu uses CONTINUE only.** No separate Load Game button. If save-slot selection is needed, it is reached through Continue. | `9:26` is authoritative. Runtime `load_game` button must go; Continue → `150:1278` when slot choice is needed. |
| **D73** | Q8 | **`desert-oasis-scene` and `fishing-village-scene` are CONCEPT ART / MOOD REFERENCES ONLY.** Their HUD overlays are not authoritative and must not be implemented. | `144:1735`, `197:1392` carry no UI authority — including the button hint `197:1422` (since promoted to `461:6479`, D74). HUD authority is `434:6556`. |
| **D74** | follow-up | **`UI/Interaction/Prompt` (`461:6479`) is the approved generic interaction prompt.** | Covers the interaction prompt, merchant approach and D71 state 1. Save point: prompt covered; what follows is defined by D75. |
| **D75** | follow-up | **Save Slot Selection is ONE shared runtime surface with two entry points:** Main Menu → Continue → **LOAD mode**; Save Point → `UI/Interaction/Prompt` "[A] Save" → **SAVE mode**. Do not create separate Save Menu and Load Menu screens. Use the existing Figma design; do not design a new one. | Figma: `150:1278` (LOAD) + `17:5` (SAVE) share `UI/Save Load List Area` `217:3038`; overwrite confirm `258:5162`. Runtime currently has two scenes (`LoadGameMenu.tscn`, `save_game_state.tscn`) — to be merged when implemented. Save-success confirmation: see D76. |
| **D76** | follow-up | **Save Success confirmation reuses the overwrite-confirm modal family** (`258:5162` / `UI/Modal/Confirm` `258:5332`): same panel, spacing, typography, scrim, button styling, focus/navigation. Title "Game Saved", body "Your progress has been saved successfully.", single primary action OK / Continue. Flow: save succeeds → Game Saved → confirm → close Save UI → gameplay. **Not shown on failure.** Save failure uses a separate error state in the same family. No new visual design. | Coverage: MATCH (by reuse). |

## 5. Open — still undecided

| ID | Screen | Figma node | Question |
|---|---|---|---|
| D9, #4c | Inventory | `46:193` | `FILTER` button has no behaviour defined anywhere |
| D18, #6 | Status | `58:719` | 8-slot character grid + stat-point buttons absent from Figma — keep in party panel? |
| D38 | Combat HUD | `434:6556` | Skill auto-targeting rule |
| D47 (part) | Settings | `17:756` | Figma lacks the four real `skill_slot_*` binds (not covered by D66) |
| D56 | Journal | — | Quest engine has no data and is never instanced — ship or delete |
| — | Save flow | `150:1278`, `17:5` | LOAD mode: are empty slots disabled? Is a load confirmation wanted? (Save-success resolved by D76.) |

## 6. Stale entries

`ui_implementation_plan.md` §6 still lists #2, #3, #7, #8, #9 and #12 as **Open**, but
later phases settled them: Equipment was composed from `258:5110` + `258:5111`
(#2), Skills got a data model (#3), #7 became D42, the HUD was built from
`434:6556` (#8), `PauseMenu.gd` was deleted in `fc56f37b` (#9), and #12 became D1.
That table should be updated. Not changed here — outside this audit's scope.

## 7. No decisions exist yet for

None of the 28 Figma frames that `figma_inventory.md` lists as never mapped has any
recorded decision: Splash, Main Menu, Save/Load, Modals & Popups, Dialogues, NPC
Interaction, Shop sell/confirm, Crafting, Enchant, Tutorial, Healing (beyond D6).
In Phase 3, any Figma-vs-runtime difference on these surfaces is **OPEN** by
default and goes to Sapega. It is never assumed to be an override.
