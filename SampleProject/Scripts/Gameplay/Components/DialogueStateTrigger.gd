extends Area2D
class_name DialogueStateTrigger

## 💬 DialogueStateTrigger - Спеціалізований тригер для інтеграції діалогів зі стейтами
## Запускає діалог і автоматично змінює стейт сцени після завершення діалогу
## Використовується в сценах як компонент

@export_group("Dialogue")
## ID діалогу для запуску
@export var dialogue_id: String = ""

## Шлях до файлу .dqd (якщо не вказано dialogue_id)
@export var dialogue_path: String = ""

@export_group("State Change")
## Назва стейту для переходу після завершення діалогу
@export var target_state: String = ""

## Потрібна назва поточного стейту ("" = будь-який)
@export var require_state: String = ""

@export_group("Settings")
## Спрацьовує один раз
@export var one_shot: bool = true

## Затримка перед зміною стейту (в секундах)
@export var state_change_delay: float = 0.0

var has_triggered: bool = false
var _is_dialogue_active: bool = false

# Статический флаг для отслеживания показанных предупреждений (на уровне класса)
static var _collision_shape_warning_shown: bool = false

func _ready() -> void:
	"""Налаштування виявлення зіткнень"""
	# Перевіряємо, чи не підключений сигнал вже (щоб уникнути помилки при повторному виклику _ready)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Перевіряємо наявність CollisionShape2D
	# Використовуємо info замість warning, оскільки це може бути нормально в деяких випадках
	if not get_node_or_null("CollisionShape2D"):
		# Показуємо тільки один раз через статичний флаг
		if not _collision_shape_warning_shown:
			DebugLogger.info("💬 DialogueStateTrigger: CollisionShape2D не знайдено (може бути нормально в тестах)", "DialogueStateTrigger")
			_collision_shape_warning_shown = true
	
	# Підключаємося до EventBus для відстеження діалогів
	if Engine.has_singleton("EventBus"):
		# Перевіряємо, чи не підключений сигнал вже
		if not EventBus.dialogue_finished.is_connected(_on_dialogue_finished):
			EventBus.dialogue_finished.connect(_on_dialogue_finished)

func _on_body_entered(body: Node2D) -> void:
	"""Гравець увійшов у зону"""
	if has_triggered and one_shot:
		DebugLogger.info("💬 DialogueStateTrigger: Тригер вже спрацював (one_shot=true), ігноруємо", "DialogueStateTrigger")
		return
	
	# Перевіряємо, чи це гравець
	if not body.is_in_group(GameGroups.PLAYER):
		DebugLogger.info("💬 DialogueStateTrigger: Об'єкт не є гравцем, ігноруємо", "DialogueStateTrigger")
		return
	
	# Перевіряємо потрібний стейт (якщо вказано)
	if not require_state.is_empty():
		var current_state_name = _get_current_state_name()
		if current_state_name != require_state:
			DebugLogger.info("💬 DialogueStateTrigger: Поточний стейт (%s) не відповідає вимогам (%s), ігноруємо" % [current_state_name, require_state], "DialogueStateTrigger")
			return
	
	has_triggered = true
	DebugLogger.info("💬 DialogueStateTrigger: ТРИГЕР СПРАЦЮВАВ! Діалог: %s, Цільовий стейт: %s" % [
		dialogue_id if not dialogue_id.is_empty() else dialogue_path,
		target_state if not target_state.is_empty() else "NONE"
	], "DialogueStateTrigger")
	
	# Запускаємо діалог
	_trigger_dialogue()

func _trigger_dialogue() -> void:
	"""Запускає діалог через DialogueManager"""
	if dialogue_id.is_empty() and dialogue_path.is_empty():
		DebugLogger.warning("💬 DialogueStateTrigger: Діалог не вказано!", "DialogueStateTrigger")
		return
	
	# Отримуємо DialogueManager
	var dm = await _get_dialogue_manager()
	if not dm:
		DebugLogger.warning("💬 DialogueStateTrigger: ❌ DialogueManager не знайдено!", "DialogueStateTrigger")
		return
	
	# Визначаємо шлях до діалогу
	var path = _resolve_dialogue_path()
	if path.is_empty():
		DebugLogger.warning("💬 DialogueStateTrigger: ❌ Не вдалося знайти файл діалогу!", "DialogueStateTrigger")
		return
	
	DebugLogger.info("💬 DialogueStateTrigger: Запускаємо діалог: %s" % path, "DialogueStateTrigger")
	
	# Запускаємо діалог
	if dm.has_method("start_dialogue"):
		var result = await dm.start_dialogue(path)
		if result:
			_is_dialogue_active = true
			DebugLogger.info("💬 DialogueStateTrigger: ✅ Діалог успішно запущено: %s" % path, "DialogueStateTrigger")
		else:
			DebugLogger.warning("💬 DialogueStateTrigger: ❌ Не вдалося запустити діалог: %s" % path, "DialogueStateTrigger")
	else:
		DebugLogger.warning("💬 DialogueStateTrigger: ❌ DialogueManager не має методу start_dialogue", "DialogueStateTrigger")

func _on_dialogue_finished(dialogue_id: String) -> void:
	"""Обробник завершення діалогу"""
	if not _is_dialogue_active:
		return
	
	# Перевіряємо, чи це наш діалог
	var expected_path = _resolve_dialogue_path()
	if not dialogue_id.contains(expected_path.get_file()) and not expected_path.contains(dialogue_id):
		return
	
	_is_dialogue_active = false
	DebugLogger.info("💬 DialogueStateTrigger: Діалог завершено, змінюємо стейт на: %s" % target_state, "DialogueStateTrigger")
	
	# Змінюємо стейт після затримки (якщо вказано)
	if state_change_delay > 0.0:
		await get_tree().create_timer(state_change_delay).timeout
	
	_trigger_state_change()

func _trigger_state_change() -> void:
	"""Змінює стейт сцени"""
	if target_state.is_empty():
		DebugLogger.info("💬 DialogueStateTrigger: target_state порожня, пропускаємо зміну стейту", "DialogueStateTrigger")
		return
	
	# Знаходимо стейт-менеджер в сцені
	var state_manager = null
	
	# Сначала пробуем через current_scene
	var tree = get_tree()
	if tree and tree.current_scene:
		var scene_to_search = tree.current_scene
		# Если current_scene сам является стейт-менеджером, используем его
		if ISceneStateManager.is_implemented_by(scene_to_search):
			state_manager = scene_to_search
		else:
			# Иначе ищем стейт-менеджер в сцене
			state_manager = ISceneStateManager.find_state_manager_in_scene(scene_to_search)
	
	# Если не нашли через current_scene, ищем через родителя
	if not state_manager:
		var parent = get_parent()
		while parent:
			# Проверяем, является ли родитель стейт-менеджером
			if ISceneStateManager.is_implemented_by(parent):
				state_manager = parent
				break
			# Или это сцена/узел, в которой может быть стейт-менеджер
			# Ищем стейт-менеджер в родителе и его детях
			var found_manager = ISceneStateManager.find_state_manager_in_scene(parent)
			if found_manager:
				state_manager = found_manager
				break
			parent = parent.get_parent()
	
	if not state_manager:
		DebugLogger.warning("💬 DialogueStateTrigger: Стейт-менеджер не знайдено в сцені!", "DialogueStateTrigger")
		return
	
	# Змінюємо стейт
	ISceneStateManager.safe_change_state_by_name(state_manager, target_state)
	DebugLogger.info("💬 DialogueStateTrigger: ✅ Стейт успішно змінено на %s" % target_state, "DialogueStateTrigger")

func _get_current_state_name() -> String:
	"""Отримує назву поточного стейту"""
	var state_manager = null
	
	# Сначала пробуем через current_scene
	var tree = get_tree()
	if tree and tree.current_scene:
		var scene_to_search = tree.current_scene
		# Если scene_to_search сам является стейт-менеджером, используем его
		if ISceneStateManager.is_implemented_by(scene_to_search):
			state_manager = scene_to_search
		else:
			# Иначе ищем стейт-менеджер в сцене
			state_manager = ISceneStateManager.find_state_manager_in_scene(scene_to_search)
	
	# Если current_scene недоступен или не нашли, ищем через родителя
	if not state_manager:
		var parent = get_parent()
		while parent:
			# Проверяем, является ли родитель стейт-менеджером
			if ISceneStateManager.is_implemented_by(parent):
				state_manager = parent
				break
			# Или это сцена/узел, в которой может быть стейт-менеджер
			# Ищем стейт-менеджер в родителе и его детях
			var found_manager = ISceneStateManager.find_state_manager_in_scene(parent)
			if found_manager:
				state_manager = found_manager
				break
			parent = parent.get_parent()
	
	if state_manager:
		return ISceneStateManager.safe_get_current_state_name(state_manager)
	return "UNKNOWN"

func _resolve_dialogue_path() -> String:
	"""Визначає шлях до діалогу"""
	if not dialogue_path.is_empty():
		# Використовуємо повний шлях, якщо вказано
		var path = dialogue_path
		if not path.begins_with("res://"):
			path = "res://dialogue_quest/" + path
		return path
	
	if dialogue_id.is_empty():
		return ""
	
	# Спробуємо кілька варіантів шляху
	var possible_paths = [
		"res://dialogue_quest/" + dialogue_id + ".dqd",
		"res://dialogue_quest/dialogues/" + dialogue_id + ".dqd",
		"res://dialogue_quest/" + dialogue_id + ".dqd"
	]
	
	# Знаходимо існуючий файл
	for test_path in possible_paths:
		if ResourceLoader.exists(test_path) or FileAccess.file_exists(test_path):
			return test_path
	
	# Якщо не знайшли, використовуємо стандартний шлях
	return "res://dialogue_quest/" + dialogue_id + ".dqd"

func _get_dialogue_manager() -> Node:
	"""Отримує DialogueManager через ServiceLocator"""
	if not ServiceLocator:
		DebugLogger.warning("💬 DialogueStateTrigger: ❌ ServiceLocator не доступний (autoload)", "DialogueStateTrigger")
		return null
	
	# Чекаємо готовності ServiceLocator
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	
	if ServiceLocator.has_method("get_dialogue_manager"):
		var dm = ServiceLocator.get_dialogue_manager()
		if dm:
			return dm
		else:
			DebugLogger.warning("💬 DialogueStateTrigger: ❌ DialogueManager повернув null", "DialogueStateTrigger")
	else:
		DebugLogger.warning("💬 DialogueStateTrigger: ❌ ServiceLocator не має методу get_dialogue_manager", "DialogueStateTrigger")
	
	return null

func reset() -> void:
	"""Скидання тригера (для тестування/відлагодження)"""
	has_triggered = false
	_is_dialogue_active = false
