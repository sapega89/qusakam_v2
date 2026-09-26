# Equipment — data flow as it exists today

Recorded **before** any Phase 5.3 edit. Figma is the visual source of truth;
these systems are the behavioural source of truth.

## Slot set — authoritative, 11 slots

`PlayerStateManager.player_state.equipment` defines the only supported slots:

```
sword · polearm · dagger · axe · bow · staff · shield · head · body
accessory_1 · accessory_2
```

`CharacterManager._get_default_equipment_slots()` mirrors the same keys, and
`GameCharacter.equipment` is populated from them. Verified at runtime:
`char.equipment.keys()` returns exactly those 11.

**Figma's Equipment panel lists only 8** (Swords, Daggers, Bows, Shields, Head,
Body, Accessories ×2) — it omits polearm, axe and staff. The gameplay data wins
on *which slots exist*; Figma wins on *how a slot row looks*.

## Item → slot compatibility

Driven by `item_data.category` from `items.json`, not by a separate table:

| Slot | Accepts `category` |
|---|---|
| sword / polearm / dagger / axe / bow / staff / shield | same string as the slot id |
| head | `helmet`, `hat` |
| body | `armor`, `vest` |
| accessory_1 / accessory_2 | `accessory`, `ring` |

Only items whose `type` is `weapon` or `armor` are equippable.
Present in `items.json` today: `sword` ×3, `armor` ×2, `helmet` ×1, `shield` ×1.

## Stats

`StatCalculator` (static, `RefCounted`) owns **every** formula and takes
`(attributes: CharacterAttributes, equipment_stats: Dictionary)`.

`GameCharacter.get_equipment_stats()` sums `attack/defense/magic/strength/
intelligence/dexterity/constitution` across equipped items, reading each item's
`stats` block from `ItemDatabase`.

Since Phase 5.1, `GameManager.calculate_*()` are thin delegates that resolve the
active character and forward to `StatCalculator`. **No formula is duplicated.**

## The write path — two competing routes

### Route A — documented API (used by nothing until now)

```
EquipmentManager.equip_item(char_id, slot, item_id, item_data)
  └─ EventBus.equipment_equip_requested
       └─ CharacterManager._on_equipment_equip_requested
            ├─ character.equipment[slot] = {id, name, icon}
            ├─ character.update_equipment_bonuses()
            └─ EventBus.equipment_equipped
                 └─ EquipmentManager._on_equipment_equipped
                      └─ EquipmentManager.equipment_changed
```

### Route B — direct write (what the components actually did)

```
component writes game_manager.player_state.equipment[slot] = {...}
component writes game_manager.active_character.equipment[slot] = {...}
component calls active_character.update_equipment_bonuses()
```

## ⚠️ The defect this exposes

`PlayerDataModule` — the save module — persists **`player_state.equipment`**:

```gdscript
data["equipment"] = player_state.get("equipment", {}).duplicate()
```

`CharacterManager._on_equipment_equip_requested` updates `character.equipment`
but **never syncs `player_state`**. Confirmed at runtime:

```
equip_item("player_1", "sword", "iron_sword", …)
  char.equipment.sword         = { id: "iron_sword", … }   ← set
  player_state.equipment.sword = <null>                     ← NOT set
```

**Consequence: anything equipped through the documented API is lost on save.**
Route B persisted correctly only because it wrote `player_state` by hand.

`CharacterManager._sync_player_state_from_character()` already does exactly the
needed copy (`player_state.equipment = active_character.equipment.duplicate()`)
but is never called from the equip/unequip handlers.

**Phase 5.3 fix:** call that sync at the end of both handlers, guarded to the
active character. One place; makes Route A correct so the UI can stop
hand-writing `player_state`.

## Secondary defect (not fixed — out of scope)

`CharacterManager.initialize_characters()` line 50 calls
`game_manager.has("player_state")`. `Object` has no `has()` method in Godot 4
(`gm.has_method("has")` → `false`), so this line raises at runtime and the
`else` branch is never reachable as intended. Logged, not touched.

## Read path

| UI needs | Source |
|---|---|
| equipped item per slot | `EquipmentManager.get_equipped_item()` / `character.equipment` |
| item name, icon, stats | `ItemDatabase.get_item*()` |
| candidate items for a slot | `InventoryManager.get_items_dict()` filtered by category |
| derived stats | `GameManager.calculate_*()` → `StatCalculator` |
| refresh trigger | `EquipmentManager.equipment_changed`, `EventBus.equipment_equipped/unequipped` |

## Equipment-selection mode (must be preserved)

`InventoryComponent.set_equipment_selection_mode(enabled, slot_id, comp)`
filters the list to items whose category fits `slot_id`, then activation calls
`_equip_item()` and emits `request_tab("equipment")`.
