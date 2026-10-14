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

---

## 8. Sapega's answers to Q1–Q28 — 2026-09-29

All open questions in [[questions_for_sapega]] answered in one pass. Recorded
verbatim in intent; nothing here is inferred. Q1 needed no decision.

### ⚠️ Seven of these reverse shipped code

Slices 1b, 2 and 8 built the **previous** defaults and are green in the test
suite. These answers undo that work. Listed here so nobody reads a passing test
as agreement with the current decision.

| D-ID | Q | Was built | Now decided | Cost |
|---|---|---|---|---|
| D89 | Q3 | Slot card shows real level + lead character (slice 1b) | Mock data, to look like Figma; real fields later | Rework `save_slot_card`; `verify_save_load` expectations change |
| D90 | Q4 | Player data made **per slot** (slice 1b) | Revert to one shared `player_data.json`; per-slot later | **Reintroduces a known correctness bug**: loading slot 2 restores slot 1's inventory and stats |
| D91 | Q5 | Auto-save on touch **removed** (slice 1b) | Auto-save on touch stays, in parallel with the save prompt | Two save paths to keep consistent |
| D99 | Q13 | `CLAUDE.md` test instructions corrected (slice 8) | Leave `CLAUDE.md` alone for now | The "154 GUT tests" claim returns to being wrong and misleading |
| D104 | Q18 | Buy one at a time, `Quantity: 1` (slice 2) | Add a quantity selector | New UI, undesigned in Figma |
| D105 | Q19 | "Not Enough Gold" modal from the shared family (slice 2) | Grey out / disable unaffordable rows; no mandatory modal | Remove the modal path, add a disabled row state |
| D108 | Q22 | Blacksmith = furnace + anvil + workbench | **All four** stations, with tabs `Furnace │ Workbench │ Anvil │ Alchemy` | Slice 4 scope grows; tab strip is undesigned in Figma |

D90 is the one worth a second look: the per-slot fix was made *because* shared
player data makes slot selection incorrect. Reverting is a deliberate choice to
carry that bug.

### Pickups and interaction

| ID | Kind | Decision |
|---|---|---|
| D88 | OVERRIDE | **Q2.** Three distinct pickup paths: enemy loot is automatic with no modal; items placed on the map need an interaction prompt and show the pickup modal after collection; a chest opens on button press, adds its contents automatically, and **then** shows the pickup modal. |
| D98 | OVERRIDE | **Q12.** Prompt badge shows `E` on keyboard and `A` on gamepad, switching automatically with the last-used input device. |
| D100 | OVERRIDE | **Q14.** Item pickup uses the shared modal family. No dedicated compact pickup card. |

### Save / load / game over

| ID | Kind | Decision |
|---|---|---|
| D89 | OVERRIDE | **Q3.** Save-slot card filled with **mock data** so it matches the Figma layout. Real fields wired later. ⚠️ reverses slice 1b. |
| D90 | OVERRIDE | **Q4.** `player_data.json` stays **shared across slots**. Per-slot player data is deferred. ⚠️ reverses slice 1b; carries the slot-correctness bug. |
| D91 | OVERRIDE | **Q5.** Auto-save on touch **stays**, running in parallel with the manual save prompt. ⚠️ reverses slice 1b. |
| D92 | OVERRIDE | **Q6.** Game Over: *Resume from last save point* loads the last saved/loaded slot; second button *Return to Title*; **plus a third, Load Game**, opening the existing Load menu. The third button is not in Figma. |
| D93 | OVERRIDE | **Q7.** Delete Save Slot stays, styled with the existing modal family. |
| D109 | OVERRIDE | **Q23.** With no save yet, *Resume from last save point* falls back to the old respawn at the room entrance. |

### Blacksmith, crafting, enchanting

| ID | Kind | Decision |
|---|---|---|
| D115 | OVERRIDE | **Blacksmith menu is `Craft` + `Enchant`.** No Equipment, no Buy/Sell. Supersedes the earlier hide-Enchant decision. |
| D94 | OVERRIDE | **Q8. Enchanting is back in scope** — supersedes D82. Mechanic: **two identical items → one upgraded item at +1.** Weapon +1 damage, armour +1 defense, jewellery +1 magic defense. No system and no UI exist — needs a plan note. |
| D95 | OVERRIDE | **Q9.** The old "Blacksmith = Shop Equipment mode" path is removed. |
| D96 | OVERRIDE | **Q10.** `ForgeSystem.gd` is deleted as a stub and replaced by a real crafting system / `CraftingManager`. |
| D97 | TECH | **Q11.** Use **mock `gold_cost` values** for now; balancing comes later. This is an explicit, time-boxed exception to the project's no-invented-numbers rule — the numbers are placeholders by decision, not by guess. **Unblocks slice 4.** |
| D106 | OVERRIDE | **Q20.** The Blacksmith sells nothing. The `blacksmith` stock list in `merchants.json` stays in the file, unused. |
| D108 | OVERRIDE | **Q22.** Blacksmith covers **all four** station types, with a tab strip `Furnace │ Workbench │ Anvil │ Alchemy`. ⚠️ widens slice 4; the tab strip has no Figma design. |

### Shop

| ID | Kind | Decision |
|---|---|---|
| D101 | OVERRIDE | **Q15.** Normal party panel stays. No stat-comparison logic for now. |
| D102 | OVERRIDE | **Q16.** Category mapping confirmed: sword → weapons, shield → shields, helmet → other armor, bell → accessories, scroll → consumables + materials. |
| D103 | OVERRIDE | **Q17.** `Equipment` is removed from **both** the Shop and the Blacksmith menu. Equipping happens in the normal Game Menu. |
| D104 | OVERRIDE | **Q18.** Add a **quantity selector** to the Shop. ⚠️ reverses slice 2; undesigned in Figma. |
| D105 | OVERRIDE | **Q19.** Unaffordable rows are **disabled / greyed out**. The "Not Enough Gold" modal is no longer mandatory. ⚠️ reverses slice 2; no Figma state exists for a disabled row. |
| D107 | GAP | **Q21.** The Figma NPC art for Merchant and Blacksmith is the current in-game art. |

### Dialogue

| ID | Kind | Decision |
|---|---|---|
| D110 | OVERRIDE | **Q24 — resolves D83.** DialogueQuest stays as **engine, data and branching**. Presentation is a **project-owned layer**, compatible with `DQDialogueBox` / `DQChoiceMenu`. The addon prefab is **not** restyled directly. This is neither option A nor B from [[dialogue_audit]] §3 — it keeps the addon's data path and replaces only its rendering. |
| D111 | OVERRIDE | **Q25.** Special story dialogue is **not deferred**. Much of the prologue's story dialogue moves onto the special story presentation. |
| D112 | OVERRIDE | **Q26.** Story scenes use **full-body character art**, not portraits. Existing assets are usable for now (e.g. Зомбі, Кусакам). Supersedes the "wait for portrait art" default. |
| D113 | OVERRIDE | **Q27.** Choices are not needed yet. No branching / choice UI work now. |
| D114 | OVERRIDE | **Q28.** Duplicate speaker IDs that clearly denote one character are merged into one canonical ID. `.dqd.tmp` and technical litter may be cleaned. **Dialogue lines themselves are not rewritten.** |

### Not a decision

**Q1** — nothing was lost; the unlisted items were simply not enumerated.

---

## 9. Game Menu structure — 2026-10-12

| ID | Kind | Decision |
|---|---|---|
| D116 | TECH | **The Game Menu is one scene.** Every window (7 tab panels, sidebar, party column, bottom bar) is a node in that `.tscn`; the script only shows and hides them. The frame is the shared `base_menu.tscn` (also used by the Shop), instanced with editable children: it owns the background, title, an **empty `Sidebar`** (296 wide, `TopSpacer` 48, `MenuSidebar` gaps) and an **empty `Content` slot**; each screen puts its own buttons and panels into them. `UIMenuShell` was deleted. No `add_nav_item()`, no runtime mounting. **The initial state lives in the scene too** (which panel is visible, which tab is pressed); the script hides nothing on `_ready()` and only reacts to presses. Plan: [[game_menu_single_scene_plan]]. |
| D117 | TECH | **Data rows extend from a template that lives in the scene.** Where a list grows with data (stat rows, equipment slots, party cards, item lists), one real row node sits in the `.tscn` — at least one character always exists, so it is also the first row — and further rows are duplicated from it. Rows are not assembled from `Label.new()` / `StyleBoxFlat.new()`. |
| D118 | OVERRIDE | **Game Menu sidebar pointer = the main menu's `▶`.** Exactly one: on the tab under focus / mouse (hover grabs focus, as on the main menu); when focus is in the content, it returns to the pressed tab. Implemented as theme variation `SidebarTab` (icon transparent) ↔ `SidebarTabOn` (icon `TEXT_PRIMARY`); the scene authors the initial `SidebarTabOn` on Inventory. Replaces the floating `cursor_indicator.gd` (closes [[BUGS]] B3, B38). Settles [[questions_for_sapega]] Q33 **for the Game Menu sidebar only** — the other surfaces in Q33 stay open. |
| D119 | OVERRIDE | **Main menu items are centred under the title**, each button hugging its content so the `▶` sits next to the text. Replaces the Figma `UI/Menu Item` 300 px left-aligned column on this screen (`MainMenu.gd` no longer forces `MENU_ITEM_WIDTH`; Game Over still uses it). Closes [[BUGS]] B17. |
| D120 | GAP | **Journal story structure: stage → sub-stages.** The Prologue is one journal stage; its sub-stages are the zones in story order — **Canyon I → Village → Canyon II → Desert Road → City Gates → Laboratory → Laboratory — Outside** (the canyon is visited twice and each visit is its own sub-stage, numbered like parts), "like Dragon Nest" main-quest chapters. Done / current / locked per zone, the live objective under the current one. Built for more stages later (main game). No Figma frame. Plan: [[prologue_journal_plan]]. |
| D121 | OVERRIDE | **Q36, Q37. English is the primary language** of all user-facing text, before localization. Zone titles are English (`Resources/Data/story.json`). The ~30 Ukrainian objective strings in the zone scripts (`Village.gd`, `DesertRoad.gd`, `CityGates.gd`, `Laboratory.gd`, `LaboratoryOutside.gd`, part of `Canyon.gd`) were translated to English on 2026-10-12 (24 strings, 34 calls). Sapega: these are **placeholder objectives, not authored text**, so a direct translation was fine; rewrite freely when the real story text lands. |
| D122 | GAP | **Journal chronicle.** Each sub-stage keeps a micro-story of what already happened — one line per story step, shown once that step's quest flag is set, as the sub-stage's text on the right of the Journal (D124) (Sapega: "кусакам помедитував…, кусакам побив бандита і відправився шукати діда"). Lines live in `Resources/Data/story.json` → `zones[].chronicle[{flag, text}]`. The 21 lines were **drafted by Claude from the `.dqd` dialogue on Sapega's request** — English (D121), placeholder quality, edit freely. They follow the game's actual order: the meditation is at the relic **after** the village (`Canyon_MeditationAtRelic`); `AfterFight_Meditation.dqd` is used by no code. |
| D123 | GAP | **Journal keeps both objective displays.** The `CURRENT OBJECTIVE` panel at the top and the objective under the current sub-stage show the same text on purpose — the top panel is visible the moment the Journal opens, the inline one keeps it next to its sub-stage. Not a duplicate to clean up. |
| D124 | OVERRIDE | **Journal layout: everything on the left, text only on the right.** Left: the stage header (`PROLOGUE`) and one item per sub-stage (✓ done · ● current · ○ locked, locked items cannot be opened). Right: only the open item's text — its chronicle (D122). No page flipping; arrows / mouse pick an item. Replaces the D120 first draft where sub-stages were drawn inside the right pane. |
| D125 | OVERRIDE | **Objectives are sub-items under their sub-stage, on the left.** An objective appears once it becomes available and stays after it is done (✓); the next one is ● current; later ones are hidden. Clicking an objective leaves the right-hand text unchanged (it shows its sub-stage). Data: `story.json → zones[].objectives[{flag, text}]`; a sub-stage is done with its last objective, so `done_flag` was removed. Texts are the game's own `set_objective()` strings (test-enforced). Not listed because the game never shows them as current: "Help the old man" / "Make a decision" (share `village_oldman_complete` with the previous step), "Explore the village" (only during the abduction cutscene). Canyon II's relic meditation has no objective in the game. |
| D126 | OVERRIDE | **Tutorial = topic list in the Game Menu centre + one full-screen window per topic.** Misc → Tutorial shows the topic list (`130:1172`) as a panel in `base_menu`'s centre, Misc stays the selected tab, sidebar and party column stay; choosing a topic opens it full-screen (`135:1260`, no sidebar, no party column), arrows switch topics, B/Esc returns to the list. **Topics only for systems that exist** — Basic Controls, The Map, Saving Your Progress, The Journal; English texts drafted by Claude from the real bindings, images are in-game screenshots (`capture_tutorial_shots.gd`), all editable in `Resources/Data/tutorial.json`. Topic-row icons (36 px squares in Figma) are placeholders there and are not built. Fixes B2. Mapping: [[tutorial_mapping]]. |
| D127 | GAP | **Drinking a potion from the Inventory.** Enter / double-click on a healing consumable → focus moves to the party cards → choose who drinks it → confirmation (shared modal family) → `CombatBody2D.heal_damage()` + one item removed. Only characters with a real HP model can be chosen — today the active character only (others have no HP, D18); a card at full HP is not selectable, and if nobody can be healed the bottom bar says so and nothing is spent. Esc while choosing returns focus to the item. `ether` (mana) is not usable yet — no SP model. No Figma frame for the flow; built from `UI/Party Character Card` + `UI/Modal/Confirm`. The party card moved to a scene template on the way (D117). |
| D128 | GAP | **Item icons from Figma `🎨 Icons & Assets → 📦 Item & Skill Icons`** (partly closes D5). Exported as whole symbols (grey 36 px tile + line icon, as drawn) into `Assets/UI/Icons/Items/`: potion / hi_potion / potion_lesser / potion_medium → `flask-conical`, ether → `bottle-wine`, herb → `leaf`, mana_crystal → `gem`. Still placeholders: weapons, armour, helmets, shields, ore, ingots, wood, stone, leather — Figma has no item tile for them (its `icon/equipment/*` are bare dark strokes, invisible on dark rows; `sword-frame` is the gold *selected* tile). The old `res://release/assets/textures/ui/items/...` paths never existed in this repo. |
| D129 | GAP | **Starter loot (Sapega, 2026-10-12).** A new game starts with no potions and nothing equipped. The **first enemy killed in the game drops exactly 5 potions**, once (`first_kill_potions`). The old man gives **Copper Sword + Leather Armor** after the **last** of his three talks (`OldMan_Decision`), once (`village_oldman_gift`). An empty potion stack leaves the inventory list. |
| D130 | GAP | **Mayor's Hall → Laboratory is a one-way teleport (Sapega, 2026-10-12).** City → Mayor's Hall → the mayor's cutscene (`City_MayorHall`) → teleport to `Laboratory.tscn` / `SavePoint_Entrance`. The Laboratory stays on MetSys layer 2 with no passage back to the city — that is the design, not a gap. A maze after the lab is wanted later; its shape is undecided. |
| D131 | OVERRIDE | **No fallbacks (Sapega, 2026-10-12).** Missing nodes, managers or autoloads fail loudly; no silent `if x: … return`, no `get_node_or_null`/`has_method` guards where the type is always known, no retry-if-empty, no old-save compatibility branches. Checks stay only where the type is genuinely unknown (a body entering an area, the control under the cursor). Dead files are deleted (git keeps them). **Old saves may break** — play from New Game. |
| D132 | GAP | **Random loot is on as written (Sapega, 2026-10-12).** Once `EventBus.enemy_died` really fires (B50), `LootSystem` drops gold and, with its chance, a potion from every enemy, with the numbers already in the code — on top of D129's first-kill potions. |
| D133 | GAP | **Save slot location = the journal zone title (Sapega, 2026-10-12).** The slot card shows the zone name from `story.json` ("Desert Road", "Village", …), not the scene or "Game". Rooms that are not journal zones (City, Mayor's Hall) show the scene's own name. |
| D134 | OVERRIDE | **Dialogue box takes its look from `GameUITheme`** — the code-built grey StyleBox override is removed. The full dialogue design (D110) is still separate work. |
| D135 | OVERRIDE | **Music: every room's track is assigned explicitly in the music table** — no runtime fallback to `main_theme` when a file is missing; a missing file is an error. (Sapega chose "assign `main_theme` explicitly"; on inspection no `main_theme` — and no music config — ever existed, so the assignment itself is Q38. [[music_plan]].) |
| D136 | OVERRIDE | **The Game Menu does not open during a dialogue.** Esc / the HUD menu button do nothing while a conversation runs (`UIManager.can_open_pause_menu`). Before, the dialogue (layer 100, `PROCESS_MODE_ALWAYS`) drew over the menu and kept taking Enter/clicks. (Sapega chose this over hiding/pausing the box, 2026-10-13.) Fixes B16. |
| D137 | OVERRIDE | **Canyon exit: a trigger halfway down the stairs plays `Canyon_ExitCutscene`, then the player is moved onto the Desert Road** (`ArrivalFromCanyon`, left of the start save point). Only after returning from the village (`RELIC_PICKUP`); before that the stairs are plain stairs. (Sapega, 2026-10-13.) |
| D138 | OVERRIDE | **Q40. Kusakam keeps the current 64×64 player art; the missing states (Idle, Jump, Fall, Attack, Hurt, Death) are drawn in the same style.** Needs an artist — [[character_animation_plan]] slice 1 waits on the frames. (Sapega, 2026-10-13.) |
| D139 | OVERRIDE | **Q41. Enemies and NPCs stay as they are for now** (one shared enemy sheet, static NPCs). [[character_animation_plan]] slices 2–3 deferred. (Sapega, 2026-10-13.) |
| D140 | OVERRIDE | **Q42. Village becomes a staged sequence:** the abduction is a fade + dialogue; then a talk with the first bandit → the fight → "oh no, I must check the house" → **the old man is a real cutscene, not just a dialogue**: he heals Kusakam, Kusakam heals him, and Kusakam gains his **first skill**. Kusakam needs at least a few skills defined. Other beats not decided yet. (Sapega, 2026-10-13.) |
| D141 | OVERRIDE | **Kusakam's skills:** **Длань лікування** (Healing Palm) — taught by the old man, the first skill; **Електричний удар** (Electric Strike) — only with a halberd or a mace in hand; **Вогняний удар** (Fire Strike) — only with a sword or a dagger in hand. (Sapega, 2026-10-13.) |
| D142 | OVERRIDE | **Skill targeting** (supersedes the deferral in D38 for these skills): a strike hits **everything in front of the hero** in the attack area; Healing Palm heals **an ally next to the hero, otherwise the hero**. (Sapega, 2026-10-13.) |
| D143 | OVERRIDE | **Halberd, mace and dagger are added as items** with **mock** prices and stats next to `iron_sword`; balance later. (Sapega, 2026-10-13.) |
| D144 | TECH | **Mock skill numbers** (like D97): Healing Palm +30 HP / 5 SP / 4 s; Fire Strike 20 dmg / 6 SP / 2 s; Electric Strike 25 dmg / 8 SP / 3 s. Balance later. (Sapega, 2026-10-13.) |
| D145 | OVERRIDE | **"Kusakam heals the old man" is a player action:** in the old man's cutscene the player uses Healing Palm on him (the skill is taught right there). (Sapega, 2026-10-13.) |
| D146 | TECH | **Mock SP pool:** Kusakam has 30 max SP and regains 1 SP per second. Balance later. (Sapega, 2026-10-13.) |
| D147 | OVERRIDE | **A new equipment slot `mace`** (12 slots). Halberd → `polearm`, dagger → `dagger`, mace → `mace`. (Sapega, 2026-10-13.) |
| D148 | OVERRIDE | **Healing Palm is not bought with points: the old man teaches it, as a tutorial.** When he is dying ("your grandfather is dying — use Healing Palm") the skill is learned automatically, put on slot 1, and the player uses it on him (D145). It heals **40** — 10 less than a Potion (50); it upgrades like every skill (D150). (Sapega, 2026-10-13.) |
| D149 | OVERRIDE | **Skills are learned with skill points** (JP in code): **2 per character level**. Fire Strike and Electric Strike cost 1 point to learn and **unlock at character level 6**. Answers Q43. (Sapega, 2026-10-13.) |
| D150 | OVERRIDE | **Every skill — Healing Palm included — upgrades up to rank 20:** 1 point = +1 rank = **+10 %** effect (damage or healing; rank 20 = ×2.9). SP cost and cooldown do not change. Mock, balance later. (Sapega, 2026-10-13.) |
| D151 | OVERRIDE | **Game Menu tabs are opened by the story.** At the very start only **Misc** is open; a locked tab is grey with a lock and cannot be pressed or focused, and the menu opens on Misc while Inventory is locked. Journal ← `village_abduction_complete`; Skills ← `village_oldman_healed` (the old man teaches Healing Palm); Inventory, Equipment, Status ← `village_oldman_gift`; World Map ← `village_left_complete`. Each button carries `metadata/unlock_flag` in `game_menu.tscn`. **Pressing Misc only opens its list of items** (Settings / Tutorial / exits); Settings appear only after choosing Settings, the previous tab stays selected otherwise, and a menu that opens on Misc has an empty centre. (Sapega, 2026-10-13.) |
| D152 | OVERRIDE | **Re-entering a room leaves its enemies as the player left them:** killed ones stay dead, living ones keep their HP, until the fight is won; the fight's dialogue is not replayed. Answers Q44. Spec for [[room_state_plan]] slice 2. (Sapega, 2026-10-14.) |
| D153 | OVERRIDE | **Camera vs room size — leave as is for now.** Zoom 1 (1920×1080 view) against 864×480 MetSys cells; empty space around small rooms is accepted until revisited. Answers Q45. (Sapega, 2026-10-14.) |
