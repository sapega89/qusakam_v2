class_name ModalTemplates

static func confirm_exit() -> Dictionary:
	return {
		"title": "Exit Game?",
		"description": "Any unsaved progress will be lost.",
		"buttons": [
			{"id": "confirm", "text": "Exit", "is_default": true},
			{"id": "cancel", "text": "Cancel", "is_cancel": true}
		]
	}

static func unsaved_changes() -> Dictionary:
	return {
		"title": "Unsaved Changes",
		"description": "You have unsaved changes. Continue?",
		"buttons": [
			{"id": "confirm", "text": "Continue", "is_default": true},
			{"id": "cancel", "text": "Back", "is_cancel": true}
		]
	}

static func reset_settings() -> Dictionary:
	return {
		"title": "Reset Settings",
		"description": "Reset all settings to defaults?",
		"buttons": [
			{"id": "confirm", "text": "Reset", "is_default": true},
			{"id": "cancel", "text": "Cancel", "is_cancel": true}
		]
	}

static func delete_save() -> Dictionary:
	return {
		"title": "Delete Save",
		"description": "This will permanently delete the save slot.",
		"buttons": [
			{"id": "confirm", "text": "Delete", "is_default": true},
			{"id": "cancel", "text": "Cancel", "is_cancel": true}
		]
	}

## Figma UI/Save Screen Modal 258:5162 → UI/Modal/Confirm. Лише режим SAVE (D78).
static func overwrite_save() -> Dictionary:
	return {
		"title": "Overwrite Save?",
		"description": "This will replace the existing save data.",
		"buttons": [
			{"id": "confirm", "text": "Yes", "is_default": true},
			{"id": "cancel", "text": "No", "is_cancel": true}
		]
	}

## Figma shop-buy-confirm 153:1760: "Buy Circlet?" / "Quantity: 4  •  Total Cost: ₹ 4,200".
static func buy_confirm(item_name: String, quantity: int, total: String) -> Dictionary:
	return {
		"title": "Buy %s?" % item_name,
		"description": "Quantity: ◀ %d ▶  •  Total Cost: %s" % [quantity, total],
		"buttons": [
			{"id": "confirm", "text": "Yes", "is_default": true},
			{"id": "cancel", "text": "No", "is_cancel": true}
		]
	}

## Figma 164:2545: "Craft Iron Sword?" — під заголовком матеріали й ціна через " • ".
static func craft_confirm(item_name: String, materials: PackedStringArray, cost: String) -> Dictionary:
	var parts := materials.duplicate()
	parts.append(cost)
	return {
		"title": "Craft %s?" % item_name,
		"description": "  •  ".join(parts),
		"buttons": [
			{"id": "confirm", "text": "Yes", "is_default": true},
			{"id": "cancel", "text": "No", "is_cancel": true}
		]
	}

## Figma UI/Craft Error Modal (217:2983): "Cannot Craft" / причина / CLOSE.
static func cannot_craft(reason: String) -> Dictionary:
	return misc_popup("Cannot Craft", reason, "Close")

## Зачарування (D94, D163) — та сама родина, що й крафт; Figma enchant-list не звірено (MCP).
static func enchant_confirm(item_name: String, result_name: String, cost: String) -> Dictionary:
	return {
		"title": "Enchant %s?" % item_name,
		"description": "%s ×2 → %s  •  %s" % [item_name, result_name, cost],
		"buttons": [
			{"id": "confirm", "text": "Yes", "is_default": true},
			{"id": "cancel", "text": "No", "is_cancel": true}
		]
	}

static func cannot_enchant(reason: String) -> Dictionary:
	return misc_popup("Cannot Enchant", reason, "Close")

## D76: похідна від модалки перезапису — та сама родина, одна дія.
static func game_saved() -> Dictionary:
	return misc_popup("Game Saved", "Your progress has been saved successfully.")

## D79: помилка збереження — та сама родина модалок, окремий стан.
static func save_failed() -> Dictionary:
	return misc_popup("Save Failed", "Your progress could not be saved. Please try again.")

## Figma UI/Modal/ItemPickup (222:4880): "You obtained:" / "<Item> × <N>" (D71).
static func item_pickup(item_name: String, amount: int) -> Dictionary:
	return misc_popup("You obtained:", "%s × %d" % [item_name, amount])

static func misc_popup(title: String, description: String, ok_text: String = "OK") -> Dictionary:
	return {
		"title": title,
		"description": description,
		"buttons": [
			{"id": "confirm", "text": ok_text, "is_default": true}
		]
	}

## D127: випити зілля — та сама родина модалок, що й купівля.
static func use_item(item_name: String, character_name: String, hp_from: int, hp_to: int, hp_max: int) -> Dictionary:
	return {
		"title": "Use %s?" % item_name,
		"description": "%s  •  HP %d → %d / %d" % [character_name, hp_from, hp_to, hp_max],
		"buttons": [
			{"id": "confirm", "text": "Use", "is_default": true},
			{"id": "cancel", "text": "Cancel", "is_cancel": true}
		]
	}


static func confirm_exit_to_main_menu() -> Dictionary:
	return {
		"title": "Exit to Main Menu?",
		"description": "Unsaved progress will be lost.",
		"buttons": [
			{"id": "confirm", "text": "Exit", "is_default": true},
			{"id": "cancel", "text": "Cancel", "is_cancel": true}
		]
	}

static func confirm_exit_game_unsaved() -> Dictionary:
	return {
		"title": "Exit Game?",
		"description": "Unsaved progress will be lost.",
		"buttons": [
			{"id": "confirm", "text": "Exit", "is_default": true},
			{"id": "cancel", "text": "Cancel", "is_cancel": true}
		]
	}
