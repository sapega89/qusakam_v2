## Тригер діалогу
## Висить на Area2D та викликає діалог при вході гравця
## Реалізує IDialogueTrigger
extends Area2D
class_name DialogueTrigger

## ID діалогу (наприклад, "p09_trader" або "p10_training")
@export var dialogue_id: String = ""

## Спрацьовувати тільки один раз
@export var trigger_once: bool = true

## Вимкнути після спрацювання
@export var disable_after_trigger: bool = true

## Чи вже спрацював
var triggered: bool = false

## Сигнал спрацювання тригера
signal dialogue_triggered(dialogue_id: String)

func _ready() -> void:
	# Додаємо до групи для пошуку
	add_to_group("dialogue_trigger")
	
	# Підключаємо сигнал body_entered
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

## Реалізація IDialogueTrigger.get_dialogue_id()
func get_dialogue_id() -> String:
	return dialogue_id

## Обробник входження тіла в область
func _on_body_entered(body: Node2D) -> void:
	if not body:
		return
	
	# Перевіряємо, чи це гравець
	if not body.is_in_group(GameGroups.PLAYER):
		return
	
	# Перевіряємо, чи вже спрацював
	if trigger_once and triggered:
		return
	
	# Перевіряємо наявність ID діалогу
	if dialogue_id == "":
		push_error("DialogueTrigger: dialogue_id не встановлено")
		return
	
	# Позначаємо як спрацьований
	triggered = true
	
	# Вимкнути область, якщо потрібно
	if disable_after_trigger:
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
	
	# Емітуємо сигнал
	dialogue_triggered.emit(dialogue_id)

