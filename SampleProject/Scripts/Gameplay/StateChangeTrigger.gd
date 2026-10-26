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
## D737: герой зайшов посеред розмови — тригер чекає її кінця в DialogueManager (другий вхід не ставить його вдруге).
var _waiting: bool = false

# Статический флаг для отслеживания показанных предупреждений (на уровне класса)

func _ready() -> void:
	"""Настройка обнаружения столкновений"""
	# Проверяем, не подключен ли сигнал уже (чтобы избежать ошибки при повторном вызове _ready)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	"""Игрок вошел в зону"""
	if has_triggered and one_shot:
		DebugLogger.info("🔄 StateChangeTrigger: Тригер вже спрацював (one_shot=true), ігноруємо", "StateChangeTrigger")
		return

	# Проверяем, что это игрок
	if not body.is_in_group(GameGroups.PLAYER):
		DebugLogger.info("🔄 StateChangeTrigger: Об'єкт не є гравцем, ігноруємо", "StateChangeTrigger")
		return
	if _waiting:
		return
	# D737 / B154: посеред розмови тригер не губиться і не стрибає в неї — спрацьовує, щойно розмови скінчаться.
	# Тоді ж і перевірки стану: розмова сама могла довести сцену до require_state (раніше герой стояв у зоні,
	# стан ще був старий, тригер відсіювався, а нового входу вже не було). Сюжетний тригер спрацьовує, навіть якщо
	# герой встиг вийти із зони: він фіксує місце в сюжеті, а не «стоїть тут».
	_waiting = true
	ServiceLocator.get_dialogue_manager().when_story_free(_fire)


func _fire() -> void:
	_waiting = false
	if has_triggered and one_shot:
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
	# ворота і підміняючи ціль на "Return to the village".
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
			# Діалог тригера — першим: стан, що змінюється, може сам запустити свій діалог
			# (Village: ArrivalToVillage → потім репліка бандита), і вони підуть по черзі.
			_trigger_dialogue()
			_trigger_state_change()

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

	return _get_target_scene().get_current_state_name() == required_state_name

func _get_current_state_name() -> String:
	"""Отримує назву поточного стейту"""
	return _get_target_scene().get_current_state_name()

## Кімната (Canyon, Village), у якій стоїть тригер, — вона й керує станами.
func _get_target_scene() -> Node:
	return owner

func _trigger_state_change() -> void:
	"""Вызывает смену состояния через scene manager"""
	if target_state.is_empty():
		DebugLogger.info("🔄 StateChangeTrigger: target_state пуста, пропускаємо зміну стейту", "StateChangeTrigger")
		return

	var state_name = target_state
	DebugLogger.info("🔄 StateChangeTrigger: ЗАПУСКАЄМО ЗМІНУ СТЕЙТУ на %s" % state_name, "StateChangeTrigger")

	_get_target_scene().change_state_by_name(state_name)

func _trigger_dialogue() -> void:
	"""Запускает диалог через DialogueManager"""
	if dialogue_id.is_empty() and dialogue_path.is_empty():
		DebugLogger.info("🔄 StateChangeTrigger: Діалог не вказано, пропускаємо", "StateChangeTrigger")
		return

	# Усі діалоги лежать у res://dialogue_quest/<id>.dqd; dialogue_path у сценах — повний шлях.
	var path := dialogue_path if not dialogue_path.is_empty() else "res://dialogue_quest/%s.dqd" % dialogue_id
	DebugLogger.info("🔄 StateChangeTrigger: ЗАПУСКАЄМО ДІАЛОГ: %s" % path, "StateChangeTrigger")
	await ServiceLocator.get_dialogue_manager().start_dialogue(path)

func reset() -> void:
	"""Сброс триггера (для тестирования/отладки)"""
	has_triggered = false
