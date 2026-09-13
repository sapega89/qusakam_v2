extends Node
class_name SceneQuestManager

## 🎮 SceneQuestManager - Менеджер квестів для сцени
## Відстежує прогрес проходження діалогів та етапів
## Автоматично визначає, коли гравець може перейти до інших сцен

@export_group("Configuration")
@export var quest_config: SceneQuestConfig  # Resource з налаштуваннями

@export_group("Debug")
@export var debug_mode: bool = false  # Додаткове логування

# Внутрішній стан
var completed_dialogues: Array[String] = []
var completed_stages: Array[String] = []
var current_stage_index: int = 0
var current_stage: QuestStageResource = null

# Сигнали
signal stage_completed(stage_id: String, stage_name: String)
signal all_stages_completed()
signal dialogue_completed(dialogue_id: String)
signal scene_unlocked(scene_name: String)
signal progress_updated(completed: int, total: int)

func _ready() -> void:
	"""Ініціалізація менеджера"""
	if not quest_config:
		DebugLogger.warning("SceneQuestManager: quest_config не встановлено!", "Quest")
		return
	
	# Підключення до EventBus для відстеження діалогів
	_connect_to_event_bus()
	
	# Ініціалізація поточного етапу
	_initialize_current_stage()
	
	# Відновлення прогресу зі збереження (якщо потрібно)
	_restore_progress()
	
	DebugLogger.info("SceneQuestManager: Ініціалізовано для сцени '%s' з %d етапами" % [
		quest_config.scene_name, quest_config.get_stage_count()
	], "Quest")

func _connect_to_event_bus() -> void:
	"""Підключення до EventBus для відстеження діалогів"""
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		if event_bus and event_bus.has_signal("dialogue_finished"):
			if not event_bus.dialogue_finished.is_connected(_on_dialogue_finished):
				event_bus.dialogue_finished.connect(_on_dialogue_finished)
				DebugLogger.info("SceneQuestManager: Підключено до EventBus.dialogue_finished", "Quest")
		else:
			DebugLogger.warning("SceneQuestManager: EventBus не має сигналу dialogue_finished", "Quest")
	else:
		DebugLogger.warning("SceneQuestManager: EventBus не знайдено", "Quest")

func _initialize_current_stage() -> void:
	"""Ініціалізація поточного етапу"""
	if not quest_config or quest_config.get_stage_count() == 0:
		return
	
	# Знаходимо перший незавершений етап
	for i in range(quest_config.get_stage_count()):
		var stage = quest_config.get_stage_by_index(i)
		if stage and not stage.stage_id in completed_stages:
			current_stage_index = i
			current_stage = stage
			DebugLogger.info("SceneQuestManager: Поточний етап: %s (%s)" % [
				stage.stage_name, stage.stage_id
			], "Quest")
			return
	
	# Всі етапи завершені
	current_stage = null
	current_stage_index = quest_config.get_stage_count()

func _restore_progress() -> void:
	"""Відновлення прогресу зі збереження (якщо потрібно)"""
	# TODO: Можна додати збереження/завантаження прогресу
	pass

func _on_dialogue_finished(dialogue_id: String) -> void:
	"""Обробник завершення діалогу"""
	if not quest_config or not current_stage:
		return
	
	# Нормалізуємо dialogue_id (видаляємо шлях та розширення)
	var normalized_id = _normalize_dialogue_id(dialogue_id)
	
	# Перевірка, чи це обов'язковий діалог
	if not _is_required_dialogue(normalized_id):
		if debug_mode:
			DebugLogger.info("SceneQuestManager: Діалог '%s' не є обов'язковим для поточного етапу" % normalized_id, "Quest")
		return
	
	# Додаємо до завершених діалогів
	if not normalized_id in completed_dialogues:
		completed_dialogues.append(normalized_id)
		dialogue_completed.emit(normalized_id)
		DebugLogger.info("SceneQuestManager: Діалог '%s' завершено" % normalized_id, "Quest")
	
	# Оновлюємо прогрес
	_update_progress()
	
	# Перевірка завершення поточного етапу
	if is_stage_complete(current_stage):
		_complete_current_stage()

func _normalize_dialogue_id(dialogue_id: String) -> String:
	"""Нормалізує ID діалогу (видаляє шлях та розширення)"""
	# Видаляємо шлях
	var id = dialogue_id.get_file()
	# Видаляємо розширення
	if id.ends_with(".dqd"):
		id = id.substr(0, id.length() - 4)
	return id

func _is_required_dialogue(dialogue_id: String) -> bool:
	"""Перевіряє, чи є діалог обов'язковим для поточного етапу"""
	if not current_stage:
		return false
	
	# Перевіряємо в поточному етапі
	if dialogue_id in current_stage.required_dialogues:
		return true
	
	# Якщо allow_progressive_unlock, перевіряємо в попередніх етапах
	if quest_config.allow_progressive_unlock:
		for i in range(current_stage_index + 1):
			var stage = quest_config.get_stage_by_index(i)
			if stage and dialogue_id in stage.required_dialogues:
				return true
	
	return false

func is_stage_complete(stage: QuestStageResource) -> bool:
	"""Перевіряє, чи всі діалоги з етапу завершені"""
	if not stage:
		return false
	
	# Перевірка квестових флагів
	var game = Game.get_singleton()
	if not stage.has_required_flags(game):
		return false
	
	# Перевірка діалогів
	for dialogue_id in stage.required_dialogues:
		if not dialogue_id in completed_dialogues:
			return false
	
	return true

func _complete_current_stage() -> void:
	"""Завершує поточний етап"""
	if not current_stage:
		return
	
	var stage_id = current_stage.stage_id
	var stage_name = current_stage.stage_name
	
	# Додаємо до завершених етапів
	if not stage_id in completed_stages:
		completed_stages.append(stage_id)
	
	# Емітуємо сигнал
	stage_completed.emit(stage_id, stage_name)
	DebugLogger.info("SceneQuestManager: Етап '%s' (%s) завершено!" % [stage_name, stage_id], "Quest")
	
	# Розблоковуємо доступні сцени
	for scene_name in current_stage.available_scenes:
		scene_unlocked.emit(scene_name)
		DebugLogger.info("SceneQuestManager: Сцена '%s' розблокована" % scene_name, "Quest")
	
	# Переходимо до наступного етапу
	_advance_to_next_stage()

func _advance_to_next_stage() -> void:
	"""Переходить до наступного етапу"""
	current_stage_index += 1
	
	if current_stage_index >= quest_config.get_stage_count():
		# Всі етапи завершені
		current_stage = null
		all_stages_completed.emit()
		DebugLogger.info("SceneQuestManager: Всі етапи завершені!", "Quest")
		return
	
	# Встановлюємо наступний етап
	current_stage = quest_config.get_stage_by_index(current_stage_index)
	if current_stage:
		DebugLogger.info("SceneQuestManager: Перехід до етапу: %s (%s)" % [
			current_stage.stage_name, current_stage.stage_id
		], "Quest")
	
	_update_progress()

func _update_progress() -> void:
	"""Оновлює прогрес та емітує сигнал"""
	if not quest_config:
		return
	
	var total_dialogues = quest_config.get_all_required_dialogues().size()
	var completed = completed_dialogues.size()
	
	progress_updated.emit(completed, total_dialogues)
	
	if debug_mode:
		DebugLogger.info("SceneQuestManager: Прогрес: %d/%d діалогів" % [completed, total_dialogues], "Quest")

func get_available_scenes() -> Array[String]:
	"""Повертає список доступних сцен для переходу"""
	var available: Array[String] = []
	
	if not quest_config:
		return available
	
	# Якщо require_all_stages, перевіряємо всі етапи
	if quest_config.require_all_stages:
		# Перевіряємо, чи всі етапи завершені
		if completed_stages.size() >= quest_config.get_stage_count():
			# Збираємо всі доступні сцени з усіх етапів
			for stage in quest_config.stages:
				if stage:
					for scene_name in stage.available_scenes:
						if not scene_name in available:
							available.append(scene_name)
	else:
		# Якщо allow_progressive_unlock, додаємо сцени з завершених етапів
		for i in range(completed_stages.size()):
			var stage = quest_config.get_stage_by_index(i)
			if stage:
				for scene_name in stage.available_scenes:
					if not scene_name in available:
						available.append(scene_name)
	
	return available

func get_current_stage() -> QuestStageResource:
	"""Повертає поточний етап"""
	return current_stage

func get_current_stage_index() -> int:
	"""Повертає індекс поточного етапу"""
	return current_stage_index

func get_completed_dialogues() -> Array[String]:
	"""Повертає список завершених діалогів"""
	return completed_dialogues.duplicate()

func get_completed_stages() -> Array[String]:
	"""Повертає список завершених етапів"""
	return completed_stages.duplicate()

func get_progress_percentage() -> float:
	"""Повертає відсоток завершення (0.0 - 1.0)"""
	if not quest_config:
		return 0.0
	
	var total_dialogues = quest_config.get_all_required_dialogues().size()
	if total_dialogues == 0:
		return 1.0
	
	return float(completed_dialogues.size()) / float(total_dialogues)

func can_transition_to_scene(scene_name: String) -> bool:
	"""Перевіряє, чи можна перейти до вказаної сцени"""
	var available = get_available_scenes()
	
	# Нормалізуємо назву сцени (видаляємо розширення)
	var normalized_scene = scene_name
	if normalized_scene.ends_with(".tscn"):
		normalized_scene = normalized_scene.substr(0, normalized_scene.length() - 5)
	
	# Перевіряємо в доступних сценах
	for available_scene in available:
		var normalized_available = available_scene
		if normalized_available.ends_with(".tscn"):
			normalized_available = normalized_available.substr(0, normalized_available.length() - 5)
		
		if normalized_available == normalized_scene:
			return true
	
	return false

func get_stage_progress(stage: QuestStageResource) -> Dictionary:
	"""Повертає прогрес конкретного етапу"""
	if not stage:
		return {"completed": 0, "total": 0, "percentage": 0.0}
	
	var completed = 0
	var total = stage.required_dialogues.size()
	
	for dialogue_id in stage.required_dialogues:
		if dialogue_id in completed_dialogues:
			completed += 1
	
	var percentage = 0.0
	if total > 0:
		percentage = float(completed) / float(total)
	
	return {
		"completed": completed,
		"total": total,
		"percentage": percentage
	}
