# Runtime UI Completion — Implementation Plan

Umbrella scope approved by Sapega on 2026-09-27. The work is split into sequential
vertical slices. Each slice:

- uses Figma as the visual source of truth and existing Godot systems as the
  runtime source of truth;
- uses no placeholder or fake production data;
- adds focused tests (`SampleProject/UI/verify_*.gd`) and, where relevant, a
  responsive/focus check with screenshots;
- ends in its own commit and updates `figma_coverage.md`;
- stops **only itself** on a real blocker and records the minimum question in
  `questions_for_sapega.md`.

Decisions: `figma_decision_register.md` (D1–D87). Open questions:
`questions_for_sapega.md`.

---

## Out of scope for this pass

Healing, Jobs (D65) · Enchanting (D82) · character switching, final roster, Stat
Points (D18) · quest engine activation or rework (D56) · skill auto-targeting (D38)
· Figma Controls skill-slot cleanup (D47) · Merchant/Blacksmith placement on
production maps (D81) · choosing the dialogue presentation approach (D83).

---

## Facts from the pre-plan audit that shape the slices

| Area | Current runtime | Consequence |
|---|---|---|
| Tests | **No GUT tests exist.** No `tests/` folder; `gutconfig` points to missing paths. The real suite is 17 `SampleProject/UI/verify_*.gd` scripts (headless `--script`). `CLAUDE.md`'s "154 tests" is stale. | Baseline = the 17 verify scripts. New tests follow the same pattern. |
| Save slots | `SaveSystem` has 4 slots (`user://saves/slot_%02d.sav`) with metadata `{timestamp, location (raw MetSys room name), slot}` + playtime. | Slot cards can show date, location, playtime from real data. Level, party and region need new metadata or must be left out (Q3). |
| Player data | `save_player_data()` writes **one shared** `user://savegames/player_data.json`, not per slot. | Loading slot 2 may restore slot 1's player data — a correctness risk for slot selection (Q4). |
| Save/Load scenes | `LoadGameMenu.gd` already has `set_mode("save"/"load")`; `save_game_state.gd` just instances it in save mode. Also has a **delete-slot** modal (not in Figma). | D80 "two scenes + shared logic" is mostly there; the work is extracting a reusable slot-card component and aligning with Figma. |
| Main menu | Continue and Load Game both open `LoadGameMenu`. `_check_save_file_exists()` is never called. Title screen already has a working "press any button" state. | D72: remove Load Game; Continue → LOAD mode. Splash reuses the existing title state. |
| Save points | **Auto-save on touch** (`SavePoint.gd` `body_entered`), no UI. Present in 8 production maps. | D74/D75 change this to prompt → slot selection (Q5). |
| Item pickup | All automatic on touch: coins fly to the player, orbs `collect()`, enemy loot goes straight into the inventory. No pickup UI, no `item_picked_up` signal. | D71 prompt + confirm modal needs a rule for which pickups use it (Q2). |
| Interaction | **No `interact` input action.** Merchant and RelicArmor hard-code `KEY_E`/`ui_accept` with their own labels. `addons/interaction_system` is unused. | Slice 1a adds an `interact` action and one shared interactable + prompt. |
| Game over | `Player.kill()` teleports to `reset_position` and restores HP. No UI. | The Game Over screen needs a respawn rule (Q6). |
| Modals | `ModalTemplates.misc_popup(title, desc, ok_text)` → one-button modal; result via `ModalLayer.modal_closed`. | Pickup confirm, Game Saved and save error reuse it (D79). |

---

## Slice 0 — Test baseline (no code changes)

- Run all 17 `verify_*.gd` scripts headless with Godot 4.6.3; run GUT once to
  confirm it finds nothing.
- Record per-script pass/fail, errors and warnings in `design/test_baseline.md`.
- Pre-existing failures are recorded, not fixed.
- Commit: baseline doc only.

## Slice 1a — Interaction Prompt + Item Pickup — ✅ DONE

> Done: `interaction_prompt.tscn`, `InteractableComponent`, `ItemPickup.tscn`, `interact` action,
> Merchant + RelicArmor migrated. `verify_interaction.gd` 51/51; full suite matches the baseline
> (17/18, same `verify_responsive` failure). Shots: `design/shots/interaction_prompt_1920.png`,
> `item_pickup_modal_1920.png`.
>
> Found, not fixed (out of scope): `InventoryManager.add_item()` guards `EventBus.item_added` with
> `Engine.has_singleton("EventBus")`, so that global signal never fires; `RelicArmor` finds no
> DialogueManager for the same reason (it is not placed in any scene).

**Figma:** `UI/Interaction/Prompt` `461:6479` (improved variant, D84: hug width,
14–16 px text, same style); `UI/Modal/ItemPickup` `222:4880`; `28:5`, `28:25`.

1. Add an `interact` input action (keyboard E, gamepad A). This matches the
   Figma prompt badge and the Controls "Interact / Examine" row.
2. Build a reusable `InteractionPrompt` UI scene: badge + action text, states
   Default / Focused / Disabled, themed from `UITokens`.
3. Build a reusable interactable component (Area2D + action label + `interacted`
   signal) that shows and hides the shared prompt. Do not hard-code keys.
4. Migrate Merchant's "Press E" label and RelicArmor to it, keeping their current
   behaviour.
5. Item pickup per D71: prompt "Pick up" → item added through `InventoryManager`
   → `UI/Modal/ItemPickup` confirmation. Applies **only** to the pickup types
   agreed in Q2. Default until answered: world item pickups; coins and enemy loot
   stay automatic.
6. Tests: prompt shows and hides on enter/exit, label and badge are set, the
   `interact` action fires `interacted`, the item lands in the inventory, and the
   modal opens and closes with focus on OK.

## Slice 1b — Save/Load shared logic (two scenes, D80) — ✅ DONE

> Done: `SaveSlotCard` component + rewritten `LoadGameMenu` (shared by `load_game_state` /
> `save_game_state`), `SaveSystem` per-slot player data + `get_slot_summary` / `delete_slot`,
> `Game.save_game() -> bool` (level + lead character in metadata), save point → prompt → SAVE mode,
> `save_delete` action (Delete / pad Y). `verify_save_load.gd` 55/55; full suite matches the baseline.
> Defaults applied: Q3 (level + name, no portraits/region), Q4 (per-slot player data), Q5 (no auto-save),
> Q7 (delete kept).
>
> Fixed on the way (blocking this flow):
> - `Game._save_full_game_data_to_save_system()` and `LoadGameMenu` used `Engine.has_singleton("ServiceLocator")`
>   → inventory/flags were never saved with a slot, slot metadata was never read, `set_current_slot()` never ran.
> - `save_system.has("player_data")` (nonexistent method) in the same function.
> - `ModalLayer` closed twice per button press (`chosen` + `confirmed`), emitting `modal_closed` twice and
>   destroying any follow-up modal (overwrite → Game Saved).
>
> Not migrated: saves made before this change keep their MetSys slot file but have no per-slot player data
> (it was never written for them anyway).

**Figma:** `17:5` (SAVE), `150:1278` (LOAD), `258:5162` overwrite,
`UI/Save Load Top Section` `217:1597`, `UI/Save Load List Area` `217:3038`.

1. Extract a shared **SlotCard** component and a shared slot-list controller used
   by both the load scene and the save state. The scenes stay separate.
2. Restyle both to Figma: top section, 4 slot cards, gold selected state, empty
   card, bottom bar hints.
3. Card fields: date, location and playtime from real metadata. Level / lead
   character / party / region only after Q3 — no invented values.
4. LOAD mode: empty slots visible but disabled and unfocusable (D77); occupied
   slot loads directly (D78).
5. SAVE mode: overwrite confirm only on occupied slots; on success the "Game
   Saved" modal (D76), then close and return to gameplay; on failure an error
   modal from the same family (D79). The result is read from `Game.save_game()` /
   `SaveSystem`.
6. Save point per D74/D75: `interact` → prompt "Save" → SAVE mode. Auto-save on
   touch is replaced or kept according to Q5.
7. Keep the existing delete-slot action until Q7 is answered (no removal of
   functionality).
8. Tests: focus skips empty slots in LOAD, overwrite appears only on occupied
   slots in SAVE, success/failure modal branching, both scenes use the shared
   component.

## Slice 1c — Main Menu Continue + Splash — ✅ DONE

> Done: `MainMenu.tscn` rebuilt to Figma 9:26 / 258:5140 (title block with letter-spacing, diamond
> dividers, `UI/Menu Item` styles, forest background exported from Figma, Figma copyright copy).
> Load Game removed (D72); Continue → Save Slot Selection LOAD, disabled and skipped by focus when no
> save exists; Options renamed Settings (Figma copy). `verify_main_menu.gd` 29/29; full suite 20/20.
> Deviations: title rules 1.5/2.5 px → 2/3 px (integer line widths); vertical position of the centre
> block is centred rather than Figma's exact 267/352 px offsets.

**Figma:** `9:26`, `258:5141`.

1. Remove the Load Game button (D72). Continue → load scene in LOAD mode.
2. Continue disabled when no slot has data (wire the existing
   `_check_save_file_exists()`).
3. Splash: restyle the existing "press any button" title state to `258:5141`.
4. Tests: Continue state with and without saves, focus order, no Load Game node.

## Slice 2 — Merchant / Shop (UI + logic, no map placement, D81) — ✅ DONE

> Done: `ShopService` (categories, buy, sell, gold = inventory "coin"), `ShopRow`, `NpcActionMenu`,
> `shop_menu.tscn` / `shop_ui.gd` rebuilt to Figma 153:1289 / 153:1523 / 153:1760, Merchant NPC menu
> (164:1302), `menu_prev_tab` / `menu_next_tab` actions (Q/E, LB/RB). `verify_shop.gd` 42/42.
>
> Found on the way: the old shop lists were stubs (`set_table()` only warned — the shop never showed
> items), every lookup used `Engine.has_singleton`, and `Merchant.open_shop()` called a nonexistent
> `Node.has()`. Old `item_list_display` / `buy_…` / `sell_…` / `tooltip` scripts removed.
> Item icons still fall back to placeholders (D5 — art not in the project).

**Figma:** `153:1289`, `153:1523`, `153:1760`, `164:1302`.

1. Fix `shop_ui.gd:43` `Engine.has_singleton("ServiceLocator")` so the shop gets
   `ItemDatabase` and `GameManager`. Only the shop's own call sites.
2. Merchant NPC menu (Talk / Quest / Buy) via the shared prompt → shop.
3. Restyle buy / sell / confirm to Figma and the shared theme. Remove hard-coded
   colours and local style boxes. Fix the accent-on-accent selected row (D26 rule).
4. Reachable through a test scene or verify script only. No production map.
5. Tests: buy/sell change gold and inventory, the confirm modal, and category tabs.

## Slice 3 — Blacksmith NPC flow (D69, no map placement)

**Figma:** `176:1357`.

1. A separate Blacksmith NPC with the menu Talk / Quest / Craft. Enchant is
   hidden or disabled while Enchanting is out of scope (Q8).
2. Remove the blacksmith-as-shop-Equipment-mode path from the shop, or keep it
   until slice 3 is verified (Q9).
3. Tests: menu entries, Craft routes to slice 4's screen.

## Slice 4 — Crafting (materials + gold, D85)

**Figma:** `160:1291`, `164:2326`, `164:2545`, `164:2764`; `UI/Recipe Confirmation
Panel` `217:2189`; `UI/Craft Error Modal` `217:2983`.

1. A `CraftingManager` (ManagerBase, registered through ServiceLocator) that reads
   the 18 existing recipes from `ItemDatabase`: check materials **and** gold,
   consume both, add the result. Replaces the `ForgeSystem` stub or sits beside it
   (Q10).
2. Recipes need a gold cost. If `crafting_recipes.json` has none, the slice stops
   for costs (Q11) — no invented prices.
3. List → detail → confirm → error screens per Figma, reached from the blacksmith.
4. Tests: can/can't craft, exact consumption, error messages.

## Slice 5 — Game Over + Inventory FILTER (replaces Enchanting in the order)

**Figma:** `41:83`; `46:193`.

1. Game Over screen on `EventBus.player_died`, per the Q6 rule. Options come from
   the frame (e.g. "Resume from last save point").
2. Inventory FILTER cycles ALL → CONSUMABLES → MATERIALS → EQUIPMENT → KEY ITEMS
   → ALL with an active indicator; KEY ITEMS shows the empty state (D9).
3. Tests: death → screen → chosen option, the filter cycle and empty state.

## Slice 6 — Standard NPC Dialogue (audit only, D83)

Audit the DialogueQuest box against `36:6` / `UI/Character Dialogue` `127:1087`.
Document restyle-the-addon vs own-presentation-layer options, costs and risks.
No implementation.

## Slice 7 — Special Story Dialogue (audit only, D83)

Same audit for `36:65` (special story scenes, D70) and the cutscene path.

## Slice 8 — Final runtime UI regression and cleanup

1. Re-run the full verify suite and compare against the slice 0 baseline.
2. Screenshot pass at 1920×1080 and one smaller resolution for every touched
   surface.
3. Remove dead code that these slices superseded (e.g. hard-coded prompt labels).
4. Update `figma_coverage.md`, `UI_SURFACE_AUDIT.md` and `CLAUDE.md` test
   instructions.

---

## Order and dependencies

`0 → 1a → 1b → 1c → 2 → 3 → 4 → 5 → 6 → 7 → 8`

- 1a first: the prompt and the `interact` action are used by 1b, 2 and 3.
- 5 has no dependency on 2–4 and can move earlier if those slices block.
- 6 and 7 are audits and can run at any time.
