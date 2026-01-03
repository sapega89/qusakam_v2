## Менеджер катсцен
## Керує виконанням катсцен та переходами між кроками
extends Node
class_name CutsceneManager

## Поточна катсцена
var current_cutscene: Array[Node] = []

## Поточний індекс кроку
var current_step_index: int = 0

## Чи виконується катсцена зараз
var is_playing: bool = false

## Чи можна пропустити катсцену
var can_skip: bool = true

## Сигнали
signal cutscene_started(cutscene_name: String)
signal cutscene_finished(cutscene_name: String)
signal step_started(step: Node)
signal step_finished(step: Node)

func _ready() -> void:
	print("🎬 CutsceneManager: Initialized")

## Запускає катсцену
func play_cutscene(steps: Array[Node], cutscene_name: String = "") -> void:
	if is_playing:
		push_warning("CutsceneManager: Cutscene already playing, stopping current one")
		stop_cutscene()
	
	# Convert Array[Node] to Array[ICutsceneStep]
	current_cutscene.clear()
	for step in steps:
		if step is Node:
			current_cutscene.append(step)
	current_step_index = 0
	is_playing = true
	
	cutscene_started.emit(cutscene_name)
	print("🎬 CutsceneManager: Starting cutscene: ", cutscene_name)
	
	_execute_next_step()

## Виконує наступний крок
func _execute_next_step() -> void:
	if current_step_index >= current_cutscene.size():
		_finish_cutscene()
		return
	
	var step = current_cutscene[current_step_index]
	if not step or not is_instance_valid(step):
		push_warning("CutsceneManager: Invalid step at index ", current_step_index)
		current_step_index += 1
		_execute_next_step()
		return
	
	step_started.emit(step)
	print("🎬 CutsceneManager: Executing step ", current_step_index + 1, " of ", current_cutscene.size())
	
	# Виконуємо крок (якщо має метод execute)
	if step.has_method("execute"):
		await step.execute()
	
	# Чекаємо, поки крок завершиться
	await _wait_for_step_completion(step)
	
	step_finished.emit(step)
	current_step_index += 1
	
	# Переходимо до наступного кроку
	_execute_next_step()

## Чекає завершення кроку
func _wait_for_step_completion(step: Node) -> void:
	# Перевіряємо, чи крок має сигнал завершення
	if step.has_signal("step_completed"):
		await step.step_completed
		return
	
	# Інакше перевіряємо через is_complete
	if step.has_method("is_complete"):
		while not step.is_complete():
			await get_tree().process_frame
	else:
		# Fallback: чекаємо один кадр
		await get_tree().process_frame

## Завершує катсцену
func _finish_cutscene() -> void:
	is_playing = false
	var cutscene_name = "unnamed"
	if current_cutscene.size() > 0 and current_cutscene[0] and current_cutscene[0].has_method("get_cutscene_name"):
		cutscene_name = current_cutscene[0].get_cutscene_name()
	
	cutscene_finished.emit(cutscene_name)
	print("🎬 CutsceneManager: Cutscene finished: ", cutscene_name)
	
	# Очищаємо
	current_cutscene.clear()
	current_step_index = 0

## Зупиняє катсцену
func stop_cutscene() -> void:
	if not is_playing:
		return
	
	# Скидаємо всі кроки
	for step in current_cutscene:
		if step and is_instance_valid(step):
			if step.has_method("reset"):
				step.reset()
	
	_finish_cutscene()

## Пропускає поточний крок
func skip_current_step() -> void:
	if not is_playing or not can_skip:
		return
	
	if current_step_index < current_cutscene.size():
		var step = current_cutscene[current_step_index]
		if step and is_instance_valid(step):
			if step.has_method("reset"):
				step.reset()
	
	current_step_index += 1
	_execute_next_step()

## Перевіряє, чи виконується катсцена
func is_cutscene_playing() -> bool:
	return is_playing

