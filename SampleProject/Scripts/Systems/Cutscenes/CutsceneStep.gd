## Базовий клас для кроків катсцени
## Реалізує ICutsceneStep інтерфейс
extends Node
class_name CutsceneStep

## Назва кроку
@export var step_name: String = ""

## Тривалість кроку (якщо автоматичний)
@export var duration: float = 0.0

## Чи можна пропустити цей крок
@export var can_skip: bool = true

## Чи завершено крок (внутрішня змінна)
var _step_complete: bool = false

## Сигнали
signal step_completed()
signal step_started()

func _ready() -> void:
	reset()

## Реалізація ICutsceneStep.execute()
func execute() -> bool:
	_step_complete = false
	step_started.emit()
	
	# Якщо є тривалість, автоматично завершуємо через неї
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		complete()
	else:
		# Інакше викликаємо _on_execute для кастомної логіки
		_on_execute()
	
	return true

## Реалізація ICutsceneStep.is_complete()
func is_complete() -> bool:
	return _step_complete

## Реалізація ICutsceneStep.reset()
func reset() -> void:
	_step_complete = false

## Кастомна логіка виконання (перевизначається в дочірніх класах)
func _on_execute() -> void:
	# За замовчуванням одразу завершуємо
	complete()

## Позначає крок як завершений
func complete() -> void:
	_step_complete = true
	step_completed.emit()

