---
type: mapping
status: in-progress
figma: "menu-inventory 46:193 · UI/Equipment Panel 258:5110 · UI/Party Status Panel 104:490 · menu-tutorial 130:1172 · tutorial-content 135:1260 · journal-main-story 192:1529 · journal-character-detail 192:1754"
tags: [game-menu, feedback-queue]
---

# Game Menu batch (BACKLOG 9–13) — Figma → Godot

Sapega's play feedback items 9–13 ([[BACKLOG]] → "Sapega's play feedback 2026-10-20", [[play_feedback_queue]]).
Decisions D286–D290 in [[figma_decision_register]] — all agent calls, Sapega to confirm.

**Figma access:** the Figma MCP was not reachable from the agent that built this batch, so the frames were not
re-read; the visual reference is the shipped look of each screen (already matched to these frames by
[[inventory_diff_plan]], [[equipment_data_flow]], [[tutorial_mapping]], [[journal_audit]]) and
`design/shots/*_1920.png`. Nothing below adds a colour, size or font outside `UITokens` / `GameUITheme`.

## 9 · Inventory actions — D286

Figma: `menu-inventory` 46:193 — the row list has no action buttons and no "use" frame. Godot:
`Scenes/Menus/Game/inventory_component.tscn` + `Scripts/Menus/Game/inventory_component.gd`.

| Figma layer | Godot node | Action |
|---|---|---|
| UI/ListRow | `UIItemRow` (`UI/Components/item_row.tscn`) | reuse; `row_activated` = double click / Enter / pad A |
| — (no frame) | `ModalLayer` + `modal_dialog.tscn` via `ModalTemplates.cannot_use()` | reuse the shared modal family (same as Cannot Craft) |
| bottom bar hint | `BottomBar.set_context_hint()` | reuse for the result line ("Iron Sword equipped — Sword.", "Potion — HP 80 / 100.") |

Behaviour (D286): a healing consumable heals Kusakam at once, an ether restores SP at once, one item spent — no
party choice, no confirmation (D127's target choice and `ModalTemplates.use_item` are gone; at full HP / full SP
the item is kept and the bar says so). A weapon / armour / helmet / shield / accessory equips into
`InventorySlotRules.default_slot()` through `EquipmentManager.equip_item()` (the same EventBus path as the
Equipment screen). Anything else (materials, key items) opens **"Cannot Use" / "<Item> cannot be used." / OK**.
Single-button info popups now also close on B / Esc (`misc_popup` button is the cancel button too).

Preserved: `InventoryManager.inventory_changed`, `EventBus.equipment_equipped`, the filter cycle (D9), the
bottom-bar description. Removed with D127: party-card target selection (`character_chosen`,
`begin_target_select`, the card `Select` button) — nothing else used it.

Verify: `verify_use_item.gd` (keys, double click, pad A/B).

## 11 · Equipment slot picker — D288

Figma: `UI/Equipment Panel` 258:5110 (slot rows) — no picker frame. Godot: `equipment_component.gd` +
new `UI/Components/equip_picker.tscn/.gd`, shown through `ModalLayer.show_custom_modal()` (as the crafting
`RecipePanel`).

| Element | Godot | Action |
|---|---|---|
| window | `EquipPicker/Window` — `WindowPanel`, `ShopColumn`, `TitleLabel`, `AccentLabel`, `MutedLabel` | reuse the RecipePanel look |
| item list | `UIItemRow` (`item_row.tscn`) | reuse; subtitle "Equipped" on the worn item |
| Unequip / Cancel | theme `Button` | ADD; Unequip only when the slot is filled |

Behaviour (D288): a click / Enter / pad A on a slot row opens the window with the bag items that
`InventorySlotRules.fits()` that slot; a click, Enter / A or a double click on a row equips it through
`EquipmentManager.equip_item()`; Unequip empties the slot; Cancel / B / Esc closes without change. Focus returns
to the slot row. Replaces the old jump to the Inventory tab in "selection mode" (removed from
`inventory_component.gd`). Verify: `verify_equip_picker.gd`.
