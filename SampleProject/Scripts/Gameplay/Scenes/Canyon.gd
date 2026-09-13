extends Node2D

## 🏜️ Canyon Scene Manager
## States: INTRO, MONOLOGUE, EXPLORATION, CUTSCENE_ABDUCTION, TO_VILLAGE, RELIC_PICKUP, TO_DESERT_ROAD
## Follows Robust State-Flow Pattern (StepType + Guards + Addressable Dialogues)

enum State {
	INTRO,
	MONOLOGUE,
	EXPLORATION,
	CUTSCENE_ABDUCTION,
	TO_VILLAGE,
	RELIC_PICKUP,  # Возврат из деревни за реликвией
	EXIT_CUTSCENE,  # Катсцена спуска с каньона
	TO_DESERT_ROAD
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.INTRO:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0
var _previous_state: State = State.INTRO  # Предыдущее состояние для события
signal state_complete(state: State)

# Опціональний Quest Manager для відстеження прогресу
@onready var quest_manager: SceneQuestManager = get_node_or_null("SceneQuestManager")

var _canyon_ready_called: bool = false
var _canyon_ready_room: String = ""

func _ready() -> void:
	print("🏜️ [Canyon] ========== _ready() ВИКЛИКАНО ==========")
	DebugLogger.info("🏜️ Canyon: ========== _ready() ВИКЛИКАНО ==========", "Canyon")
	
	# Перевіряємо, чи це повторний виклик для тієї ж кімнати
	var current_room = ""
	if MetSys and MetSys.has_method("get_current_room_name"):
		current_room = MetSys.get_current_room_name()
	
	if _canyon_ready_called and _canyon_ready_room == current_room:
		print("⚠️ [Canyon] _ready() вже викликано для кімнати %s, пропускаємо повторну ініціалізацію" % current_room)
		DebugLogger.warning("🏜️ Canyon: _ready() вже викликано для кімнати %s, пропускаємо повторну ініціалізацію" % current_room, "Canyon")
		return
	
	_canyon_ready_called = true
	_canyon_ready_room = current_room
	
	print("🏜️ [Canyon] Поточний стейт перед визначенням: %s" % State.keys()[current_state])
	print("🏜️ [Canyon] Поточна кімната: %s" % current_room)
	DebugLogger.info("🏜️ Canyon: Поточний стейт перед визначенням: %s" % State.keys()[current_state], "Canyon")
	DebugLogger.info("🏜️ Canyon: Поточна кімната: %s" % current_room, "Canyon")
	
	# ServiceLocator is an autoload, accessible directly
	if ServiceLocator:
		if not ServiceLocator.is_node_ready():
			DebugLogger.info("🏜️ Canyon: Очікуємо готовності ServiceLocator...", "Canyon")
			await ServiceLocator.ready
		DebugLogger.info("🏜️ Canyon: ServiceLocator готовий", "Canyon")
		
		# Wait a frame to ensure DialogueManager is registered
		await get_tree().process_frame
	else:
		DebugLogger.warning("🏜️ Canyon: ServiceLocator не знайдено (autoload недоступний)!", "Canyon")
	
	# Перевіряємо наявність DialogueSystem
	_check_dialogue_system()
	
	# Ініціалізуємо Quest Manager (якщо є)
	_initialize_quest_manager()
	
	# Перевіряємо та створюємо GateControllers ПЕРЕД визначенням стейту
	_ensure_gate_controllers()
	
	# Чекаємо кілька кадрів, щоб GateControllers ініціалізувалися
	await get_tree().process_frame
	await get_tree().process_frame
	
	# КРИТИЧНО: Ждем загрузки quest flags перед определением состояния
	# Это гарантирует что quest flags будут доступны при определении начального состояния
	await _wait_for_quest_flags_loaded()
	
	# Определяем начальное состояние на основе текущей сцени/room_id
	DebugLogger.info("🏜️ Canyon: Визначаємо початковий стейт...", "Canyon")
	_determine_initial_state()
	DebugLogger.info("🏜️ Canyon: Початковий стейт визначено: %s" % State.keys()[current_state], "Canyon")
	
	# Чекаємо ще кілька кадрів, щоб GateControllers точно ініціалізувалися
	await get_tree().process_frame
	await get_tree().process_frame
	
	# КРИТИЧНО: Оновлюємо ворота відповідно до поточного стану ПОСЛЕ того як состояние правильно определено
	# Это гарантирует что ворота будут правильно открыты/закрыты на основе состояния из quest flags
	_update_gates_for_state(current_state)
	
	# Підписуємося на зміни quest flags, щоб реагувати на завершення діалогів в інших сценах
	_connect_to_quest_events()
	
	# Запускаємо стейт
	DebugLogger.info("🏜️ Canyon: Запускаємо обробку стейту...", "Canyon")
	# _on_state_changed викликається через setter current_state у _determine_initial_state
	# Якщо _determine_initial_state не змінив стан (вже був дефолтний), то setter не викликався?
	# Перевіримо це.
	if state_run_id == 0:
		_on_state_changed(current_state)

func _ensure_gate_controllers() -> void:
	"""Гарантує наявність GateController для воріт у TileMap"""
	var gates_config = {
		"Gate": "canyon_abduction_complete",   # Ворота до Village (вихід)
		# Спуск до пустелі відкривається лише ПІСЛЯ візиту в село й діалогу з дідом.
		# Раніше тут стояв canyon_exploration_complete — він ставиться одразу після
		# вступного монологу, тож ворота зникали ще до того, як гравець до них дійде.
		"Gate2": "village_left_complete"        # Ворота до дороги (спуск у пустелю)
	}
	
	# Перевіряємо поточний прогрес для правильного початкового стану воріт
	var game = Game.get_singleton()
	var village_left_complete = false
	if game:
		village_left_complete = game.get_quest_flag("village_left_complete", false)
	
	for gate_name in gates_config:
		if not _find_gate_controller(gate_name):
			var controller = GateController.new()
			controller.gate_layer_name = gate_name
			controller.required_quest_id = gates_config[gate_name]
			
			# Визначаємо початковий стан на основі quest flags
			# Якщо гравець повернувся з Village, ворота мають бути відкриті
			var should_be_open = false
			if game:
				var quest_flag = gates_config[gate_name]
				should_be_open = game.get_quest_flag(quest_flag, false)
				# Якщо гравець повернувся з Village (village_left_complete), всі ворота відкриті
				if village_left_complete:
					should_be_open = true
			
			controller.open_by_default = should_be_open
			controller.name = "Controller_" + gate_name
			add_child(controller)
			DebugLogger.info("🏜️ Canyon: Створено контролер для %s з квестом %s (open_by_default=%s)" % [gate_name, gates_config[gate_name], should_be_open], "Canyon")
		else:
			# Якщо контролер вже існує, перевіряємо та оновлюємо його стан
			var controller = _find_gate_controller(gate_name)
			if controller and game:
				var quest_flag = gates_config[gate_name]
				var should_be_open = game.get_quest_flag(quest_flag, false)
				if village_left_complete:
					should_be_open = true
				
				# Встановлюємо правильний стан через _pending_open_state
				if controller.has_method("_set_pending_state"):
					controller._set_pending_state(should_be_open)
				else:
					# Якщо GateController вже ініціалізований, викликаємо open_gate/close_gate
					if should_be_open:
						controller.open_gate()
					else:
						controller.close_gate()
			
			DebugLogger.info("🏜️ Canyon: Контролер для %s вже існує" % gate_name, "Canyon")

func _update_gates_for_state(state: State) -> void:
	"""Централізоване керування воротами на основі стану сцени"""
	var gate_exit = _find_gate_controller("Gate")   # Вихід до села (ворота до Village)
	var gate_inner = _find_gate_controller("Gate2") # Внутрішній прохід (ворота до дороги)
	
	# Якщо GateControllers не знайдені, спробуємо знайти їх через call_deferred
	if not gate_exit or not gate_inner:
		DebugLogger.warning("🏜️ Canyon: GateControllers не знайдені, спробуємо через call_deferred...", "Canyon")
		call_deferred("_update_gates_for_state_deferred", state)
		return
	
	# Викликаємо основну логіку оновлення
	_apply_gates_state(state, gate_exit, gate_inner)

func _update_gates_for_state_deferred(state: State) -> void:
	"""Відкладене оновлення воріт (якщо GateControllers не були готові)"""
	var gate_exit = _find_gate_controller("Gate")
	var gate_inner = _find_gate_controller("Gate2")
	
	if not gate_exit:
		DebugLogger.warning("🏜️ Canyon: GateController 'Gate' все ще не знайдено після call_deferred!", "Canyon")
	if not gate_inner:
		DebugLogger.warning("🏜️ Canyon: GateController 'Gate2' все ще не знайдено після call_deferred!", "Canyon")
	
	# Викликаємо основну логіку оновлення
	_apply_gates_state(state, gate_exit, gate_inner)

func _apply_gates_state(state: State, gate_exit: Node, gate_inner: Node) -> void:
	"""Основна логіка оновлення воріт (винесена в окрему функцію для повторного використання)"""
	# Проверяем что GateControllers не null перед вызовом методов
	if not gate_exit:
		DebugLogger.warning("🏜️ Canyon: GateController 'Gate' не найден, пропускаем обновление", "Canyon")
		return
	if not gate_inner:
		DebugLogger.warning("🏜️ Canyon: GateController 'Gate2' не найден, пропускаем обновление", "Canyon")
		return
	
	# Проверяем что GateControllers имеют нужные методы
	if not gate_exit.has_method("open_gate") or not gate_exit.has_method("close_gate"):
		DebugLogger.warning("🏜️ Canyon: GateController 'Gate' не имеет методов open_gate/close_gate", "Canyon")
		return
	if not gate_inner.has_method("open_gate") or not gate_inner.has_method("close_gate"):
		DebugLogger.warning("🏜️ Canyon: GateController 'Gate2' не имеет методов open_gate/close_gate", "Canyon")
		return
	
	DebugLogger.info("🏜️ Canyon: Обновляем ворота для состояния %s" % State.keys()[state], "Canyon")
	
	match state:
		State.INTRO, State.MONOLOGUE:
			# На початку обидві ворота ЗАКРИТІ (видимі)
			if gate_exit: 
				gate_exit.close_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate' (до Village) ЗАКРИТІ", "Canyon")
			if gate_inner: 
				gate_inner.close_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate2' (до дороги) ЗАКРИТІ", "Canyon")
			
		State.EXPLORATION:
			# Спуск у пустелю ще закритий: спершу треба дійти до села і поговорити з дідом.
			if gate_exit:
				gate_exit.close_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate' (до Village) залишаються ЗАКРИТИМИ", "Canyon")
			if gate_inner:
				gate_inner.close_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate2' (спуск у пустелю) ЗАКРИТІ", "Canyon")

		State.CUTSCENE_ABDUCTION:
			# Після викрадення відкривається шлях до села, але не в пустелю.
			if gate_exit:
				gate_exit.open_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate' (до Village) ВІДКРИТІ", "Canyon")
			if gate_inner:
				gate_inner.close_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate2' (спуск у пустелю) ЗАКРИТІ", "Canyon")

		State.TO_VILLAGE:
			# Пора в село. Шлях туди — через Gate; спуск у пустелю досі закритий.
			if gate_exit:
				gate_exit.open_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate' (до Village) ВІДКРИТІ - можна йти в село", "Canyon")
			if gate_inner:
				gate_inner.close_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate2' (спуск у пустелю) ЗАКРИТІ", "Canyon")
			
		State.RELIC_PICKUP, State.EXIT_CUTSCENE:
			# У фінальних стадіях всі ворота відкриті
			# Важливо: при поверненні з Village стан RELIC_PICKUP, тому ворота мають бути відкриті
			if gate_exit: 
				gate_exit.open_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate' (до Village) ВІДКРИТІ (фінал/RELIC_PICKUP)", "Canyon")
			if gate_inner: 
				gate_inner.open_gate()
				DebugLogger.info("🏜️ Canyon: Ворота 'Gate2' (до дороги) ВІДКРИТІ (фінал/RELIC_PICKUP)", "Canyon")
	
	DebugLogger.info("🏜️ Canyon: Ворота синхронізовано зі станом %s" % State.keys()[state], "Canyon")

func _determine_initial_state() -> void:
	"""Определяет начальное состояние на основе room_id текущей сцены"""
	DebugLogger.info("🏜️ Canyon: _determine_initial_state() викликано", "Canyon")
	
	# MetSys is an autoload singleton, accessible directly
	if not MetSys:
		DebugLogger.warning("🏜️ Canyon: ❌ MetSys singleton not found (autoload недоступний), використовуємо INTRO за замовчуванням", "Canyon")
		current_state = State.INTRO
		return
	
	# Отримуємо назву поточної кімнати через MetSys API
	var room_name = ""
	if MetSys.has_method("get_current_room_name"):
		room_name = MetSys.get_current_room_name()
	
	if room_name.is_empty():
		DebugLogger.warning("🏜️ Canyon: ❌ MetSys.get_current_room_name() повернув порожній рядок, використовуємо INTRO за замовчуванням", "Canyon")
		current_state = State.INTRO
		return
	
	DebugLogger.info("🏜️ Canyon: ✅ Current room_name: %s" % room_name, "Canyon")
	
	# 2. Перевіряємо квестові флаги (це найнадійніший спосіб)
	var game = Game.get_singleton()
	if game:
		# Якщо ми вже були в селі і повернулися - це найвищий пріоритет
		if game.get_quest_flag("village_left_complete"):
			current_state = State.RELIC_PICKUP
			_previous_state = State.TO_VILLAGE  # Встановлюємо попередній стан для коректної роботи
			print("🏜️ [Canyon] ✅ Прогрес виявлено (village_left), стейт = RELIC_PICKUP")
			print("🏜️ [Canyon] ⚠️ ВАЖЛИВО: При поверненні з Village ворота мають бути ВІДКРИТІ!")
			DebugLogger.info("🏜️ Canyon: ✅ Прогрес виявлено (village_left), стейт = RELIC_PICKUP", "Canyon")
			DebugLogger.info("🏜️ Canyon: ⚠️ ВАЖЛИВО: При поверненні з Village ворота мають бути ВІДКРИТІ!", "Canyon")
			return
		
		# Якщо ми вже були в селі (village_abduction_complete), але ще не залишили його
		# то при поверненні до Canyon не встановлюємо TO_VILLAGE, бо це може викликати
		# автоматичний перехід назад до Village
		if game.get_quest_flag("village_abduction_complete", false):
			# КРИТИЧНО: Перевіряємо, чи гравець зараз в Village (щоб не встановлювати TO_VILLAGE, якщо він там)
			var current_room_name = MetSys.get_current_room_name() if MetSys else ""
			if "Village" in current_room_name or "village" in current_room_name.to_lower():
				print("⚠️ [Canyon] Гравець зараз в Village (%s), не встановлюємо TO_VILLAGE" % current_room_name)
				DebugLogger.warning("🏜️ Canyon: Гравець зараз в Village (%s), не встановлюємо TO_VILLAGE" % current_room_name, "Canyon")
				# Встановлюємо RELIC_PICKUP замість TO_VILLAGE, щоб уникнути автоматичного переходу
				current_state = State.RELIC_PICKUP
				_previous_state = State.TO_VILLAGE
				return
			
			# Гравець вже був у Village, тому при поверненні до Canyon
			# встановлюємо стан RELIC_PICKUP (якщо ще не залишили Village)
			# або залишаємо поточний прогрес
			if not game.get_quest_flag("village_left_complete", false):
				# Гравець ще не залишив Village, тому при поверненні до Canyon
				# встановлюємо стан, який дозволяє йому повернутися до Village
				# але не викликає автоматичний перехід
				current_state = State.TO_VILLAGE
				DebugLogger.info("🏜️ Canyon: ✅ Гравець повернувся з Village, стейт = TO_VILLAGE (без авто-переходу)", "Canyon")
				return
		
		# Якщо катсцена викрадення завершена, але гравець ще не був у Village
		if game.get_quest_flag("canyon_abduction_complete", false):
			# Перевіряємо, чи гравець вже був у Village
			if not game.get_quest_flag("village_abduction_complete", false):
				_previous_state = State.CUTSCENE_ABDUCTION
				current_state = State.TO_VILLAGE
				DebugLogger.info("🏜️ Canyon: ✅ Abduction finished, setting state to TO_VILLAGE", "Canyon")
				return
		
		if game.get_quest_flag("canyon_exploration_complete", false):
			_previous_state = State.EXPLORATION
			current_state = State.CUTSCENE_ABDUCTION
			DebugLogger.info("🏜️ Canyon: ✅ Exploration finished, setting state to CUTSCENE_ABDUCTION", "Canyon")
			return

		if game.get_quest_flag("canyon_intro_complete", false):
			_previous_state = State.MONOLOGUE
			current_state = State.EXPLORATION
			DebugLogger.info("🏜️ Canyon: ✅ Intro finished, setting state to EXPLORATION", "Canyon")
			return

	# 3. Визначаємо стан за назвою кімнати (fallback)
	DebugLogger.info("🏜️ Canyon: ✅ Starting scene detected, setting state to INTRO", "Canyon")
	current_state = State.INTRO

func trigger_abduction_cutscene() -> void:
	"""Вызывается из Area2D триггера при входе в зону катсцены"""
	if current_state == State.EXPLORATION:
		current_state = State.CUTSCENE_ABDUCTION

func change_state_by_name(state_name: String) -> void:
	"""Изменяет состояние по имени (для StateChangeTrigger)"""
	var state_key = state_name.to_upper()
	
	# Пытаемся найти состояние в enum
	if State.keys().has(state_key):
		var new_state = State[state_key]
		current_state = new_state
		DebugLogger.info("🏜️ Canyon: State changed to %s via StateChangeTrigger" % state_key, "Canyon")
	else:
		DebugLogger.warning("🏜️ Canyon: Unknown state name: %s" % state_name, "Canyon")

func get_current_state_name() -> String:
	"""Возвращает имя текущего состояния (для проверки в триггерах)"""
	return State.keys()[current_state]

func trigger_exit_cutscene(_target_room: String = "") -> void:
	"""Вызывается из CanyonExitTrigger при входе в зону выхода"""
	# Переходим в состояние катсцены выхода (тільки якщо ще не в цьому стані)
	if current_state != State.EXIT_CUTSCENE:
		DebugLogger.info("🏜️ Canyon: CanyonExitTrigger активовано, переходимо до стану EXIT_CUTSCENE", "Canyon")
		current_state = State.EXIT_CUTSCENE
	else:
		DebugLogger.info("🏜️ Canyon: CanyonExitTrigger активовано, але стан вже EXIT_CUTSCENE", "Canyon")
	# Перехід до наступної кімнати обробляється автоматично через MetSys room connections
	# Параметр _target_room залишено для сумісності з викликами, але не використовується

func _on_state_changed(new_state: State) -> void:
	"""Вызывается при изменении current_state через setter"""
	if not is_node_ready():
		return
		
	# Инкрементируем ID прогона, чтобы остановить старые асинхронные задачи
	state_run_id += 1
	var run_id = state_run_id
	
	DebugLogger.info("🏜️ Canyon: >>> STATE CHANGED TO: %s (RunID: %d)" % [State.keys()[new_state], run_id], "Canyon")
	
	# Оновлюємо ворота при кожній зміні стану
	# Використовуємо call_deferred, щоб переконатися, що GateControllers готові
	call_deferred("_update_gates_for_state", new_state)
	
	# Якщо це стан TO_VILLAGE і гравець вже був у Village, не запускаємо логіку переходу
	# щоб уникнути автоматичного переходу назад до Village
	if new_state == State.TO_VILLAGE:
		var game = Game.get_singleton()
		if game and game.get_quest_flag("village_abduction_complete", false):
			DebugLogger.info("🏜️ Canyon: Стан TO_VILLAGE, але гравець вже був у Village - пропускаємо автоматичний перехід", "Canyon")
			# Встановлюємо об'єктив, але не запускаємо діалог
			if game.has_method("set_objective"):
				game.set_objective("Повернутися до села")
			# Емітуємо подію зміни стану
			_emit_state_changed_event(_previous_state, new_state)
			_previous_state = new_state
			return
	
	# Эмитим событие смены состояния
	_emit_state_changed_event(_previous_state, new_state)
	
	# Сохраняем текущее состояние как предыдущее
	_previous_state = new_state
	
	DebugLogger.info("🏜️ Canyon: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	
	_apply_state_logic(new_state, run_id)

func _emit_state_changed_event(old_state: State, new_state: State) -> void:
	"""Эмитит событие смены состояния через GameFlow (State Manager)"""
	var old_state_name = State.keys()[old_state] if old_state >= 0 else "NONE"
	var new_state_name = State.keys()[new_state]
	
	# Пытаемся использовать GameFlow (State Manager) через ServiceLocator
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_game_flow"):
			var game_flow = service_locator.get_game_flow()
			if game_flow and game_flow.has_signal("scene_state_changed"):
				game_flow.scene_state_changed.emit("Canyon", old_state_name, new_state_name)
				DebugLogger.info("🏜️ Canyon: Event emitted via GameFlow - state changed from %s to %s" % [old_state_name, new_state_name], "Canyon")
				return
	
	# Fallback: используем EventBus, если GameFlow недоступен
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		if event_bus and event_bus.has_signal("scene_state_changed"):
			event_bus.scene_state_changed.emit("Canyon", old_state_name, new_state_name)
			DebugLogger.info("🏜️ Canyon: Event emitted via EventBus (fallback) - state changed from %s to %s" % [old_state_name, new_state_name], "Canyon")

func _apply_state_logic(state: Variant, run_id: int) -> void:
	# Приводим Variant к State для совместимости с базовым классом
	if not state is State:
		DebugLogger.warning("🏜️ Canyon: _apply_state_logic получил неверный тип состояния: %s" % typeof(state), "Canyon")
		return
	
	var canyon_state = state as State
	match canyon_state:
		State.INTRO:
			# Начало - игрок появляется в каньоне
			_on_intro_state(run_id)
		State.MONOLOGUE:
			# Монолог персонажа в начальной сцене - о глупом деде и шамане
			_on_monologue_state(run_id)
		State.EXPLORATION:
			# Изучение окружения - персонаж осматривается, затем свободное исследование
			_on_exploration_state(run_id)
		State.CUTSCENE_ABDUCTION:
			# Катсцена - показывают как уводят жителей, персонаж чувствует что-то не так
			_on_abduction_cutscene_state(run_id)
		State.TO_VILLAGE:
			# Переход в деревню - персонаж бежит туда
			_on_to_village_state(run_id)
		State.RELIC_PICKUP:
			# Возврат из деревни - медитация возле священных обладунков
			_on_relic_pickup_state(run_id)
		State.EXIT_CUTSCENE:
			# Катсцена спуска с каньона - показываем как Кусакам спускается
			_on_exit_cutscene_state(run_id)
		State.TO_DESERT_ROAD:
			# Переход в пустыню после катсцены спуска
			_on_to_desert_road_state(run_id)
		_:
			DebugLogger.warning("🏜️ Canyon: Неизвестное состояние: %s" % state, "Canyon")

func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
	var step_name = StepType.keys()[type]
	DebugLogger.info("🏜️ Canyon: 🎯 ВИКОНУЄМО ДІЮ: %s (діалог: %s)" % [step_name, dialogue_id if not dialogue_id.is_empty() else "N/A"], "Canyon")
	
	match type:
		StepType.DIALOGUE:
			# Перевіряємо, чи діалог вже був прочитаний
			if _is_dialogue_completed(dialogue_id):
				DebugLogger.info("🏜️ Canyon: ⏭️ Діалог %s вже був прочитаний, пропускаємо" % dialogue_id, "Canyon")
				# Не запускаємо діалог, але все одно позначаємо квест як виконаний (якщо потрібно)
				# _complete_quest_for_dialogue(dialogue_id) - не викликаємо, бо квест вже виконаний
				return
			
			DebugLogger.info("🏜️ Canyon: 💬 ДІЯ: Запуск діалогу %s" % dialogue_id, "Canyon")
			await _play_dialogue(dialogue_id, run_id)
			# Завершаємо квести після діалогів
			_complete_quest_for_dialogue(dialogue_id)
		StepType.COMBAT:
			DebugLogger.info("🏜️ Canyon: ⚔️ ДІЯ: Запуск бою (діалог: %s)" % dialogue_id, "Canyon")
			await _play_dialogue(dialogue_id, run_id)
			# Завершаємо квести після бою
			_complete_quest_for_dialogue(dialogue_id)
		StepType.LOOP:
			DebugLogger.info("🏜️ Canyon: 🔄 ДІЯ: Очікування 1 секунда (LOOP)", "Canyon")
			await get_tree().create_timer(1.0).timeout
		StepType.TRANSITION:
			DebugLogger.info("🏜️ Canyon: 🚪 ДІЯ: Перехід (очікування 0.5 секунди)", "Canyon")
			await get_tree().create_timer(0.5).timeout
	
	if run_id != state_run_id: 
		DebugLogger.info("🏜️ Canyon: ⚠️ Стейт змінився під час виконання дії, перериваємо", "Canyon")
		return
	
	# EXPLORATION та CUTSCENE_ABDUCTION не переходять автоматично - чекають триггера або дій гравця
	if current_state != State.EXPLORATION and current_state != State.CUTSCENE_ABDUCTION:
		DebugLogger.info("🏜️ Canyon: ➡️ Переходимо до наступного стейту (поточний: %s)" % State.keys()[current_state], "Canyon")
		advance_state()
	else:
		DebugLogger.info("🏜️ Canyon: ⏸️ Стейт %s - очікуємо триггера зони або дій гравця" % State.keys()[current_state], "Canyon")

var _is_dialogue_playing: bool = false

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	"""Програє діалог через DialogueManager"""
	if state_run_id != run_id or dialogue_id.is_empty():
		return
		
	if _is_dialogue_playing:
		DebugLogger.info("🏜️ Canyon: Діалог %s проігноровано, вже програється інший" % dialogue_id, "Canyon")
		return
		
	_is_dialogue_playing = true
	DebugLogger.info("🏜️ Canyon: ⏩ Запуск діалогу: %s" % dialogue_id, "Canyon")
	
	var dm = await _get_dialogue_manager()
	if not dm:
		DebugLogger.warning("🏜️ Canyon: ❌ DialogueManager не знайдено! Діалог %s не запущено" % dialogue_id, "Canyon")
		return

	# Спробуємо кілька варіантів шляху
	var possible_paths = [
		"res://dialogue_quest/" + dialogue_id + ".dqd",
		"res://dialogue_quest/dialogues/" + dialogue_id + ".dqd"
	]
	
	var path = ""
	for test_path in possible_paths:
		if ResourceLoader.exists(test_path) or FileAccess.file_exists(test_path):
			path = test_path
			break
	
	if path.is_empty():
		path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	
	DebugLogger.info("🏜️ Canyon: 📂 Шлях до діалогу: %s" % path, "Canyon")
	
	var started = await dm.start_dialogue(path)
	if started:
		DebugLogger.info("🏜️ Canyon: ✅ Діалог %s успішно запущено, очікуємо завершення..." % dialogue_id, "Canyon")
		
		if Engine.has_singleton("EventBus"):
			while true:
				var finished_id = await EventBus.dialogue_finished
				if finished_id == path or finished_id == dialogue_id:
					DebugLogger.info("🏜️ Canyon: ✅ Діалог %s завершено" % dialogue_id, "Canyon")
					# Завершуємо квест на основі діалогу ПЕРЕД скиданням прапорця
					_complete_quest_for_dialogue(dialogue_id)
					# Додаємо невелику затримку після завершення діалогу
					await get_tree().create_timer(0.1).timeout
					break
				if run_id != state_run_id: 
					DebugLogger.info("🏜️ Canyon: ⚠️ Стейт змінився під час діалогу, перериваємо очікування", "Canyon")
					_is_dialogue_playing = false
					return
					
		_is_dialogue_playing = false
	else:
		_is_dialogue_playing = false
		DebugLogger.warning("🏜️ Canyon: ❌ Не вдалося запустити діалог %s (шлях: %s)" % [dialogue_id, path], "Canyon")

func advance_state() -> void:
	state_complete.emit(current_state)
	# EXIT_CUTSCENE переходит в TO_DESERT_ROAD
	if current_state == State.EXIT_CUTSCENE:
		current_state = State.TO_DESERT_ROAD
	elif current_state < State.TO_DESERT_ROAD:
		current_state = (current_state + 1) as State
	# Переходи між сценами обробляються автоматично через MetSys room connections
	# Не потрібно викликати ручні переходи - MetSys сам обробить перехід, коли гравець доходить до межі кімнати

func set_state_for_relic_pickup() -> void:
	"""Вызывается при возврате из деревни для подбора реликвии"""
	current_state = State.RELIC_PICKUP

func _check_dialogue_system() -> void:
	"""Перевіряє наявність DialogueSystem"""
	# DialogueSystem живе в Game.tscn, а не в кімнаті. Раніше копія стояла в
	# кожній мапі й помирала разом з кімнатою: під час переходу DialogueManager
	# чіплявся за DialogueSystem старої кімнати, ScrollingRoomTransitions робив
	# їй queue_free() — вікно зникало посеред діалогу, dialogue_ended не
	# приходив, і гра залипала з event = true.
	var game := Game.get_singleton()
	var dialogue_system = game.get_node_or_null("DialogueSystem") if game else null
	if dialogue_system:
		DebugLogger.info("🏜️ Canyon: ✅ DialogueSystem знайдено (Game)", "Canyon")
		# Перевіряємо компоненти
		var dialogue_player = dialogue_system.get_node_or_null("DialoguePlayer")
		var dialogue_box = dialogue_system.get_node_or_null("DialogueBox")
		DebugLogger.info("🏜️ Canyon: DialoguePlayer: %s, DialogueBox: %s" % [
			"✅ знайдено" if dialogue_player else "❌ не знайдено",
			"✅ знайдено" if dialogue_box else "❌ не знайдено"
		], "Canyon")
	else:
		DebugLogger.warning("🏜️ Canyon: ❌ DialogueSystem НЕ знайдено! Діалоги не працюватимуть!", "Canyon")
		DebugLogger.warning("🏜️ Canyon: DialogueSystem.tscn має бути в Game.tscn (не в мапі)", "Canyon")

func _connect_to_quest_events() -> void:
	"""Підписується на події зміни quest flags для реакції на завершення діалогів в інших сценах"""
	var game = Game.get_singleton()
	if game:
		if not game.quest_flag_changed.is_connected(_on_quest_flag_changed):
			game.quest_flag_changed.connect(_on_quest_flag_changed)
			DebugLogger.info("🏜️ Canyon: Підписано на quest_flag_changed сигнал", "Canyon")
	else:
		DebugLogger.warning("🏜️ Canyon: Game singleton не знайдено, не можу підписатися на quest_flag_changed", "Canyon")

func _on_quest_flag_changed(quest_id: String, value: Variant) -> void:
	"""Обробник зміни quest flag - реагує на завершення діалогів в інших сценах"""
	# Якщо гравець завершив останній діалог в Village, змінюємо стан на RELIC_PICKUP
	if quest_id == "village_left_complete" and value == true:
		# Перевіряємо, чи ми зараз в Canyon
		var current_room = ""
		if MetSys and MetSys.has_method("get_current_room_name"):
			current_room = MetSys.get_current_room_name()
		
		if "Canyon" in current_room or current_room.is_empty():
			# Змінюємо стан на RELIC_PICKUP, якщо ще не в цьому стані
			if current_state != State.RELIC_PICKUP:
				DebugLogger.info("🏜️ Canyon: Quest flag 'village_left_complete' встановлено - змінюємо стан на RELIC_PICKUP", "Canyon")
				current_state = State.RELIC_PICKUP
				_previous_state = State.TO_VILLAGE

func _initialize_quest_manager() -> void:
	"""Ініціалізує Quest Manager (якщо він є в сцені)"""
	if quest_manager:
		quest_manager.all_stages_completed.connect(_on_all_quest_stages_completed)
		quest_manager.scene_unlocked.connect(_on_quest_scene_unlocked)
		quest_manager.progress_updated.connect(_on_quest_progress_updated)
		DebugLogger.info("🏜️ Canyon: Quest Manager ініціалізовано", "Canyon")
	else:
		DebugLogger.info("🏜️ Canyon: Quest Manager не знайдено (опціональний)", "Canyon")

func _on_all_quest_stages_completed() -> void:
	"""Обробник завершення всіх етапів квесту"""
	DebugLogger.info("🏜️ Canyon: Всі етапи квесту завершені!", "Canyon")
	# Можна додати додаткову логіку, якщо потрібно

func _on_quest_scene_unlocked(scene_name: String) -> void:
	"""Обробник розблоковування сцени"""
	DebugLogger.info("🏜️ Canyon: Сцена '%s' розблокована через Quest Manager" % scene_name, "Canyon")

func _on_quest_progress_updated(completed: int, total: int) -> void:
	"""Обробник оновлення прогресу"""
	if quest_manager and quest_manager.debug_mode:
		DebugLogger.info("🏜️ Canyon: Прогрес квесту: %d/%d діалогів" % [completed, total], "Canyon")

func can_transition_to_scene(scene_name: String) -> bool:
	"""Перевіряє, чи можна перейти до вказаної сцени"""
	if quest_manager:
		return quest_manager.can_transition_to_scene(scene_name)
	# Якщо Quest Manager немає, використовуємо стару логіку
	return true

func get_available_scenes_from_quest() -> Array[String]:
	"""Повертає список доступних сцен з Quest Manager"""
	if quest_manager:
		return quest_manager.get_available_scenes()
	return []

func _get_dialogue_manager() -> Node:
	DebugLogger.info("🏜️ Canyon: Отримуємо DialogueManager через ServiceLocator...", "Canyon")
	
	# ServiceLocator is an autoload, accessible directly
	if not ServiceLocator:
		DebugLogger.warning("🏜️ Canyon: ❌ ServiceLocator не знайдено (autoload недоступний)", "Canyon")
		return null
	
	# Wait for ServiceLocator to be ready if needed
	if not ServiceLocator.is_node_ready():
		DebugLogger.info("🏜️ Canyon: Очікуємо готовності ServiceLocator...", "Canyon")
		await ServiceLocator.ready
	
	if ServiceLocator.has_method("get_dialogue_manager"):
		var dm = ServiceLocator.get_dialogue_manager()
		if dm:
			DebugLogger.info("🏜️ Canyon: ✅ DialogueManager отримано", "Canyon")
		else:
			DebugLogger.warning("🏜️ Canyon: ❌ DialogueManager повернув null (може бути не зареєстрований в GameManager)", "Canyon")
		return dm
	else:
		DebugLogger.warning("🏜️ Canyon: ❌ ServiceLocator не має методу get_dialogue_manager", "Canyon")
	return null

# ============================================================================
# State Handlers - Конкретні дії для кожного стейту
# ============================================================================

func _on_intro_state(run_id: int) -> void:
	"""Обробка стейту INTRO - початок гри"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ INTRO ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	
	# Перевіряємо, чи діалог вже був прочитаний
	if _is_dialogue_completed("Canyon_Intro"):
		DebugLogger.info("🏜️ Canyon: ⏭️ Діалог Canyon_Intro вже був прочитаний, пропускаємо", "Canyon")
		if Game.get_singleton().has_method("set_objective"):
			Game.get_singleton().set_objective("Explore the Canyon")
		return
	
	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Запуск вступного діалогу Canyon_Intro", "Canyon")
	# Запускаємо вступний діалог
	await _execute_step(StepType.DIALOGUE, "Canyon_Intro", run_id)
	# Після діалогу
	if Game.get_singleton().has_method("set_objective"):
		Game.get_singleton().set_objective("Explore the Canyon")

func _on_monologue_state(run_id: int) -> void:
	"""Обробка стейту MONOLOGUE - монолог про діда та шамана"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ MONOLOGUE ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	
	# Перевіряємо, чи діалог вже був прочитаний
	if _is_dialogue_completed("Canyon_StartMonologue"):
		DebugLogger.info("🏜️ Canyon: ⏭️ Діалог Canyon_StartMonologue вже був прочитаний, пропускаємо", "Canyon")
		return
	
	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Запуск монологу Canyon_StartMonologue", "Canyon")
	# Запускаємо монолог
	await _execute_step(StepType.DIALOGUE, "Canyon_StartMonologue", run_id)
	# Після монологу можна відкрити першу браму або активувати наступний тригер

func _on_exploration_state(run_id: int) -> void:
	"""Обробка стейту EXPLORATION - дослідження каньону"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ EXPLORATION ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Очікування запуску діалогу Canyon_Exploration через тригер", "Canyon")
	
	# Не запускаємо автоматично. Чекаємо поки гравець активує тригер.
	# await _execute_step(StepType.DIALOGUE, "Canyon_Exploration", run_id)
	
	# Чекаємо завершення діалогу (запущеного тригером)
	if Engine.has_singleton("EventBus"):
		while true:
			var finished_id = await EventBus.dialogue_finished
			# Normalize path/id check
			if "Canyon_Exploration" in finished_id:
				DebugLogger.info("🏜️ Canyon: ✅ Діалог Canyon_Exploration завершено (через тригер)", "Canyon")
				# Важливо: позначити квест виконаним, бо _execute_step не викликався!
				_complete_quest_for_dialogue("Canyon_Exploration")
				break
			
			if run_id != state_run_id:
				return
				
	# Після діалогу:
	# - Відкриваємо браму (якщо квест виконано)
	# - Дозволяємо гравцю вільно досліджувати
	# - Катсцена спрацює при вході в зону через trigger_abduction_cutscene()
	if Game.get_singleton().has_method("set_objective"):
		Game.get_singleton().set_objective("Find a way forward")
	_after_exploration_dialogue()

func _on_abduction_cutscene_state(run_id: int) -> void:
	"""Обробка стейту CUTSCENE_ABDUCTION - катсцена викрадення"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ CUTSCENE_ABDUCTION ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	
	# Перевіряємо, чи діалог вже був прочитаний
	if _is_dialogue_completed("Canyon_AbductionCutscene"):
		DebugLogger.info("🏜️ Canyon: ⏭️ Діалог Canyon_AbductionCutscene вже був прочитаний, пропускаємо", "Canyon")
		if Game.get_singleton().has_method("set_objective"):
			Game.get_singleton().set_objective("Pursue the kidnappers")
		_after_abduction_cutscene()
		return
	
	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Запуск катсцени викрадення Canyon_AbductionCutscene", "Canyon")
	# Запускаємо катсцену викрадення
	await _execute_step(StepType.DIALOGUE, "Canyon_AbductionCutscene", run_id)
	# Після катсцени:
	# - Відкриваємо другу браму (якщо квест виконано)
	# - Готуємо перехід до села
	if Game.get_singleton().has_method("set_objective"):
		Game.get_singleton().set_objective("Pursue the kidnappers")
	_after_abduction_cutscene()

func _on_to_village_state(run_id: int) -> void:
	"""Обробка стейту TO_VILLAGE - діалог та підготовка до переходу через проходи між сценами"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ TO_VILLAGE ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	
	# Якщо ми вже були в селі (навіть трохи), не показуємо цей монолог знову
	var game = Game.get_singleton()
	if game and game.get_quest_flag("village_abduction_complete"):
		DebugLogger.info("🏜️ Canyon: Гравець вже відвідував село, пропускаємо монолог RoadToVillage", "Canyon")
		# Встановлюємо об'єктив для повернення до Village
		if game.has_method("set_objective"):
			game.set_objective("Повернутися до села")
		DebugLogger.info("🏜️ Canyon: Гравець може йти до Village через проходи між сценами (без телепорту)", "Canyon")
		return
	
	# Запускаємо короткий діалог перед переходом (тільки якщо гравець ще не був у Village)
	await _play_dialogue("RoadToVillage", run_id)
	
	# Перехід до Village здійснюється через проходи між сценами (MetSys room connections)
	# НЕ використовуємо телепорт - гравець має йти сам
	DebugLogger.info("🏜️ Canyon: Діалог завершено. Гравець може йти до Village через проходи між сценами (без телепорту)", "Canyon")
	
	# Встановлюємо об'єктив для переходу до Village
	if game and game.has_method("set_objective"):
		game.set_objective("Йти до села")

func _on_relic_pickup_state(run_id: int) -> void:
	"""Обробка стейту RELIC_PICKUP - медитація біля реліквій"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ RELIC_PICKUP ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	DebugLogger.info("🏜️ Canyon: ⏸️ Очікування активації реліквії гравцем", "Canyon")
	
	# Не запускаємо автоматично. Чекаємо поки гравець активує тригер біля реліквії.
	# Коли тригер спрацює, він повинен викликати advance_state() або змінити стейт на EXIT_CUTSCENE

func _on_exit_cutscene_state(run_id: int) -> void:
	"""Обробка стейту EXIT_CUTSCENE - катсцена спуску з каньону"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ EXIT_CUTSCENE ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	
	# Перевіряємо, чи діалог вже був прочитаний
	if _is_dialogue_completed("Canyon_ExitCutscene"):
		DebugLogger.info("🏜️ Canyon: ⏭️ Діалог Canyon_ExitCutscene вже був прочитаний, пропускаємо", "Canyon")
		if Game.get_singleton().has_method("set_objective"):
			Game.get_singleton().set_objective("Спуститися до дороги")
		_after_exit_cutscene()
		return
	
	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Запуск катсцени спуску Canyon_ExitCutscene", "Canyon")
	
	# Запускаємо катсцену спуску до дороги
	await _execute_step(StepType.DIALOGUE, "Canyon_ExitCutscene", run_id)
	
	# Після катсцени:
	# - Встановлюємо об'єктив
	# - Готуємо перехід до пустельної дороги
	if Game.get_singleton().has_method("set_objective"):
		Game.get_singleton().set_objective("Спуститися до дороги")
	
	_after_exit_cutscene()

func _on_to_desert_road_state(run_id: int) -> void:
	"""Обробка стейту TO_DESERT_ROAD - перехід до пустельної дороги"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ TO_DESERT_ROAD ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Перехід до пустельної дороги", "Canyon")
	# Виконуємо перехід
	await _execute_step(StepType.TRANSITION, "", run_id)
	# Перехід до пустельної дороги обробляється автоматично через MetSys room connections

# ============================================================================
# After-dialogue Actions - Дії після діалогів
# ============================================================================

func _after_exploration_dialogue() -> void:
	"""Дії після діалогу дослідження"""
	DebugLogger.info("🏜️ Canyon: Після діалогу дослідження", "Canyon")

func _after_abduction_cutscene() -> void:
	"""Дії після катсцени викрадення"""
	DebugLogger.info("🏜️ Canyon: Після катсцени викрадення", "Canyon")

func _after_relic_meditation() -> void:
	"""Дії після медитації біля реліквій"""
	# Можна додати логіку отримання реліквії
	DebugLogger.info("🏜️ Canyon: Після медитації - реліквія отримана", "Canyon")

func _after_exit_cutscene() -> void:
	"""Дії після катсцени спуску"""
	# Всі брами відкриті, гравець готовий до переходу
	DebugLogger.info("🏜️ Canyon: Після катсцени спуску - готово до переходу", "Canyon")

# ============================================================================
# Helper Functions - Допоміжні функції
# ============================================================================

func _is_dialogue_completed(dialogue_id: String) -> bool:
	"""Перевіряє, чи діалог вже був прочитаний (через quest flags або SaveSystem)"""
	if dialogue_id.is_empty():
		return false
	
	# Нормалізуємо dialogue_id (видаляємо шлях та розширення)
	var normalized_id = dialogue_id
	if normalized_id.contains("/"):
		normalized_id = normalized_id.get_file()
	if normalized_id.ends_with(".dqd"):
		normalized_id = normalized_id.substr(0, normalized_id.length() - 4)
	
	# 1. Перевіряємо quest flags (найнадійніший спосіб)
	var game = Game.get_singleton()
	if not game:
		DebugLogger.warning("🏜️ Canyon: Game singleton не найден при проверке диалога %s" % normalized_id, "Canyon")
		# Fallback на SaveSystem
	else:
		# Мапінг діалогів на quest flags
		var dialogue_to_flag = {
			"Canyon_Intro": "canyon_intro_complete",
			"Canyon_StartMonologue": "canyon_intro_complete",  # Монолог завершує intro
			"Canyon_Exploration": "canyon_exploration_complete",
			"Canyon_AbductionCutscene": "canyon_abduction_complete",
			"RoadToVillage": "village_abduction_complete",  # Якщо був у Village, то діалог прочитаний
			"Canyon_ExitCutscene": "canyon_exit_cutscene_complete",  # Можливо, потрібно додати цей флаг
		}
		
		if normalized_id in dialogue_to_flag:
			var flag_name = dialogue_to_flag[normalized_id]
			var completed = game.get_quest_flag(flag_name, false)
			if completed:
				DebugLogger.info("🏜️ Canyon: ✅ Діалог %s вже прочитаний (quest flag: %s)" % [normalized_id, flag_name], "Canyon")
				return true
	
	# 2. Перевіряємо SaveSystem (якщо quest flags не знайдені)
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_save_system"):
			var save_system = service_locator.get_save_system()
			if save_system and save_system.has("player_data"):
				var player_data = save_system.player_data
				if player_data.has("completed_dialogues"):
					var completed_dialogues = player_data.completed_dialogues
					# Перевіряємо різні варіанти ID
					if normalized_id in completed_dialogues or dialogue_id in completed_dialogues:
						DebugLogger.info("🏜️ Canyon: ✅ Діалог %s вже прочитаний (SaveSystem)" % normalized_id, "Canyon")
						return true
					# Також перевіряємо з шляхом
					for completed_id in completed_dialogues:
						if normalized_id in str(completed_id) or dialogue_id in str(completed_id):
							DebugLogger.info("🏜️ Canyon: ✅ Діалог %s вже прочитаний (SaveSystem, частковий збіг)" % normalized_id, "Canyon")
							return true
	
	return false

func _open_gate_if_quest_complete(quest_id: String, gate_name: String) -> void:
	"""Відкриває браму, якщо квест виконано"""
	var game = Game.get_singleton()
	if game and game.has_method("get_quest_flag"):
		var completed = game.get_quest_flag(quest_id, false)
		if completed:
			# Знаходимо GateController для цієї брами
			var gate_controller = _find_gate_controller(gate_name)
			if gate_controller:
				gate_controller.open_gate()
				DebugLogger.info("🏜️ Canyon: Брама %s відкрита (квест %s виконано)" % [gate_name, quest_id], "Canyon")
			else:
				DebugLogger.warning("🏜️ Canyon: GateController для %s не знайдено" % gate_name, "Canyon")
	else:
		DebugLogger.warning("🏜️ Canyon: Game.get_singleton() не доступний або не має методу get_quest_flag", "Canyon")

func _find_gate_controller(gate_name: String) -> Node:
	"""Знаходить GateController для брами"""
	# Спочатку шукаємо в дітях поточного вузла (якщо ми в Canyon)
	for child in get_children():
		if child.has_method("open_gate") and child.get("gate_layer_name") == gate_name:
			return child
			
	var scene = get_tree().current_scene
	if not scene:
		return null
	
	# Шукаємо GateController серед дочірніх вузлів сцени
	for child in scene.get_children():
		if child.has_method("open_gate") and child.get("gate_layer_name") == gate_name:
			return child
		# Також шукаємо в глибину (один рівень)
		for grandchild in child.get_children():
			if grandchild.has_method("open_gate") and grandchild.get("gate_layer_name") == gate_name:
				return grandchild
	
	return null

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	"""Завершує квест на основі діалогу"""
	var quest_id = ""
	
	match dialogue_id:
		"Canyon_StartMonologue":
			quest_id = "canyon_intro_complete"
		"Canyon_Exploration":
			quest_id = "canyon_exploration_complete"
		"Canyon_AbductionCutscene":
			quest_id = "canyon_abduction_complete"
		"RoadToVillage":
			# Додаємо про всяк випадок, якщо це останній діалог перед переходом
			quest_id = "canyon_abduction_complete" 
		"Canyon_MeditationAtRelic":
			quest_id = "canyon_relic_meditation_complete"
		"Canyon_ExitCutscene":
			quest_id = "canyon_exit_complete"
		_:
			# Якщо діалог не має відповідного квеста, не робимо нічого
			DebugLogger.info("🏜️ Canyon: Діалог %s не пов'язаний з квестами" % dialogue_id, "Canyon")
			return
	
	if not quest_id.is_empty():
		_complete_quest(quest_id)

func _complete_quest(quest_id: String) -> void:
	"""Завершує квест і встановлює флаг"""
	var game = Game.get_singleton()
	if game and game.has_method("set_quest_flag"):
		# Встановлюємо флаг завершення квеста (quest_id вже містить _complete зазвичай)
		game.set_quest_flag(quest_id, true)
		DebugLogger.info("🏜️ Canyon: Квест %s завершено" % quest_id, "Canyon")

func _wait_for_quest_flags_loaded() -> void:
	"""Ждет загрузки quest flags перед определением состояния"""
	var game = Game.get_singleton()
	if not game:
		DebugLogger.warning("🏜️ Canyon: Game singleton не найден, пропускаем ожидание quest flags", "Canyon")
		return
	
	# Проверяем что quest flags загружены (не пустой словарь если это загрузка сохранения)
	# Для новой игры quest_flags будет пустым, это нормально
	var max_wait_frames = 20  # Максимум 20 кадров (~0.3 секунды)
	var wait_count = 0
	
	# Если это загрузка сохранения, ждем пока quest flags не будут загружены
	if game.loaded_from_save:
		DebugLogger.info("🏜️ Canyon: Ожидаем загрузки quest flags из сохранения...", "Canyon")
		while wait_count < max_wait_frames:
			# Проверяем что quest_flags не пустой (значит загружены)
			# или что SaveSystem уже загрузил данные
			if game.quest_flags.size() > 0:
				DebugLogger.info("🏜️ Canyon: ✅ Quest flags загружены (%d флагов)" % game.quest_flags.size(), "Canyon")
				return
			
			# Также проверяем через SaveSystem
			if Engine.has_singleton("ServiceLocator"):
				var service_locator = Engine.get_singleton("ServiceLocator")
				if service_locator and service_locator.has_method("get_save_system"):
					var save_system = service_locator.get_save_system()
					if save_system and save_system.has("player_data"):
						var player_data = save_system.player_data
						if player_data.has("flags") and player_data.flags.has("quest_flags"):
							if player_data.flags.quest_flags.size() > 0:
								DebugLogger.info("🏜️ Canyon: ✅ Quest flags загружены через SaveSystem", "Canyon")
								return
			
			await get_tree().process_frame
			wait_count += 1
		
		DebugLogger.warning("🏜️ Canyon: ⚠️ Quest flags не загружены за %d кадров, продолжаем..." % max_wait_frames, "Canyon")
	else:
		# Для новой игры quest flags будут пустыми, это нормально
		DebugLogger.info("🏜️ Canyon: Новая игра, quest flags будут пустыми", "Canyon")
