---
type: plan
status: planned
figma: "enchant-list (node id not in the repo — Figma MCP was down 2026-10-14)"
---

# Enchanting — plan

**Slices 1–2 built 2026-10-15** (rule, service, screen at the Blacksmith); slice 3 (quest) waits on the Tasks system. Planned 2026-10-14. Picked up first because the Blacksmith's enchant quest needs
it (Sapega: "спершу зачарування"). Mechanic decided: **D94** — two identical items → one item at
+1; weapon +1 damage, armour +1 defense, jewellery +1 magic defense. Entry: Blacksmith menu
(**D115**). Supersedes D82.

## What exists today

| Thing | Where | State |
|---|---|---|
| Enchant entry in the Blacksmith menu | `Scripts/Gameplay/NPCs/Blacksmith.gd:12,35-36` | ⚠️ hidden, `ENCHANT_ENABLED := false` |
| Inventory | `Scripts/Systems/Inventory.gd` — `items: Dictionary` **item_id → count** | ✅ no item instances exist |
| Item data | `Scripts/Systems/ItemDatabase.gd:109` `get_item(id)` → raw dict from `items.json` | ✅ |
| Enchantable items | `items.json`: 6 weapons (`stats.attack`), 4 armour incl. `iron_helmet`, `iron_shield` (`stats.defense`) | ✅ |
| Jewellery | `items.json` | ❌ none exists — the D94 jewellery rule has nothing to apply to yet |
| `magic defense` stat | `items.json` `stats` has only `attack` / `defense` / `magic` | ⚠️ D94's "+1 magic defense" has no stat to land on — irrelevant until jewellery exists |
| Crafting screen to model the UI on | `Scenes/Crafting/crafting_menu.tscn`, `CraftingService` | ✅ |

## Missing entirely

`grep -rni enchant Scripts/` → only `Blacksmith.gd`. No service, no UI, no data, no test.

## Design — where "+1" lives

**Recommendation: in the id.** `iron_dagger` + `iron_dagger` → `iron_dagger+1`. The inventory, saves
(`save_to_dict` is id → count) and stacking keep working unchanged; `ItemDatabase.get_item("x+N")`
returns the base item with `name` "X +N" and the stat raised by N. No new field in `items.json`.
"Identical" = same id, so `+1` and `+1` make `+2`, and `+1` never merges with a plain one.
Alternative (item instances with their own data) means rewriting the inventory and saves — rejected
unless stacking is refused.

## Decisions required

1. ✅ **D163** — two `+N` → `+N+1`, cap +20.
2. ✅ **D164** — grows with level; provisional 10 % of base buy price × resulting level.
3. Jewellery / magic defense — out of scope until a jewellery item exists. Non-blocking.
4. UI — Figma `enchant-list`; check the frame when Figma MCP is back. Until then, the crafting
   screen's list → detail → confirm pattern. Non-blocking.

## Slices

### ✅ Slice 1 — the rule (built 2026-10-15)
- Built: `ItemDatabase.get_item()` resolves `base+N` (`_enchanted_item`, `base_id`, `enchant_level`,
  `enchanted_id`, `is_enchantable`); `Scripts/Crafting/enchanting_service.gd`; the Inventory type
  filter matches on `base_id` (`inventory_component.gd`); `verify_enchanting.gd`. Equipment needed
  no change — `GameCharacter.get_equipment_stats()` reads `get_item()`.
- Sell/buy price of a `+N` = the base item's (no decision; balance later).
- `ItemDatabase`: resolve `base+N` ids (name suffix, stat + N on `attack` for weapons, `defense`
  for armour), `enchant_level(id)`, `base_id(id)`.
- `Scripts/Crafting/enchanting_service.gd` (like `CraftingService`): `can_enchant(id, inv)`,
  `enchant(id, inv) -> String` (removes two, adds one at N+1, charges Q50's cost).
- Equipment: an equipped `x+1` shows and applies its raised stat.
- `SampleProject/UI/verify_enchanting.gd`.

### ✅ Slice 2 — the screen (built 2026-10-15)
- Built: `Scenes/Enchanting/enchanting_menu.tscn` + `Scripts/Crafting/enchanting_ui.gd` on the crafting
  frame (no station tabs, no categories); `modal_templates.enchant_confirm` / `cannot_enchant`;
  `Blacksmith` shows **Enchant** when the screen exists and opens Craft/Enchant through one
  `open_screen(path)` (`is_screen_open`, `screen_instance`). Shots: `shots/enchanting_list_1920.png`,
  `enchanting_confirm_1920.png`, `enchanting_error_1920.png` (`capture_enchanting.gd`).
- **Not compared with Figma `enchant-list`** — MCP was down. Do it when it is back; triage any
  difference (D / Q / B).
- Known: the description box shows the base item's text ("Attack: +10") for a `+N` too.
- `Scenes/Enchanting/enchanting_menu.tscn` from Figma `enchant-list` (or the crafting pattern);
  `Blacksmith.ENCHANT_ENABLED` removed, the entry shown when the screen exists (as Craft is).
- Capture + compare.

### Slice 3 — the Blacksmith's enchant quest — ✅ built 2026-10-15 (D175)
- Needs the side-quest Tasks system ([[npc_recall_plan]], D162 revised). The Blacksmith hands over
  **two identical items** (Sapega) → enchant → bring back the `+1`. Which item and the reward: ask.

## Order and dependencies

`1 → 2 → 3`; 3 also waits on the Tasks system.

## Out of scope for this pass

Jewellery and magic defense (no items), removing an enchantment, failure chance.
