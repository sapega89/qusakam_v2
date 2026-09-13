extends Resource
class_name QuestStageResource

## 📋 QuestStageResource - Resource для налаштування етапу квесту
## Містить список обов'язкових діалогів та доступних сцен для переходу

@export_group("Stage Info")
@export var stage_name: String = ""  # Назва етапу (для відображення)
@export var stage_id: String = ""   # Унікальний ID етапу

@export_group("Required Content")
# Список обов'язкових діалогів для цього етапу
# Формат: ["DialogueID1", "DialogueID2"] (без розширення .dqd)
@export var required_dialogues: Array[String] = []

@export_group("Available Transitions")
# Список сцен, доступних для переходу після завершення етапу
# Формат: ["Canyon.tscn", "Village.tscn"] або ["Canyon", "Village"]
@export var available_scenes: Array[String] = []

@export_group("Optional Conditions")
# Опціональні умови (квестові флаги)
# Формат: {"flag_name": true, "another_flag": false}
@export var required_flags: Dictionary = {}

@export_group("Display")
# Опис етапу (для UI)
@export_multiline var description: String = ""

func _init():
	"""Ініціалізація за замовчуванням"""
	pass

func get_required_dialogues() -> Array[String]:
	"""Повертає список обов'язкових діалогів"""
	return required_dialogues.duplicate()

func get_available_scenes() -> Array[String]:
	"""Повертає список доступних сцен"""
	return available_scenes.duplicate()

func has_required_flags(game: Node) -> bool:
	"""Перевіряє, чи виконані всі необхідні квестові флаги"""
	if required_flags.is_empty():
		return true
	
	if not game or not game.has_method("get_quest_flag"):
		return false
	
	for flag_name in required_flags:
		var expected_value = required_flags[flag_name]
		var actual_value = game.get_quest_flag(flag_name, false)
		if actual_value != expected_value:
			return false
	
	return true
