extends Area2D
class_name StateChangeTrigger

## 🔄 StateChangeTrigger - Универсальный триггер для смены состояния и запуска диалогов
## Можно вставлять в любую точку сцены для смены состояния или запуска диалога

# Enum состояний Canyon (должен совпадать с Canyon.gd)
enum CanyonState {
	NONE,  # Не менять состояние
	INTRO,
	MONOLOGUE,
	EXPLORATION,
	CUTSCENE_ABDUCTION,
	TO_VILLAGE,
	RELIC_PICKUP,
	EXIT_CUTSCENE,
	TO_DESERT_ROAD
}

@export_group("State Change")
@export var target_state: CanyonState = CanyonState.NONE  # Состояние для перехода
@export var require_state: CanyonState = CanyonState.NONE  # Требуемое текущее состояние (NONE = любое)

@export_group("Dialogue")
@export var dialogue_id: String = ""  # ID диалога для запуска (например, "Canyon_Intro")
@export var dialogue_path: String = ""  # Полный путь к .dqd файлу (если указан, используется вместо dialogue_id)

@export_group("Settings")
@export var one_shot: bool = true  # Срабатывает только один раз
@export var action_mode: ActionMode = ActionMode.BOTH  # Что делать: состояние, диалог или оба

enum ActionMode {
	STATE_ONLY,  # Только смена состояния
	DIALOGUE_ONLY,  # Только запуск диалога
	BOTH  # И состояние, и диалог
}

var has_triggered: bool = false

func _ready() -> void:
	"""Настройка обнаружения столкновений"""
	body_entered.connect(_on_body_entered)
	
	# Если нет CollisionShape2D, создаем предупреждение
	if not get_node_or_null("CollisionShape2D"):
		DebugLogger.warning("StateChangeTrigger: CollisionShape2D не найден! Добавьте CollisionShape2D к этому Area2D", "StateChangeTrigger")

func _on_body_entered(body: Node2D) -> void:
	"""Игрок вошел в зону"""
	if has_triggered and one_shot:
		return

	# Проверяем, что это игрок
	if not body.is_in_group(GameGroups.PLAYER):
		return

	# Проверяем требуемое состояние (если указано)
	if require_state != CanyonState.NONE:
		if not _check_current_state(require_state):
			return

	has_triggered = true
	
	# Выполняем действия в зависимости от режима
	match action_mode:
		ActionMode.STATE_ONLY:
			_trigger_state_change()
		ActionMode.DIALOGUE_ONLY:
			_trigger_dialogue()
		ActionMode.BOTH:
			_trigger_state_change()
			_trigger_dialogue()

func _check_current_state(required_state: CanyonState) -> bool:
	"""Проверяет текущее состояние Canyon"""
	if required_state == CanyonState.NONE:
		return true
	
	var canyon_scene = get_tree().current_scene
	if not canyon_scene or not canyon_scene.has_method("get_current_state_name"):
		return false
	
	var current_state_name = canyon_scene.get_current_state_name()
	var required_state_name = CanyonState.keys()[required_state]
	return current_state_name == required_state_name

func _trigger_state_change() -> void:
	"""Вызывает смену состояния через Canyon scene manager"""
	if target_state == CanyonState.NONE:
		return
	
	var canyon_scene = get_tree().current_scene
	if canyon_scene and canyon_scene.has_method("change_state_by_name"):
		var state_name = CanyonState.keys()[target_state]
		canyon_scene.change_state_by_name(state_name)
		DebugLogger.info("StateChangeTrigger: Изменение состояния на %s" % state_name, "StateChangeTrigger")
	else:
		DebugLogger.warning("StateChangeTrigger: Canyon scene manager не найден или не имеет метода change_state_by_name", "StateChangeTrigger")

func _trigger_dialogue() -> void:
	"""Запускает диалог через DialogueManager"""
	if dialogue_id.is_empty() and dialogue_path.is_empty():
		return
	
	# Получаем DialogueManager
	var dm = _get_dialogue_manager()
	if not dm:
		DebugLogger.warning("StateChangeTrigger: DialogueManager не найден", "StateChangeTrigger")
		return
	
	# Определяем путь к диалогу
	var path = ""
	if not dialogue_path.is_empty():
		# Используем полный путь, если указан
		path = dialogue_path
		if not path.begins_with("res://"):
			path = "res://dialogue_quest/" + path
	else:
		# Используем dialogue_id
		path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	
	# Запускаем диалог
	if dm.has_method("start_dialogue"):
		dm.start_dialogue(path)
		DebugLogger.info("StateChangeTrigger: Запущен диалог %s" % path, "StateChangeTrigger")
	else:
		DebugLogger.warning("StateChangeTrigger: DialogueManager не имеет метода start_dialogue", "StateChangeTrigger")

func _get_dialogue_manager() -> Node:
	"""Получает DialogueManager через ServiceLocator"""
	if Engine.has_singleton("ServiceLocator"):
		var loc = Engine.get_singleton("ServiceLocator")
		if loc and loc.has_method("get_dialogue_manager"):
			return loc.get_dialogue_manager()
	return null

func reset() -> void:
	"""Сброс триггера (для тестирования/отладки)"""
	has_triggered = false
