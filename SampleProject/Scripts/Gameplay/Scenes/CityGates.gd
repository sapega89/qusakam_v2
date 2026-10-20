extends Node2D

## Ключ підказки TutorialHintDisplay для охоронця (D209).
const CALL_GUARD := "call_guard"
const COMPANIONS_HINT := "companions"

## 🏰 City Gates Scene Manager
## States: INTRO_DIALOGUE, FIGHT_LOOP, AFTER_FIGHT_DIALOGUE, TO_CITY

enum State {
	INTRO_DIALOGUE,
	FIGHT_LOOP,
	AFTER_FIGHT_DIALOGUE,
	TO_CITY
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.INTRO_DIALOGUE:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0
signal state_complete(state: State)

# Enemy spawner reference
var enemy_spawner: RoomEnemySpawner = null

func _ready() -> void:
	var loc = ServiceLocator
	if not loc.is_node_ready():
		await loc.ready

	# Находим EnemySpawner
	enemy_spawner = $EnemySpawner
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	DebugLogger.info("🏰 CityGates: EnemySpawner found and connected", "Scene")

	# Присвоєння запускає сеттер → _on_state_changed().
	current_state = _initial_state()

## Стан при вході — за прапорцями. Раніше завжди стартували з INTRO_DIALOGUE, а він при
## прочитаному вступі просто виходив: повернувшись у кімнату, бій не починався ніколи.
func _initial_state() -> State:
	var game := Game.get_singleton()
	if game.get_quest_flag("city_gates_after_fight_complete"):
		return State.TO_CITY
	if game.get_quest_flag("city_gates_fight_complete"):
		return State.AFTER_FIGHT_DIALOGUE
	if game.get_quest_flag("city_gates_intro_complete"):
		return State.FIGHT_LOOP
	return State.INTRO_DIALOGUE

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	DebugLogger.info("🏰 CityGates: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")

	_apply_state_logic(new_state, run_id)

func _apply_state_logic(state: State, run_id: int) -> void:
	var game = Game.get_singleton()
	match state:
		State.INTRO_DIALOGUE:
			# Перевіряємо, чи діалог вже був прочитаний
			if game.get_quest_flag("city_gates_intro_complete", false):
				DebugLogger.info("🏰 CityGates: ⏭️ Діалог CityGates вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Defeat the gate guards")
				return
			_set_objective("Approach the city gates")
			_execute_step(StepType.DIALOGUE, "CityGates", run_id)
		State.FIGHT_LOOP:
			# Перевіряємо, чи діалог вже був прочитаний
			if game.get_quest_flag("city_gates_fight_complete", false):
				DebugLogger.info("🏰 CityGates: ⏭️ Діалог CityGates_Fight вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Enter the city")
				return
			_set_objective("Defeat the gate guards")
			_start_fight("CityGates_Fight", run_id)
		State.AFTER_FIGHT_DIALOGUE:
			# Перевіряємо, чи діалог вже був прочитаний
			if game.get_quest_flag("city_gates_after_fight_complete", false):
				DebugLogger.info("🏰 CityGates: ⏭️ Діалог CityGates_AfterFight вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Find the laboratory")
				return
			_set_objective("Enter the city")
			_execute_step(StepType.DIALOGUE, "CityGates_AfterFight", run_id)
		State.TO_CITY:
			_set_objective("Find the laboratory")
			# Перехід до Laboratory обробляється автоматично через MetSys room connections
			DebugLogger.info("🏰 CityGates: Стейт TO_CITY - перехід обробляється через MetSys", "Scene")

## Репліка йде ПЕРЕД боєм: поки вона висить, гравець заблокований (DialogueManager), і ворог,
## що вже зʼявився, бив би його, а гравець не міг би поворухнутись — виглядало як зависання.
## Бій закінчується лише смертю ворогів (_on_all_enemies_defeated), а не кінцем репліки.
## Гравець вийшов посеред бою — повертаємо тих самих ворогів без репліки (D152).
func _start_fight(dialogue_id: String, run_id: int) -> void:
	if not enemy_spawner.fight_in_progress():
		await _play_dialogue(dialogue_id, run_id)
		if run_id != state_run_id:
			return
	_spawn_enemies_for_fight()

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
	advance_state()

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	var dm = _get_dialogue_manager()
	if not dm: return

	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	dm.start_dialogue(path)

	while true:
		var finished_id = await EventBus.dialogue_finished
		if finished_id == path or finished_id == dialogue_id:
			# Завершуємо квест після діалогу
			_complete_quest_for_dialogue(dialogue_id)
			break
		if run_id != state_run_id: return

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	"""Встановлює квестові флаги для діалогів"""
	var game = Game.get_singleton()
	if not game: return

	match dialogue_id:
		"CityGates":
			game.set_quest_flag("city_gates_intro_complete", true)
		"CityGates_AfterFight":
			game.set_quest_flag("city_gates_after_fight_complete", true)

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.TO_CITY:
		current_state = (current_state + 1) as State
	else:
		# Перехід до Laboratory обробляється автоматично через MetSys room connections
		DebugLogger.info("🏰 CityGates: Стейт TO_CITY досягнуто - перехід обробляється через MetSys", "Scene")

func _set_objective(text: String) -> void:
	"""Встановлює об'єктив для гравця"""
	var game = Game.get_singleton()
	game.set_objective(text)

func _get_dialogue_manager() -> Node:
	return ServiceLocator.get_dialogue_manager()
	return null

func _spawn_enemies_for_fight() -> void:
	"""Спавнить врагов для боя"""
	enemy_spawner.spawn_all_enemies()
	DebugLogger.info("🏰 CityGates: Enemies spawning for fight", "Scene")
	# D209: охоронець — перший асист-туторіал: кнопка асисту кличе його, його удар закінчує бій
	ServiceLocator.get_companion_manager().offer_guard(true)
	_hint().show_hint(CALL_GUARD, true, true)
	if not EventBus.assist_called.is_connected(_on_assist_called):
		EventBus.assist_called.connect(_on_assist_called)

func _on_assist_called(companion_id: String) -> void:
	if companion_id == "guard":
		_hint().force_hide()
		_hint().show_hint(COMPANIONS_HINT, true)

func _hint() -> TutorialHintDisplay:
	return get_tree().get_first_node_in_group(&"tutorial_hint_display")

## Пішли з воріт посеред бою (смерть, портал) — охоронця більше не пропонують.
func _exit_tree() -> void:
	ServiceLocator.get_companion_manager().offer_guard(false)


func _on_all_enemies_defeated() -> void:
	"""Обработчик когда все враги убиты"""
	ServiceLocator.get_companion_manager().offer_guard(false)
	if _hint().current_hint == CALL_GUARD:
		_hint().force_hide()
	DebugLogger.info("🏰 CityGates: All enemies defeated, advancing state", "Scene")
	# Переходим к следующему state после победы
	if current_state == State.FIGHT_LOOP:
		Game.get_singleton().set_quest_flag("city_gates_fight_complete", true)
		advance_state()
