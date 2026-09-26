extends RefCounted
class_name InventorySlotRules

## Єдине правило сумісності «предмет ↔ слот екіпіровки».
##
## Слоти беруться з player_state.equipment (11 штук), сумісність — з поля
## category у items.json. Раніше цей match дублювався в InventoryComponent
## і EquipmentComponent; тепер джерело одне.
##
## Див. design/equipment_data_flow.md


## Чи можна вдягнути [code]item_data[/code] у слот [code]slot_id[/code].
static func fits(item_data: Dictionary, slot_id: String) -> bool:
	var item_type := String(item_data.get("type", ""))
	if item_type != "weapon" and item_type != "armor":
		return false

	var category := String(item_data.get("category", ""))
	match slot_id:
		"sword", "polearm", "dagger", "axe", "bow", "staff", "shield":
			return category == slot_id
		"head":
			return category == "helmet" or category == "hat"
		"body":
			return category == "armor" or category == "vest"
		"accessory_1", "accessory_2":
			return category == "accessory" or category == "ring"
	return false


## Слот, у який предмет піде за замовчуванням, або "" якщо не екіпірується.
## [code]accessory_1_taken[/code] дозволяє перекинути другу біжутерію в слот 2.
static func default_slot(item_data: Dictionary, accessory_1_taken: bool = false) -> String:
	var item_type := String(item_data.get("type", ""))
	if item_type != "weapon" and item_type != "armor":
		return ""

	match String(item_data.get("category", "")):
		"sword", "polearm", "dagger", "axe", "bow", "staff", "shield":
			return String(item_data.get("category", ""))
		"helmet", "hat":
			return "head"
		"armor", "vest":
			return "body"
		"accessory", "ring":
			return "accessory_2" if accessory_1_taken else "accessory_1"
	return ""
