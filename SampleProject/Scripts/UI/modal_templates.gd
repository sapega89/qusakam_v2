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
		"description": "Quantity: %d  •  Total Cost: %s" % [quantity, total],
		"buttons": [
			{"id": "confirm", "text": "Yes", "is_default": true},
			{"id": "cancel", "text": "No", "is_cancel": true}
		]
	}

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
