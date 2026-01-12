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

static func overwrite_save() -> Dictionary:
	return {
		"title": "Overwrite Save",
		"description": "Overwrite the existing save slot?",
		"buttons": [
			{"id": "confirm", "text": "Overwrite", "is_default": true},
			{"id": "cancel", "text": "Cancel", "is_cancel": true}
		]
	}

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
