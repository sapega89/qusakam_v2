extends Area2D
class_name RelicArmor

## 🛡️ RelicArmor - Интерактивный объект обладунков/реликвии
## Показывает диалог при взаимодействии (дія `interact`) рядом с объектом.
## Підказка — спільна UI/Interaction/Prompt (D74) через InteractableComponent.

@export var dialogue_id: String = "RelicArmor_Examine"
@export var action_text: String = "Examine"

var dialogue_played: bool = false
var interactable: InteractableComponent = null

func _ready() -> void:
	interactable = InteractableComponent.new()
	interactable.name = "Interactable"
	interactable.action_text = action_text
	add_child(interactable)
	interactable.interacted.connect(_interact_with_relic)

	# Добавляем в группу для поиска
	add_to_group("interactive_objects")

func _interact_with_relic() -> void:
	"""Взаимодействие с реликвией - запуск диалога"""
	if dialogue_id.is_empty():
		DebugLogger.warning("RelicArmor: dialogue_id не установлен", "RelicArmor")
		return

	DebugLogger.info("RelicArmor: Игрок взаимодействует с обладунками", "RelicArmor")

	# Запускаем диалог
	var dm = _get_dialogue_manager()
	if not dm:
		DebugLogger.error("RelicArmor: DialogueManager не найден", "RelicArmor")
		return

	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	dm.start_dialogue(path)

	dialogue_played = true

func _get_dialogue_manager() -> Node:
	"""Получает DialogueManager через ServiceLocator"""
	return ServiceLocator.get_dialogue_manager()
