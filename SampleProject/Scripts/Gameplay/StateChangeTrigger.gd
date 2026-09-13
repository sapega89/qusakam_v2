extends Area2D
class_name StateChangeTrigger

## 🔄 StateChangeTrigger - Универсальный триггер для смены состояния и запуска диалогов
## Можно вставлять в любую точку сцены для смены состояния или запуска диалога

# Enums должны быть определены до использования в @export
enum ActionMode {
	STATE_ONLY,
	DIALOGUE_ONLY,
	BOTH
}

# Enum для совместимости с Godot Editor (если свойства настроены как enum)
# В реальности используются строки, но этот enum нужен чтобы избежать ошибок компиляции
# Этот enum доступен через StateChangeTrigger.CanyonState.VALUE для использования в тестах
enum CanyonState {
	NONE,
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
## Назва стану для переходу (використовуйте назви з enum State сцени, наприклад: "INTRO", "EXPLORATION")
## Можна використовувати як рядок ("MONOLOGUE") або як enum (StateChangeTrigger.CanyonState.MONOLOGUE)
var _target_state_internal: String = ""
@export var target_state: Variant = "":  # Назва стану для переходу (може бути String або CanyonState)
	set(value):
		if value is CanyonState:
			_target_state_internal = CanyonState.keys()[value]
		elif value is String:
			_target_state_internal = value
		else:
			_target_state_internal = str(value)
	get:
		return _target_state_internal
## Потрібна назва поточного стану ("" = будь-який, або назва стану з enum State сцени)
## Можна використовувати як рядок ("MONOLOGUE") або як enum (StateChangeTrigger.CanyonState.MONOLOGUE)
var _require_state_internal: String = ""
@export var require_state: Variant = "":  # Потрібна назва поточного стану ("" = будь-який, може бути String або CanyonState)
	set(value):
		if value is CanyonState:
			_require_state_internal = CanyonState.keys()[value]
		elif value is String:
			_require_state_internal = value
		else:
			_require_state_internal = str(value)
	get:
		return _require_state_internal

@export_group("Dialogue")
@export var dialogue_id: String = ""  # ID діалогу для запуску
@export var dialogue_path: String = ""  # Шлях до файлу .dqd

@export_group("Settings")
@export var one_shot: bool = true  # Спрацьовує один раз
@export var action_mode: ActionMode = ActionMode.BOTH  # Режим: Стан, Діалог або обидва

var has_triggered: bool = false

# Статический флаг для отслеживания показанных предупреждений (на уровне класса)
static var _collision_shape_warning_shown: bool = false

func _ready() -> void:
	"""Настройка обнаружения столкновений"""
	# Проверяем, не подключен ли сигнал уже (чтобы избежать ошибки при повторном вызове _ready)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Если нет CollisionShape2D, логируем как info (только один раз)
	# Используем статический флаг на уровне класса, чтобы не показывать сообщение повторно
	if not _collision_shape_warning_shown:
		if not get_node_or_null("CollisionShape2D"):
			DebugLogger.info("🔄 StateChangeTrigger: CollisionShape2D не найден (может быть нормально в тестах)", "StateChangeTrigger")
			_collision_shape_warning_shown = true

func _on_body_entered(body: Node2D) -> void:
	"""Игрок вошел в зону"""
	if has_triggered and one_shot:
		DebugLogger.info("🔄 StateChangeTrigger: Тригер вже спрацював (one_shot=true), ігноруємо", "StateChangeTrigger")
		return

	# Проверяем, что это игрок
	if not body.is_in_group(GameGroups.PLAYER):
		DebugLogger.info("🔄 StateChangeTrigger: Об'єкт не є гравцем, ігноруємо", "StateChangeTrigger")
		return

	# Проверяем требуемое состояние (если указано)
	if not require_state.is_empty():
		var current_state_name = _get_current_state_name()
		if current_state_name != require_state:
			DebugLogger.info("🔄 StateChangeTrigger: Поточний стейт (%s) не відповідає вимогам (%s), ігноруємо" % [current_state_name, require_state], "StateChangeTrigger")
			return

	# Захист від відкату сюжету назад.
	# one_shot живе в інстансі тригера, а кімната пересоздається при кожному
	# вході — тому has_triggered скидається, і старі тригери відпрацьовують
	# повторно. Після повернення з Village це тягнуло Canyon з RELIC_PICKUP
	# назад у EXPLORATION -> CUTSCENE_ABDUCTION -> TO_VILLAGE, знову зачиняючи
	# ворота і підміняючи ціль на "Повернутися до села".
	if _is_backwards_transition():
		DebugLogger.info("🔄 StateChangeTrigger: Стейт %s вже пройдено (зараз %s), ігноруємо відкат" % [
			target_state, _get_current_state_name()
		], "StateChangeTrigger")
		return

	has_triggered = true
	DebugLogger.info("🔄 StateChangeTrigger: ТРИГЕР СПРАЦЮВАВ! Режим: %s, Цільовий стейт: %s, Діалог: %s" % [
		ActionMode.keys()[action_mode],
		target_state if not target_state.is_empty() else "NONE",
		dialogue_id if not dialogue_id.is_empty() else dialogue_path
	], "StateChangeTrigger")
	
	# Відпрацьований тригер більше не має брати участі у фізиці: вимикаємо
	# monitoring одразу, ще до дій. Далі він не ловить body_entered і не
	# крутить перевірки на кожному проході гравця.
	#
	# Саме monitoring, а не queue_free(): _trigger_dialogue() — корутина
	# (всередині є await), і викликається вона без await, тобто продовжує
	# виконуватись уже після виходу з цього методу. Знищення вузла тут
	# вбило б її посеред await і дало "Attempt to call function on
	# previously freed instance". Вузол без monitoring коштує стільки ж,
	# скільки видалений, але переживає власну корутину.
	if one_shot:
		set_deferred(&"monitoring", false)

	# Выполняем действия в зависимости от режима
	match action_mode:
		ActionMode.STATE_ONLY:
			_trigger_state_change()
		ActionMode.DIALOGUE_ONLY:
			_trigger_dialogue()
		ActionMode.BOTH:
			_trigger_state_change()
			_trigger_dialogue()

func _is_backwards_transition() -> bool:
	"""Чи означає цей тригер відкат до вже пройденого стану сцени."""
	if target_state.is_empty():
		return false

	var scene = _get_target_scene()
	if not scene or not ("current_state" in scene):
		return false

	var script: Script = scene.get_script()
	if not script:
		return false

	# enum State сцени лежить у мапі констант скрипта: {"INTRO": 0, "MONOLOGUE": 1, ...}.
	# Значення = порядковий номер, а enum'и сцен написані в сюжетному порядку,
	# тому порівняння номерів = порівняння прогресу.
	var state_enum: Dictionary = script.get_script_constant_map().get("State", {})
	if not state_enum.has(target_state):
		return false

	var target_index: int = state_enum[target_state]
	var current_index: int = scene.current_state

	# <= , а не < : окрім справжнього відкату це прибирає і перезапуск стану,
	# в якому сцена вже перебуває. У логах Canyon це був дубль
	# EXPLORATION (RunID 3) -> EXPLORATION (RunID 4) з повторним _set_objective
	# і зайвим циклом перемикання воріт.
	# Ціна: тригером більше не можна навмисно перезапустити поточний стан.
	# Якщо колись знадобиться — додати окремий @export allow_restart.
	return target_index <= current_index

func _check_current_state(required_state_name: String) -> bool:
	"""Проверяет текущее состояние сцены"""
	if required_state_name.is_empty():
		return true
	
	var scene = _get_target_scene()
	if not scene or not scene.has_method("get_current_state_name"):
		return false
	
	var current_state_name = scene.get_current_state_name()
	return current_state_name == required_state_name

func _get_current_state_name() -> String:
	"""Отримує назву поточного стейту"""
	var scene = _get_target_scene()
	if scene and scene.has_method("get_current_state_name"):
		return scene.get_current_state_name()
	return "UNKNOWN"

func _get_target_scene() -> Node:
	"""Шукає сцену Canyon або іншу, яка керує станами"""
	# 1. Спробуємо current_scene
	var current = get_tree().current_scene
	if current:
		if current.has_method("change_state_by_name") or current.has_method("get_current_state_name"):
			return current
		# 2. Спробуємо знайти child 'Canyon' або 'Logic' в current_scene
		var child = current.find_child("Canyon", true, false)
		if child and (child.has_method("change_state_by_name") or child.has_method("get_current_state_name")):
			return child
			
	# 3. Спробуємо parent власника (якщо ми вкладені)
	var p = get_parent()
	while p:
		if p.has_method("change_state_by_name") or p.has_method("get_current_state_name"):
			return p
		p = p.get_parent()
		
	return null

func _trigger_state_change() -> void:
	"""Вызывает смену состояния через scene manager"""
	if target_state.is_empty():
		DebugLogger.info("🔄 StateChangeTrigger: target_state пуста, пропускаємо зміну стейту", "StateChangeTrigger")
		return
	
	var state_name = target_state
	DebugLogger.info("🔄 StateChangeTrigger: ЗАПУСКАЄМО ЗМІНУ СТЕЙТУ на %s" % state_name, "StateChangeTrigger")
	
	var canyon_scene = _get_target_scene()
	if not canyon_scene:
		DebugLogger.warning("🔄 StateChangeTrigger: Текущая сцена не найдена", "StateChangeTrigger")
		return
	
	# Пробуем разные методы изменения состояния
	if canyon_scene.has_method("change_state_by_name"):
		canyon_scene.change_state_by_name(state_name)
		DebugLogger.info("🔄 StateChangeTrigger: ✅ Стейт успішно змінено на %s через change_state_by_name()" % state_name, "StateChangeTrigger")
	elif canyon_scene.has_method("set") and "current_state" in canyon_scene:
		# Прямое изменение через setter (если есть)
		# state_name вже оголошено вище
		# Пытаемся найти enum State в сцене
		if canyon_scene.has_method("get"):
			var state_enum_value = canyon_scene.get("State")
			if state_enum_value != null:
				# Проверяем что это действительно enum (Dictionary с ключами)
				# Используем безопасный доступ к enum
				if typeof(state_enum_value) == TYPE_DICTIONARY:
					if state_enum_value.has(state_name):
						var state_value = state_enum_value[state_name]
						canyon_scene.current_state = state_value
						DebugLogger.info("🔄 StateChangeTrigger: ✅ Стейт успішно змінено на %s через current_state setter" % state_name, "StateChangeTrigger")
					else:
						DebugLogger.warning("🔄 StateChangeTrigger: Состояние %s не найдено в enum сцены" % state_name, "StateChangeTrigger")
				else:
					# Пробуем использовать как enum напрямую (если это enum)
					DebugLogger.warning("🔄 StateChangeTrigger: Enum State имеет неправильный тип: %s" % typeof(state_enum_value), "StateChangeTrigger")
			else:
				DebugLogger.warning("🔄 StateChangeTrigger: Enum State не найден в сцене", "StateChangeTrigger")
	else:
		DebugLogger.warning("🔄 StateChangeTrigger: Сцена не имеет метода change_state_by_name или свойства current_state", "StateChangeTrigger")

func _trigger_dialogue() -> void:
	"""Запускает диалог через DialogueManager"""
	if dialogue_id.is_empty() and dialogue_path.is_empty():
		DebugLogger.info("🔄 StateChangeTrigger: Діалог не вказано, пропускаємо", "StateChangeTrigger")
		return
	
	# Получаем DialogueManager
	var dm = await _get_dialogue_manager()
	if not dm:
		DebugLogger.warning("🔄 StateChangeTrigger: ❌ DialogueManager не найден!", "StateChangeTrigger")
		return
	
	# Определяем путь к диалогу
	var path = ""
	if not dialogue_path.is_empty():
		# Используем полный путь, если указан
		path = dialogue_path
		if not path.begins_with("res://"):
			path = "res://dialogue_quest/" + path
	else:
		# Используем dialogue_id - спробуємо кілька варіантів шляху
		var possible_paths = [
			"res://dialogue_quest/" + dialogue_id + ".dqd",
			"res://dialogue_quest/dialogues/" + dialogue_id + ".dqd",
			"res://dialogue_quest/" + dialogue_id + ".dqd"
		]
		
		# Знаходимо існуючий файл
		for test_path in possible_paths:
			if ResourceLoader.exists(test_path) or FileAccess.file_exists(test_path):
				path = test_path
				break
		
		if path.is_empty():
			# Якщо не знайшли, використовуємо стандартний шлях
			path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	
	DebugLogger.info("🔄 StateChangeTrigger: ЗАПУСКАЄМО ДІАЛОГ: %s" % path, "StateChangeTrigger")
	
	# Запускаем диалог
	if dm.has_method("start_dialogue"):
		var result = await dm.start_dialogue(path)
		if result:
			DebugLogger.info("🔄 StateChangeTrigger: ✅ Діалог успішно запущено: %s" % path, "StateChangeTrigger")
		else:
			DebugLogger.warning("🔄 StateChangeTrigger: ❌ Не вдалося запустити діалог: %s" % path, "StateChangeTrigger")
	else:
		DebugLogger.warning("🔄 StateChangeTrigger: ❌ DialogueManager не имеет метода start_dialogue", "StateChangeTrigger")

func _get_dialogue_manager() -> Node:
	"""Получает DialogueManager через ServiceLocator"""
	# ServiceLocator is an autoload, accessible directly
	if not ServiceLocator:
		DebugLogger.warning("🔄 StateChangeTrigger: ❌ ServiceLocator не доступний (autoload)", "StateChangeTrigger")
		return null
	
	# Wait for ServiceLocator to be ready
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	
	if ServiceLocator.has_method("get_dialogue_manager"):
		var dm = ServiceLocator.get_dialogue_manager()
		if dm:
			return dm
		else:
			DebugLogger.warning("🔄 StateChangeTrigger: ❌ DialogueManager повернув null", "StateChangeTrigger")
	else:
		DebugLogger.warning("🔄 StateChangeTrigger: ❌ ServiceLocator не має методу get_dialogue_manager", "StateChangeTrigger")
	
	# Fallback directly to Autoload
	var direct_dm = get_node_or_null("/root/DialogueManager")
	if direct_dm:
		DebugLogger.info("🔄 StateChangeTrigger: DialogueManager знайдено через /root/DialogueManager (fallback)", "StateChangeTrigger")
		return direct_dm
		
	return null

func reset() -> void:
	"""Сброс триггера (для тестирования/отладки)"""
	has_triggered = false
