---
type: mapping
status: done
figma: "crafting-list 160:1291 · recipe 164:2326 · confirm 164:2545 · error 164:2764 · UI/Recipe Confirmation Panel 217:2189 · UI/Craft Error Modal 217:2983"
---

# Crafting — Figma → Godot mapping

Slice 4 of [[runtime_ui_completion_plan]]. Decisions: D85 (materials + gold), D96 (delete
`ForgeSystem`), D97 (mock gold cost), D101 (normal party panel), D103 (no Equipment tab),
D108 (four station tabs), D115 (Blacksmith menu = Craft + Enchant). 2026-10-13.

## Flow (Figma)

list (160:1291) → row A → **recipe panel** (164:2326: required materials ✓ have/need, expected
result stats) → A → **"Craft Iron Sword?"** YES/NO (164:2545, materials listed) → craft, or
**"Cannot Craft — Not enough materials. You are missing: X ×n"** (164:2764).

## Mapping

| Figma | Godot | Note |
|---|---|---|
| whole frame | `Scenes/Crafting/crafting_menu.tscn` (path the Blacksmith already opens) | same skeleton as `shop_menu.tscn`: `base_menu` + sidebar + `ShopPanel` |
| left column `CRAFT` + Weapon/Armor/Accessory/Equipment | title `CRAFT` + **Furnace / Workbench / Anvil / Alchemy** `SidebarTab`s | **D108** replaces the categories with stations (undesigned tab strip); D103 drops Equipment |
| Category Filters Column (ALL + icons) | `ShopService.CATEGORIES` buttons, filtering by the **result** item | reused as in the shop (D102) |
| "Available Recipes" | `%Title` (`ShopTitle`) | |
| header `Item Name & Materials · On Hand · Crafting Cost` | `ShopColumnHeader` labels | |
| recipe row (name + "Requires: …", on hand, cost) | `shop_row.tscn` + new `%DetailLabel` (`ShopRowDetail`, 13 px) | one row component for shop and craft; hidden in the shop |
| Item Detail Plate | `%DescBox` | result item's description |
| UI/Party Equipment Effects (right) | normal party panel from `base_menu` | **D101**, same call as the shop |
| UI/Recipe Confirmation Panel 217:2189 | `UI/Components/recipe_panel.tscn` via `ModalLayer.show_custom_modal` | stats from item `stats` (attack/defense/magic) or `effect` (heal) |
| confirm "Craft X?" YES/NO | shared modal family, `modal_templates.craft_confirm()` | shown **instead of** the panel, not over it — one modal at a time in `ModalLayer` |
| Craft Error Modal 217:2983 | shared modal family, `modal_templates.cannot_craft()` | "Not enough gold" uses the same modal (Figma has no gold state) |
| Bottom Bar | `base_menu` bottom bar, hints as in the shop | |

## Data

`crafting_recipes.json` gets `gold_cost` per recipe — **mock values (D97)**: 10 % of the
result's `buy_price` × result quantity, rounded, at least 1. Balancing later.

## Logic

`Scripts/Crafting/crafting_service.gd` (`CraftingService`, RefCounted, like `ShopService`):
recipes per station, have/need per ingredient, `craft()` → OK / NOT_ENOUGH_MATERIALS /
NOT_ENOUGH_GOLD. Consumes materials and gold, adds the result. `ForgeSystem.gd` deleted (D96).
Test: `UI/verify_crafting.gd`.

## Deviations (triaged)

- Station tabs instead of Figma categories — **D108**.
- Confirm replaces the recipe panel rather than stacking on it — single-modal `ModalLayer`.
- Placeholder recipe/item names in Figma ("Leather Strip", "Forge Fuel") — real data wins.

## Verified 2026-10-13

`verify_crafting.gd` ALL PASS; shots `design/shots/crafting_{list,recipe,confirm,error}_1920.png`
(`capture_crafting.gd`). Compared with Figma: recipe panel now lists **need / have** with a
green ✓ (`STATUS_INCREASE`, Figma `status/increase`). Known, not new: item icons are placeholder
squares (icon files missing, same in the shop); the shared modal family's styling — B27, B34.
