extends Node2D

## 🏘️ Village Scene Manager
## States: ABDUCTION_CUTSCENE, ARRIVAL, STREET_FIGHT, OLD_MAN_OUTSIDE, OLD_MAN_HEALING, OLD_MAN_DECISION, LEAVING_VILLAGE
## Follows Robust State-Flow Pattern

enum State {
	ABDUCTION_CUTSCENE,
	ARRIVAL,
	STREET_FIGHT,
	OLD_MAN_OUTSIDE,
	OLD_MAN_HEALING,
	OLD_MAN_DECISION,
	LEAVING_VILLAGE
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.ABDUCTION_CUTSCENE:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0
signal state_complete(state: State)

# Опціональний Quest Manager для відстеження прогресу
@onready var quest_manager: SceneQuestManager = get_node_or_null("SceneQuestManager")

func _ready() -> void:
	# ServiceLocator — autoload, а не Engine-синглтон: has_singleton() тут завжди
	# давав false, тож очікування не відбувалося взагалі.
	if ServiceLocator and not ServiceLocator.is_node_ready():
		await ServiceLocator.ready
	DebugLogger.info("🏘️ Village: ServiceLocator готовий", "Village")

	# Ініціалізуємо Quest Manager (якщо є)
	_initialize_quest_manager()
	
	# Тільки _determine_initial_state(): присвоєння current_state саме по собі
	# запускає сеттер → _on_state_changed(). Додатковий ручний виклик стартував
	# той самий стан ДВІЧІ — другий start_dialogue() перебивав перший і
	# DialogueQuest ішов у "Auto-recovering: Dialogue was active but hidden",
	# ховаючи вікно. Гравець лишався в ABDUCTION_CUTSCENE без жодного способу
	# його завершити, а тригери ARRIVAL/OLD_MAN_OUTSIDE відсіювались по стану.
	_determine_initial_state()

func _determine_initial_state() -> void:
	"""Визначає початковий стейт на основі квестових флагів"""
	var game = Game.get_singleton()
	if not game:
		# Без Game прапорців не прочитати — стартуємо з початку сцени,
		# але стан ВИСТАВИТИ треба, інакше логіка не запуститься взагалі.
		current_state = State.ABDUCTION_CUTSCENE
		return

	if game.get_quest_flag("village_left_complete"):
		current_state = State.LEAVING_VILLAGE
	elif game.get_quest_flag("village_oldman_complete"):
		current_state = State.OLD_MAN_DECISION
	elif game.get_quest_flag("village_fight_complete"):
		current_state = State.OLD_MAN_OUTSIDE
	elif game.get_quest_flag("village_arrival_complete"):
		current_state = State.STREET_FIGHT
	elif game.get_quest_flag("village_abduction_complete"):
		current_state = State.ARRIVAL
	else:
		current_state = State.ABDUCTION_CUTSCENE
	
	DebugLogger.info("🏘️ Village: Initial state determined as %s" % State.keys()[current_state], "Village")

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	DebugLogger.info("🏘️ Village: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	
	_emit_state_changed_event(new_state)
	_apply_state_logic(new_state, run_id)

func _emit_state_changed_event(new_state: State) -> void:
	var state_name = State.keys()[new_state]
	# EventBus — autoload; has_singleton() тут завжди був false, тож подія про
	# зміну стану сцени не відправлялась жодного разу.
	EventBus.scene_state_changed.emit("Village", "", state_name)

func get_current_state_name() -> String:
	"""Повертає назву поточного стейту для тригерів"""
	return State.keys()[current_state]

func change_state_by_name(state_name: String) -> void:
	"""Змінює стейт за назвою (викликається тригерами)"""
	for i in range(State.size()):
		if State.keys()[i] == state_name:
			current_state = i as State
			return
	DebugLogger.warning("🏘️ Village: Стейт %s не знайдено!" % state_name, "Village")

func _apply_state_logic(state: State, run_id: int) -> void:
	var game = Game.get_singleton()
	
	match state:
		# УВАГА: гілки "вже пройдено" МУСЯТЬ викликати advance_state().
		# Ланцюг станів рухається тільки через нього (див. сеттер current_state),
		# тож голий return зупиняв машину назавжди: гравець говорив з дідом,
		# наступний стан бачив уже виставлений прапорець, мовчки виходив — і
		# LeavingVillage не запускався ніколи, а з ним і village_left_complete.
		State.ABDUCTION_CUTSCENE:
			if game and game.get_quest_flag("village_abduction_complete"):
				DebugLogger.info("🏘️ Village: Катсцена викрадення вже відбулася, пропускаємо", "Village")
				advance_state()
				return
			_set_objective("Дослідити село")
			# Автоматична катсцена при вході
			_execute_step(StepType.DIALOGUE, "VillageAbduction", run_id)
		State.ARRIVAL:
			_set_objective("Дійти до центру села")
			# Очікуємо поки гравець дійде до тригера "ArrivalToVillage"
			DebugLogger.info("🏘️ Village: Очікуємо тригера прибуття (ARRIVAL)", "Village")
			pass
		State.STREET_FIGHT:
			if game and game.get_quest_flag("village_fight_complete"):
				DebugLogger.info("🏘️ Village: Бій вже відбувся, пропускаємо", "Village")
				advance_state()
				return
			_set_objective("Перемогти бандита на вулиці")
			# Бій запускається автоматично або через тригер
			_execute_step(StepType.COMBAT, "FightWithBandit", run_id)
		State.OLD_MAN_OUTSIDE:
			_set_objective("Підійти до діда під деревом")
			# Очікуємо поки гравець підійде до діда під деревом
			DebugLogger.info("🏘️ Village: Очікуємо тригера біля діда (OLD_MAN_OUTSIDE)", "Village")
			pass
		State.OLD_MAN_HEALING:
			# Окремого прапорця для цього кроку немає, тож він ділить
			# village_oldman_complete з OldMan_Outside — а той ставиться раніше.
			# Через це крок завжди пропускається; важливо хоча б не застрягти.
			if game and game.get_quest_flag("village_oldman_complete"):
				DebugLogger.info("🏘️ Village: Гілка діда вже завершена, пропускаємо", "Village")
				advance_state()
				return
			_set_objective("Допомогти діду")
			_execute_step(StepType.DIALOGUE, "OldMan_Healing", run_id)
		State.OLD_MAN_DECISION:
			if game and game.get_quest_flag("village_oldman_complete"):
				advance_state()
				return
			_set_objective("Прийняти рішення")
			_execute_step(StepType.DIALOGUE, "OldMan_Decision", run_id)
		State.LEAVING_VILLAGE:
			if game and game.get_quest_flag("village_left_complete"):
				return  # останній стан, просувати нікуди
			_set_objective("Покинути село")
			_execute_step(StepType.DIALOGUE, "LeavingVillage", run_id)

func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
	match type:
		StepType.DIALOGUE:
			await _play_dialogue(dialogue_id, run_id)
		StepType.COMBAT:
			await _play_dialogue(dialogue_id, run_id)
		StepType.LOOP:
			await get_tree().create_timer(1.0).timeout
		StepType.TRANSITION:
			await get_tree().create_timer(0.5).timeout
	
	if run_id != state_run_id: return
	
	# Не переходимо автоматично зі стейтів, які чекають на тригер
	if current_state != State.ARRIVAL and current_state != State.OLD_MAN_OUTSIDE:
		advance_state()

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	var dm = _get_dialogue_manager()
	if not dm: return

	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	dm.start_dialogue(path)

	# УВАГА: тут НЕ можна питати Engine.has_singleton("EventBus").
	# EventBus — це autoload, тобто вузол /root/EventBus, а не Engine-синглтон,
	# тож has_singleton() завжди повертав false. Через це цикл очікування не
	# виконувався жодного разу: _play_dialogue() виходив одразу після
	# start_dialogue(), _execute_step() робив advance_state(), і вся машина
	# станів Village пролітала до кінця, не програвши діалогів і не викликавши
	# _complete_quest_for_dialogue() — тому жоден village-прапорець не ставився.
	while true:
		var finished_id = await EventBus.dialogue_finished
		if finished_id == path or finished_id == dialogue_id:
			# Завершуємо квест після діалогу
			_complete_quest_for_dialogue(dialogue_id)
			break
		if run_id != state_run_id: return

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	"""Встановлює квестові флаги для діалогів у селі"""
	var game = Game.get_singleton()
	if not game or not game.has_method("set_quest_flag"):
		return
		
	var quest_flag = ""
	match dialogue_id:
		"VillageAbduction":
			quest_flag = "village_abduction_complete"
		"ArrivalToVillage":
			quest_flag = "village_arrival_complete"
		"FightWithBandit":
			quest_flag = "village_fight_complete"
		"OldMan_Outside":
			quest_flag = "village_oldman_complete"
		"LeavingVillage":
			quest_flag = "village_left_complete"
			
	if not quest_flag.is_empty():
		game.set_quest_flag(quest_flag, true)
		DebugLogger.info("🏘️ Village: Квест %s виконано" % quest_flag, "Village")

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.LEAVING_VILLAGE:
		current_state = (current_state + 1) as State
	else:
		# Сцена завершена - гравець може вільно переміщатися
		# Перехід до інших сцен обробляється автоматично через MetSys room connections
		DebugLogger.info("🏘️ Village: Сцена завершена - переходи обробляються через MetSys room connections", "Scene")

func _set_objective(text: String) -> void:
	"""Встановлює об'єктив для гравця"""
	var game = Game.get_singleton()
	if game and game.has_method("set_objective"):
		game.set_objective(text)

func _initialize_quest_manager() -> void:
	"""Ініціалізує Quest Manager (якщо він є в сцені)"""
	if quest_manager:
		quest_manager.all_stages_completed.connect(_on_all_quest_stages_completed)
		quest_manager.scene_unlocked.connect(_on_quest_scene_unlocked)
		quest_manager.progress_updated.connect(_on_quest_progress_updated)
		DebugLogger.info("🏘️ Village: Quest Manager ініціалізовано", "Village")
	else:
		DebugLogger.info("🏘️ Village: Quest Manager не знайдено (опціональний)", "Village")

func _on_all_quest_stages_completed() -> void:
	"""Обробник завершення всіх етапів квесту"""
	DebugLogger.info("🏘️ Village: Всі етапи квесту завершені!", "Village")
	# Можна додати додаткову логіку, якщо потрібно

func _on_quest_scene_unlocked(scene_name: String) -> void:
	"""Обробник розблоковування сцени"""
	DebugLogger.info("🏘️ Village: Сцена '%s' розблокована через Quest Manager" % scene_name, "Village")

func _on_quest_progress_updated(completed: int, total: int) -> void:
	"""Обробник оновлення прогресу"""
	if quest_manager and quest_manager.debug_mode:
		DebugLogger.info("🏘️ Village: Прогрес квесту: %d/%d діалогів" % [completed, total], "Village")

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
	# ServiceLocator — autoload (/root/ServiceLocator), а не Engine-синглтон.
	# Engine.has_singleton() для нього завжди false, тож раніше цей метод
	# ЗАВЖДИ повертав null: _play_dialogue() виходив на `if not dm: return`,
	# _execute_step() одразу викликав advance_state(), і вся машина станів
	# пролітала до кінця без жодного діалогу і без жодного прапорця.
	if ServiceLocator:
		return ServiceLocator.get_dialogue_manager()
	DebugLogger.warning("🏘️ Village: ServiceLocator недоступний", "Village")
	return null
