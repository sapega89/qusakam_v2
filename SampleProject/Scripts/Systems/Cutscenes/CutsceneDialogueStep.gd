## Крок катсцени з діалогом
## Запускає діалог через DialogueManager
extends CutsceneStep
class_name CutsceneDialogueStep

## Шлях до діалогу (.dqd файл)
@export var dialogue_path: String = ""

## Посилання на DialogueManager
var dialogue_manager: Node = null

func _ready() -> void:
	super._ready()
	step_name = "DialogueStep"

## Кастомна логіка виконання
func _on_execute() -> void:
	if dialogue_path == "":
		push_warning("CutsceneDialogueStep: dialogue_path is empty")
		complete()
		return
	
	# Знаходимо DialogueManager
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_dialogue_manager"):
			dialogue_manager = service_locator.get_dialogue_manager()
	if not dialogue_manager:
		push_error("CutsceneDialogueStep: DialogueManager not found")
		complete()
		return
	
	# Запускаємо діалог
	if dialogue_manager.has_method("start_dialogue"):
		dialogue_manager.start_dialogue(dialogue_path)
		
		# Чекаємо на завершення діалогу
		if dialogue_manager.has_signal("dialogue_finished"):
			await dialogue_manager.dialogue_finished
		else:
			# Fallback: чекаємо фіксований час
			await get_tree().create_timer(5.0).timeout
	else:
		push_error("CutsceneDialogueStep: DialogueManager does not have start_dialogue method")
	
	complete()

## Скидає крок
func reset() -> void:
	super.reset()

