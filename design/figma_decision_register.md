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
| **D75** | follow-up | **Save Slot Selection is ONE shared runtime surface with two entry points:** Main Menu → Continue → **LOAD mode**; Save Point → `UI/Interaction/Prompt` "[A] Save" → **SAVE mode**. Do not create separate Save Menu and Load Menu screens. Use the existing Figma design; do not design a new one. | Figma: `150:1278` (LOAD) + `17:5` (SAVE) share `UI/Save Load List Area` `217:3038`; overwrite confirm `258:5162`. Runtime has two scenes (`LoadGameMenu.tscn`, `save_game_state.tscn`) — **kept as two scenes with shared logic (D80)**. Save-success confirmation: see D76. |
| **D76** | follow-up | **Save Success confirmation reuses the overwrite-confirm modal family** (`258:5162` / `UI/Modal/Confirm` `258:5332`): same panel, spacing, typography, scrim, button styling, focus/navigation. Title "Game Saved", body "Your progress has been saved successfully.", single primary action OK / Continue. Flow: save succeeds → Game Saved → confirm → close Save UI → gameplay. **Not shown on failure.** Save failure uses a separate error state in the same family. No new visual design. | Coverage: MATCH (by reuse). |
| **D77** | follow-up | **LOAD mode: empty slots are disabled and unselectable.** They may stay visible but must not receive focus or trigger any action. | Figma has no disabled slot state (the empty card `Empty Slot / No save data available` is the visual). |
| **D78** | follow-up | **No load confirmation.** Main Menu → Continue → Save Slot Selection → selecting an occupied slot loads it directly; the slot screen is the confirmation. The overwrite confirmation (`258:5162`) stays, **SAVE mode only**. | Save flow closed. |
| **D79** | follow-up | **Modal family for the save flow is settled:** Save Success is covered by reuse of `UI/Modal/Confirm` (D76); save failure uses the same family with an error state; **no new modal scene is needed in Godot** (`ModalLayer.show_modal()` + `modal_dialog.gd`). | Documentation-level decision; nothing implemented. |
| **D9 — CLOSED** | follow-up | **Inventory `FILTER` cycles forward on each press:** ALL → CONSUMABLES → MATERIALS → EQUIPMENT → KEY ITEMS → ALL. No popup, dropdown or separate filter menu. The active category is visually indicated. KEY ITEMS stays in the cycle when empty and shows the existing empty state. | Supersedes #4c. Not implemented. |
| **D38 — DEFERRED** | follow-up | **Skill auto-targeting: skip.** Do not implement auto-targeting; do not invent nearest-enemy or any other targeting system. | Removed from open questions. |
| **D47 (part) — DEFERRED** | follow-up | **Skill Slot 1–4 bindings: do not add them to the Figma Controls screen now; no new bindings.** Runtime keyboard 1–4 behaviour stays unchanged. | Removed from open questions. |
| **Closed — do not reopen** | D71–D79 | Save/Load flow and the interaction prompt are closed. `UI/Interaction/Prompt` `461:6479` is the approved prompt for Talk, Pick up, Save, Shop, Craft, Enchant, Fish and other contextual actions. The concept-art fishing-village HUD is not authoritative (D73). | — |
| **D18 — DEFERRED (future feature, not cut)** | follow-up | **Character switching is planned, but not in the current scope.** Do not implement switching and do not add a character grid to Status now. **Final roster size is undecided** — neither the 8 hard-coded characters nor Figma's 4 party cards is the roster spec. **Stat Points are planned** for the future: keep them in the product plan, do not implement yet. Status keeps showing the active character only. | Audit kept in §5 for reference. |
| **D56 — DEFERRED (keep dormant)** | follow-up | **Keep the dormant quest engine; do not delete it.** Do not activate it, build quest content on it, or make the current Journal depend on it. It is **not** the approved architecture for the future quest system. Revisit when quest implementation begins. Known issues stay documented, not fixed: incomplete dialogue-event integration, progress not saved, scene-local architecture may need a redesign for a global Journal. | Audit kept in §5 for reference. |
| **D80** | scope | **Save/Load keeps two scenes** (load menu + save state) with **shared components and logic** extracted. Do not physically merge them into one scene. | Amends D75: still one logical Save Slot Selection flow, two scenes. |
| **D81** | scope | **No Merchant/Blacksmith placement on production maps** in this pass. Build UI and logic separately (test scene / verify scripts). | Slices 2–3. |
| **D82** | scope | **Enchanting is removed from this scope** entirely. Revisit later. | D68 (planned system, dedicated page) still stands. |
| **D83** | scope | **Dialogue: audit only.** Do not decide now between restyling the DialogueQuest addon and building an own presentation layer. | Slices 6–7. |
| **D84** | scope | **Interaction Prompt: improved variant, not 1:1 Figma.** Hug contents, text 14–16 px, same visual style. | Slice 1a. |
| **D85** | scope | **Crafting needs both materials and a gold cost.** | Slice 4. |
| **D86** | scope | **In scope:** Item Pickup ships with the Interaction Prompt (slice 1a); Game Over, Splash and Inventory FILTER are part of Runtime UI Completion. **Slice 1 order:** Prompt + Item Pickup → Save/Load shared logic → Main Menu Continue. | Plan: `runtime_ui_completion_plan.md`. |
| **D87** | process | **Run the full test suite before starting and record a baseline** of pre-existing failures. | Slice 0. |

## 5. Open — none in this register

Implementation-level questions from the Runtime UI Completion plan live in
`questions_for_sapega.md`. No product question in this register is open. D18 and D56 are deferred (see §4). Their audits are kept
below as reference for when the features are picked up.

### D18 — Status character grid (audit 2026-09-27, reference — deferred)

- **Figma has no character grid.** `menu-status` `58:719` shows a single-character
  header. The kit component `UI/CharacterSelector` `222:4786` (one character card: avatar,
  name, class · level, HP/SP) is **not placed in any frame**. `UI/Party Status Panel`
  `68:1177` shows a fixed list of 4 cards and has no selection state.
- **The 8-slot grid was runtime-only.** It existed in the original
  `stats_component.gd` (`CharacterButton1..8` → `_on_character_selected("player_N")`,
  plus Str/Int/Dex/Con "+" buttons) and was removed in `515bb4f3`.
- **Runtime today:** Status shows the active character only
  (`game_manager.get_active_character()`); the party panel is display-only (no input,
  no signals, max 4 cards). The active character is hard-coded to `player_1`
  (`CharacterManager.gd:14, :56`). `switch_character()` exists (`CharacterManager.gd:167`)
  but **nothing calls it**.
- **Data:** 8 characters are hard-coded defaults (`CharacterManager.gd:66-149`), with
  per-character attributes, class and equipment. No roster file, no join/leave, no party
  size concept. Level/XP are global, not per character. **No stat-point pool and no spend
  API** (deliberately excluded, `GameManager.gd:310-314`).
- **Decided (D18):** switching and Stat Points are future features; roster size undecided.

### D56 — dormant quest engine (audit 2026-09-27, reference — deferred)

- **What exists:** 5 scripts in `SampleProject/Scripts/Quest/` (615 lines, plus 5 `.gd.uid`):
  `SceneQuestManager` (307, linear per-scene stages advanced by finished dialogues),
  `SceneQuestConfig` (61), `QuestStageResource` (56), `QuestProgressUI` (152),
  `QuestDialogueItem` (39). **No authored data** (`.tres`/`.tscn`/`.json`). Unrelated to the
  `DialogueQuest` dialogue addon.
- **Use:** never instanced — not an autoload, not in any scene, not loaded, not registered.
  Only `Canyon.gd:30` and `Village.gd:31` do a `get_node_or_null("SceneQuestManager")` that
  always returns null.
- **Cost of keeping it:** negligible at runtime (two dead lookups plus two info logs); no
  startup parsing, no `_process`, no tests. Maintenance cost: 5 global `class_name`s and
  dead guarded code in Canyon/Village. Latent bugs: `Engine.has_singleton("EventBus")`
  (:47) would stop it hearing dialogues; `_restore_progress` is an empty TODO, so progress is
  never saved.
- **Journal today:** `journal_component.gd` uses only `Game.objective_updated` /
  `current_objective`. Its `set_entries()` (id, title, state, objectives, description) is
  never called.
- **To use it for the Journal later:** instance a manager per scene; author `.tres`
  configs; fix the EventBus check; add save/restore; map stages → entries; add
  player-facing objective text (stages hold raw dialogue IDs); solve the cross-scene log,
  because each manager covers only one scene.
- **Deletion list:** the 5 `.gd` + 5 `.gd.uid`; `Canyon.gd:30, :73, :638-673`;
  `Village.gd:31, :41, :255-290` (lines 30/31 use the type and would break compilation if
  left); stale comment `journal_component.gd:9-10`; docs
  `docs/QUEST_SYSTEM_IMPLEMENTATION.md`, `docs/QUEST_SYSTEM_SETUP.md`,
  `docs/QUEST_SYSTEM_SUMMARY.md`, `design/journal_audit.md:106`, `design/ui_visual_qa.md:1045`.
  No scenes or tests break.
- **Decided (D56):** keep dormant; revisit when quest implementation begins.

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
