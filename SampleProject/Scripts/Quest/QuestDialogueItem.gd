extends Control
class_name QuestDialogueItem

## 📝 QuestDialogueItem - Елемент списку діалогів у QuestProgressUI

@onready var dialogue_label: Label = $HBoxContainer/DialogueLabel
@onready var status_icon: TextureRect = $HBoxContainer/StatusIcon

var dialogue_id: String = ""
var is_completed: bool = false

func _ready() -> void:
	"""Ініціалізація"""
	update_display()

func set_dialogue_id(id: String) -> void:
	"""Встановлює ID діалогу"""
	dialogue_id = id
	update_display()

func set_completed(completed: bool) -> void:
	"""Встановлює стан завершення"""
	is_completed = completed
	update_display()

func update_display() -> void:
	"""Оновлює відображення"""
	if dialogue_label:
		if is_completed:
			dialogue_label.text = "✓ %s" % dialogue_id
			dialogue_label.modulate = Color(0.5, 1.0, 0.5)  # Зелений колір
		else:
			dialogue_label.text = "○ %s" % dialogue_id
			dialogue_label.modulate = Color.WHITE
	
	if status_icon:
		status_icon.visible = is_completed
		if is_completed:
			status_icon.modulate = Color(0.5, 1.0, 0.5)  # Зелений колір
