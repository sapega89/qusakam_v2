extends "res://SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd"

## 🏜️ Canyon Scene Manager
## States: INTRO, MONOLOGUE, EXPLORATION, CUTSCENE_ABDUCTION, TO_VILLAGE, RELIC_PICKUP, TO_DESERT_ROAD
## Машина станів — RoomStoryFlow; тут — свій _ready (брами), свої кат-сцени й «прочитано» без руху далі.

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

const Cutscene = preload("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd")

var _previous_state: State = State.INTRO  # Предыдущее состояние для события

var _canyon_ready_called: bool = false
var _canyon_ready_room: String = ""

func _ready() -> void:
	print("🏜️ [Canyon] ========== _ready() ВИКЛИКАНО ==========")
	DebugLogger.info("🏜️ Canyon: ========== _ready() ВИКЛИКАНО ==========", "Canyon")

	# Перевіряємо, чи це повторний виклик для тієї ж кімнати
	var current_room = ""
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

	# Реєстри ServiceLocator заповнюються відкладено — кадр, щоб DialogueManager уже був зареєстрований.
	await get_tree().process_frame

	# Перевіряємо та створюємо GateControllers ПЕРЕД визначенням стейту
	_ensure_gate_controllers()

	# Чекаємо кілька кадрів, щоб GateControllers ініціалізувалися
	await get_tree().process_frame
	await get_tree().process_frame

	# Прапорці зі слота завантажує Game._initialize_save_and_room() ще до load_room(),
	# тож тут вони вже є — чекати не треба.
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
	village_left_complete = game.get_quest_flag("village_left_complete", false)

	for gate_name in gates_config:
		if not _find_gate_controller(gate_name):
			var controller = GateController.new()
			controller.gate_layer_name = gate_name
			controller.required_quest_id = gates_config[gate_name]

			# Визначаємо початковий стан на основі quest flags
			# Якщо гравець повернувся з Village, ворота мають бути відкриті
			var should_be_open = false
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
			if controller:
				var quest_flag = gates_config[gate_name]
				var should_be_open = game.get_quest_flag(quest_flag, false)
				if village_left_complete:
					should_be_open = true

				# open_gate/close_gate самі відкладають команду (_pending_open_state), якщо брама ще не готова
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

	# Квестові прапорці вже завантажено (Game._initialize_save_and_room).
	var game := Game.get_singleton()
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

	if game.get_quest_flag("canyon_intro_complete", false):
		_previous_state = State.MONOLOGUE
		current_state = State.EXPLORATION
		DebugLogger.info("🏜️ Canyon: ✅ Intro finished, setting state to EXPLORATION", "Canyon")
		return

	# Жодного прапорця — це нова гра.
	DebugLogger.info("🏜️ Canyon: ✅ Starting scene detected, setting state to INTRO", "Canyon")
	current_state = State.INTRO

func trigger_abduction_cutscene() -> void:
	"""Вызывается из Area2D триггера при входе в зону катсцены"""
	if current_state == State.EXPLORATION:
		current_state = State.CUTSCENE_ABDUCTION

## Кат-сцена спуску (CanyonExitTrigger на краю плато біля містка, D256). Лише після повернення з села;
## повертає, чи запущено.
func trigger_exit_cutscene() -> bool:
	if current_state != State.RELIC_PICKUP:
		return false
	current_state = State.EXIT_CUTSCENE
	return true

func _on_state_changed(new_state: int) -> void:
	"""Вызывается при изменении current_state через setter"""
	if not is_node_ready():
		return

	# Оновлюємо ворота при кожній зміні стану
	# Використовуємо call_deferred, щоб переконатися, що GateControllers готові
	call_deferred("_update_gates_for_state", new_state)
	# TO_VILLAGE після села лише ставить ціль «Return to the village» (_on_to_village_state) — без авто-переходу.
	super(new_state)

func _announce_state(new_state: int) -> void:
	"""Эмитит событие смены состояния через EventBus"""
	EventBus.scene_state_changed.emit(room_id(), State.keys()[_previous_state], State.keys()[new_state])
	_previous_state = new_state as State

func _dialogue_flags() -> Dictionary:
	return {
		"Canyon_StartMonologue": "canyon_intro_complete",
		"Canyon_Exploration": "canyon_exploration_complete",
		"Canyon_AbductionCutscene": "canyon_abduction_complete",
		"Canyon_ExitCutscene": "canyon_exit_complete",
	}

func _apply_state_logic(state: int, run_id: int) -> void:
	match state:
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

## Діалог стану. Прочитаний (_is_dialogue_completed) не повторюється і далі НЕ веде; дограний — веде далі,
## крім EXPLORATION і CUTSCENE_ABDUCTION: ті чекають тригера зони або дій гравця.
func _dialogue_step(dialogue_id: String, run_id: int, in_cloud: bool = false) -> void:
	if _is_dialogue_completed(dialogue_id):
		DebugLogger.info("🏜️ Canyon: ⏭️ Діалог %s вже був прочитаний, пропускаємо" % dialogue_id, "Canyon")
		return
	await _play_dialogue(dialogue_id, run_id, in_cloud)
	# Прапорець — і тоді, коли стан змінився посеред діалогу.
	_complete_quest_for_dialogue(dialogue_id)
	if run_id != state_run_id:
		DebugLogger.info("🏜️ Canyon: ⚠️ Стейт змінився під час виконання дії, перериваємо", "Canyon")
		return
	if current_state != State.EXPLORATION and current_state != State.CUTSCENE_ABDUCTION:
		advance_state()

var _is_dialogue_playing: bool = false

## Один діалог зараз: другий запит, поки грає перший, відкидається.
func _play_dialogue(dialogue_id: String, run_id: int, in_cloud: bool = false) -> bool:
	if state_run_id != run_id or dialogue_id.is_empty():
		return false

	if _is_dialogue_playing:
		DebugLogger.info("🏜️ Canyon: Діалог %s проігноровано, вже програється інший" % dialogue_id, "Canyon")
		return false

	_is_dialogue_playing = true
	var finished: bool = await super(dialogue_id, run_id, in_cloud)
	# B154: розмова скінчилась — прапорець знімаємо ДО паузи. За ці 0.1 с спрацьовують тригери, що чекали
	# кінця розмови (D737), і діалог стану, який вони вмикають, раніше відкидався тут як «вже програється інший».
	_is_dialogue_playing = false
	if finished:
		# Додаємо невелику затримку після завершення діалогу
		await get_tree().create_timer(0.1).timeout
	return finished

func set_state_for_relic_pickup() -> void:
	"""Вызывается при возврате из деревни для подбора реликвии"""
	current_state = State.RELIC_PICKUP

func _connect_to_quest_events() -> void:
	"""Підписується на події зміни quest flags для реакції на завершення діалогів в інших сценах"""
	var game := Game.get_singleton()
	if not game.quest_flag_changed.is_connected(_on_quest_flag_changed):
		game.quest_flag_changed.connect(_on_quest_flag_changed)

func _on_quest_flag_changed(quest_id: String, value: Variant) -> void:
	"""Обробник зміни quest flag - реагує на завершення діалогів в інших сценах"""
	# Якщо гравець завершив останній діалог в Village, змінюємо стан на RELIC_PICKUP
	if quest_id == "village_left_complete" and value == true:
		# Перевіряємо, чи ми зараз в Canyon
		var current_room = ""
		current_room = MetSys.get_current_room_name()

		if "Canyon" in current_room or current_room.is_empty():
			# Змінюємо стан на RELIC_PICKUP, якщо ще не в цьому стані
			if current_state != State.RELIC_PICKUP:
				DebugLogger.info("🏜️ Canyon: Quest flag 'village_left_complete' встановлено - змінюємо стан на RELIC_PICKUP", "Canyon")
				current_state = State.RELIC_PICKUP
				_previous_state = State.TO_VILLAGE

# ============================================================================
# State Handlers - Конкретні дії для кожного стейту
# ============================================================================

func _on_intro_state(run_id: int) -> void:
	"""Обробка стейту INTRO - початок гри"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ INTRO ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")

	# Перевіряємо, чи діалог вже був прочитаний
	if _is_dialogue_completed("Canyon_Intro"):
		DebugLogger.info("🏜️ Canyon: ⏭️ Діалог Canyon_Intro вже був прочитаний, пропускаємо", "Canyon")
		Game.get_singleton().set_objective("Explore the Canyon", &"shrine")
		return

	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Запуск вступного діалогу Canyon_Intro", "Canyon")
	# Запускаємо вступний діалог
	await _dialogue_step("Canyon_Intro", run_id)
	# Після діалогу
	Game.get_singleton().set_objective("Explore the Canyon", &"shrine")

func _on_monologue_state(run_id: int) -> void:
	"""Обробка стейту MONOLOGUE - монолог про діда та шамана"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ MONOLOGUE ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")

	# Перевіряємо, чи діалог вже був прочитаний
	if _is_dialogue_completed("Canyon_StartMonologue"):
		DebugLogger.info("🏜️ Canyon: ⏭️ Діалог Canyon_StartMonologue вже був прочитаний, пропускаємо", "Canyon")
		return

	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Запуск монологу Canyon_StartMonologue", "Canyon")
	# Запускаємо монолог
	await _dialogue_step("Canyon_StartMonologue", run_id)
	# Після монологу можна відкрити першу браму або активувати наступний тригер

func _on_exploration_state(run_id: int) -> void:
	"""Обробка стейту EXPLORATION - дослідження каньону"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ EXPLORATION ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Очікування запуску діалогу Canyon_Exploration через тригер", "Canyon")

	# Нічого не запускаємо: MeditationTrigger на вершині скелі переводить у CUTSCENE_ABDUCTION —
	# медитація, а за нею викрадення (Sapega, 2026-10-20: «має бути сенс для того щоб піднятись на гору»).

## Медитація на вершині скелі (Sapega, 2026-10-20): MeditationTrigger забирає керування, Кусакам підходить до
## каменя (Meditation/Seat), Canyon_Exploration, сідає й дихає (Meditate), камера пливе вліво до Meditation/Look,
## затемнення — напад на село поверх чорного (VillageAbduction), він встає ще в темряві, світло, камера
## повертається до нього, Canyon_AbductionCutscene облачком над ним (D263). Кожен діалог ставить героя в Idle і віддає керування — поза й блокування вертаються.
const MEDITATION_WALK_TIME := 0.6
const MEDITATION_SIT_HOLD := 1.5
const MEDITATION_PAN_TIME := 3.5
const MEDITATION_LOOK_HOLD := 1.0
const MEDITATION_RETURN_TIME := 1.2
## D815: тема туторіалу, якою перша медитація каже, що в героя є навички (tutorial.json).
const STARTING_SKILLS_TOPIC := "starting_skills"

func _on_abduction_cutscene_state(run_id: int) -> void:
	var game := Game.get_singleton()
	if _is_dialogue_completed("Canyon_AbductionCutscene"):
		game.set_objective("Pursue the kidnappers", &"village")
		_after_abduction_cutscene()
		return

	var cs := Cutscene.new()
	await cs.walk_hero($Meditation/Seat.global_position, MEDITATION_WALK_TIME)
	await _dialogue_step("Canyon_Exploration", run_id)
	if run_id != state_run_id:
		return
	game.set_objective("Find a way forward")

	# Сідає обличчям до села (вліво) — туди ж попливе камера.
	cs.player.get_node(^"Sprite2D").flip_h = true
	cs.set_pose(&"Meditate")
	await cs.wait(MEDITATION_SIT_HOLD)
	# D815: у медитації прокидаються блок і хіл, з якими він почав, — і гра каже, які вони, на які кнопки й де решта.
	ServiceLocator.get_skill_manager().awaken_skills()
	await _tell_starting_skills()
	await cs.pan_to($Meditation/Look.global_position, MEDITATION_PAN_TIME)
	await cs.wait(MEDITATION_LOOK_HOLD)

	# Напад на село — затемнення, репліки поверх чорного, світло; потім Кусакам дивиться з хребта
	# (Sapega, 2026-10-16: «кат сцена має бути не в віледжі а в каньйоні з затемненням»).
	await ScreenFade.to_black(self)
	await _play_dialogue("VillageAbduction", run_id)
	# Встає з диска ще в темряві: коли світло й камера вертаються в каньйон, він уже стоїть (D263).
	cs.set_pose(&"Idle")
	await ScreenFade.from_black(self)
	await cs.camera_back(MEDITATION_RETURN_TIME)
	# Розмова — у білому облачці над ним, керування заблоковане до її кінця (D263).
	await _dialogue_step("Canyon_AbductionCutscene", run_id, true)
	cs.end()
	game.set_objective("Pursue the kidnappers", &"village")
	_after_abduction_cutscene()

## D815: тема «Your Skills» — «?» і одразу її вікно (TipTray, D744), гра на паузі, доки гравець його не закрив.
## Hints Off (D746) чи тему вже бачили в цьому проходженні (D745) — нічого. Вікно не відкрилось (гра не вільна) —
## «?» чекає, як кожна підказка.
func _tell_starting_skills() -> void:
	var tray: Node = get_tree().get_first_node_in_group(&"tip_tray")
	tray.show_tip(STARTING_SKILLS_TOPIC)
	if not tray.has(STARTING_SKILLS_TOPIC):
		return
	tray.open_tip(STARTING_SKILLS_TOPIC)
	if not tray.has(STARTING_SKILLS_TOPIC):
		await ServiceLocator.get_ui_manager().get_modal_layer().modal_closed

func _on_to_village_state(run_id: int) -> void:
	"""Обробка стейту TO_VILLAGE - діалог та підготовка до переходу через проходи між сценами"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ TO_VILLAGE ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")

	# Якщо ми вже були в селі (навіть трохи), не показуємо цей монолог знову
	var game = Game.get_singleton()
	if game.get_quest_flag("village_abduction_complete"):
		DebugLogger.info("🏜️ Canyon: Гравець вже відвідував село, пропускаємо монолог RoadToVillage", "Canyon")
		# Встановлюємо об'єктив для повернення до Village
		game.set_objective("Return to the village", &"village")
		DebugLogger.info("🏜️ Canyon: Гравець може йти до Village через проходи між сценами (без телепорту)", "Canyon")
		return

	# Запускаємо короткий діалог перед переходом (тільки якщо гравець ще не був у Village)
	await _play_dialogue("RoadToVillage", run_id)

	# Перехід до Village здійснюється через проходи між сценами (MetSys room connections)
	# НЕ використовуємо телепорт - гравець має йти сам
	DebugLogger.info("🏜️ Canyon: Діалог завершено. Гравець може йти до Village через проходи між сценами (без телепорту)", "Canyon")

	# Встановлюємо об'єктив для переходу до Village
	game.set_objective("Head to the village", &"village")

func _on_relic_pickup_state(run_id: int) -> void:
	"""Обробка стейту RELIC_PICKUP - медитація біля реліквій"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ RELIC_PICKUP ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	DebugLogger.info("🏜️ Canyon: ⏸️ Очікування активації реліквії гравцем", "Canyon")

	# Не запускаємо автоматично. Чекаємо поки гравець активує тригер біля реліквії.
	# Коли тригер спрацює, він повинен викликати advance_state() або змінити стейт на EXIT_CUTSCENE

## Кат-сцена спуску (D256, Sapega «я не хочу падати з мосту»): керування забрано, місток падає, Кусакам
## каже своє, підходить до краю й злазить униз за камінь переднього плану (ForegroundRock), камера пливе
## вгору до неба (HighSky, жовте до виходу з Лабораторії — D864), затемнення — і він у печері під мостом (M7, граф Каньйону: «спуск ↓, згори лише
## вниз»): звідти провалами вниз до виходу з печери на дорогу. Герой не падає й не дістає шкоди: його
## фізика стоїть (event), рух — твінами між мітками Descent/Edge і Descent/Below. Прочитаний діалог не повторюється.
const DESCENT_WALK_TIME := 0.7
const DESCENT_CLIMB_TIME := 2.6
const DESCENT_PAUSE := 0.5
const DESCENT_PAN_TIME := 4.0
const DESCENT_SKY_HOLD := 1.2
const CAVE_UNDER_BRIDGE := "res://SampleProject/Maps/CaveUnderBridge.tscn"

func _on_exit_cutscene_state(run_id: int) -> void:
	var game := Game.get_singleton()
	game.preload_room(CAVE_UNDER_BRIDGE)  # кат-сцена довга — печера встигне завантажитись у фоні (performance_plan, slice 3)
	var cs := Cutscene.new()
	cs.detach_camera()
	if not $Bridge.is_collapsed():
		await $Bridge.collapse()
	if not _is_dialogue_completed("Canyon_ExitCutscene"):
		await _play_dialogue("Canyon_ExitCutscene", run_id)
		cs.hold()
	game.set_objective("Descend to the road")

	await cs.walk_hero($Descent/Edge.global_position, DESCENT_WALK_TIME)
	# Спуск іде нижче підлоги: камера знову бачить усю нижню клітинку (D483 підняв її межу до підлоги)
	cs.camera.limit_bottom = int($RoomInstance.get_size().y)
	cs.set_pose(&"Climb")
	await cs.move(cs.player, $Descent/Below.global_position, DESCENT_CLIMB_TIME, Tween.TRANS_SINE)
	cs.set_pose(&"Idle")
	await cs.wait(DESCENT_PAUSE)

	# Небо над кімнатою — лише для цього кадру: камера підіймається до самого верху HighSky.
	var sky_top: float = $HighSky.global_position.y
	cs.camera.limit_top = int(sky_top)
	var sky_center: float = sky_top + get_viewport_rect().size.y / cs.camera.zoom.y / 2.0
	await cs.pan_to(Vector2(cs.camera.global_position.x, sky_center), DESCENT_PAN_TIME)
	await cs.wait(DESCENT_SKY_HOLD)
	await ScreenFade.to_black(self)

	# Межі камери виставить нова кімната. Після телепорту цієї кімнати вже немає: телепорт не чекаємо (жодного
	# await на ній), світло після заміни кімнати повертає сам Game.load_room() (D434).
	game.teleport_to_room(CAVE_UNDER_BRIDGE, ^"Arrival")
	cs.end()

func _on_to_desert_road_state(run_id: int) -> void:
	"""Обробка стейту TO_DESERT_ROAD - перехід до пустельної дороги"""
	DebugLogger.info("🏜️ Canyon: ========== СТЕЙТ TO_DESERT_ROAD ЗАПУЩЕНО (RunID: %d) ==========" % run_id, "Canyon")
	DebugLogger.info("🏜️ Canyon: 📍 ДІЯ: Перехід до пустельної дороги", "Canyon")
	# Виконуємо перехід
	await get_tree().create_timer(0.5).timeout
	if run_id == state_run_id:
		advance_state()
	# Перехід до пустельної дороги обробляється автоматично через MetSys room connections

# ============================================================================
# After-dialogue Actions - Дії після діалогів
# ============================================================================

func _after_abduction_cutscene() -> void:
	"""Дії після катсцени викрадення"""
	DebugLogger.info("🏜️ Canyon: Після катсцени викрадення", "Canyon")

func _after_relic_meditation() -> void:
	"""Дії після медитації біля реліквій"""
	# Можна додати логіку отримання реліквії
	DebugLogger.info("🏜️ Canyon: Після медитації - реліквія отримана", "Canyon")

# ============================================================================
# Helper Functions - Допоміжні функції
# ============================================================================

func _is_dialogue_completed(dialogue_id: String) -> bool:
	"""Перевіряє, чи діалог вже був прочитаний (за quest flags)"""
	var dialogue_to_flag := {
		"Canyon_Intro": "canyon_intro_complete",
		"Canyon_StartMonologue": "canyon_intro_complete",  # Монолог завершує intro
		"Canyon_Exploration": "canyon_exploration_complete",
		"Canyon_AbductionCutscene": "canyon_abduction_complete",
		"RoadToVillage": "village_abduction_complete",  # Якщо був у Village, то діалог прочитаний
		# Цей прапорець ставить _complete_quest_for_dialogue(); раніше тут стояв
		# canyon_exit_cutscene_complete, якого не ставить ніхто — кат-сцена вважалась непрочитаною.
		"Canyon_ExitCutscene": "canyon_exit_complete",
	}
	var normalized_id := dialogue_id.get_file().trim_suffix(".dqd")
	return dialogue_to_flag.has(normalized_id) and Game.get_singleton().get_quest_flag(dialogue_to_flag[normalized_id], false)

func _open_gate_if_quest_complete(quest_id: String, gate_name: String) -> void:
	"""Відкриває браму, якщо квест виконано"""
	var game = Game.get_singleton()
	if game.get_quest_flag(quest_id, false):
		var gate_controller = _find_gate_controller(gate_name)
		gate_controller.open_gate()
		DebugLogger.info("🏜️ Canyon: Брама %s відкрита (квест %s виконано)" % [gate_name, quest_id], "Canyon")

func _find_gate_controller(gate_name: String) -> Node:
	"""Знаходить GateController для брами"""
	# Спочатку шукаємо в дітях поточного вузла (якщо ми в Canyon)
	for child in get_children():
		if child is GateController and child.get("gate_layer_name") == gate_name:
			return child

	var scene = get_tree().current_scene
	if not scene:
		return null

	# Шукаємо GateController серед дочірніх вузлів сцени
	for child in scene.get_children():
		if child is GateController and child.get("gate_layer_name") == gate_name:
			return child
		# Також шукаємо в глибину (один рівень)
		for grandchild in child.get_children():
			if grandchild is GateController and grandchild.get("gate_layer_name") == gate_name:
				return grandchild

	return null
