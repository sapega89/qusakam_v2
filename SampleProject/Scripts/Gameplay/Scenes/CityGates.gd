extends Node2D

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
	if Engine.has_singleton("ServiceLocator"):
		var loc = Engine.get_singleton("ServiceLocator")
		if not loc.is_node_ready():
			await loc.ready
	
	# Находим EnemySpawner
	enemy_spawner = get_node_or_null("EnemySpawner") as RoomEnemySpawner
	if enemy_spawner:
		enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
		DebugLogger.info("🏰 CityGates: EnemySpawner found and connected", "Scene")
	else:
		DebugLogger.warning("🏰 CityGates: EnemySpawner not found", "Scene")
	
	_on_state_changed(current_state)

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
			if game and game.get_quest_flag("city_gates_intro_complete", false):
				DebugLogger.info("🏰 CityGates: ⏭️ Діалог CityGates вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Перемогти охоронців воріт")
				return
			_set_objective("Підійти до воріт міста")
			_execute_step(StepType.DIALOGUE, "CityGates", run_id)
		State.FIGHT_LOOP:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("city_gates_fight_complete", false):
				DebugLogger.info("🏰 CityGates: ⏭️ Діалог CityGates_Fight вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Увійти до міста")
				return
			_set_objective("Перемогти охоронців воріт")
			# Спавнимо врагів перед діалогом
			_spawn_enemies_for_fight()
			_execute_step(StepType.COMBAT, "CityGates_Fight", run_id)
		State.AFTER_FIGHT_DIALOGUE:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("city_gates_after_fight_complete", false):
				DebugLogger.info("🏰 CityGates: ⏭️ Діалог CityGates_AfterFight вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Знайти лабораторію")
				return
			_set_objective("Увійти до міста")
			_execute_step(StepType.DIALOGUE, "CityGates_AfterFight", run_id)
		State.TO_CITY:
			_set_objective("Знайти лабораторію")
			# Перехід до Laboratory обробляється автоматично через MetSys room connections
			DebugLogger.info("🏰 CityGates: Стейт TO_CITY - перехід обробляється через MetSys", "Scene")

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
	
	if Engine.has_singleton("EventBus"):
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
		"CityGates_Fight":
			game.set_quest_flag("city_gates_fight_complete", true)
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
	if game and game.has_method("set_objective"):
		game.set_objective(text)

func _get_dialogue_manager() -> Node:
	if Engine.has_singleton("ServiceLocator"):
		return Engine.get_singleton("ServiceLocator").get_dialogue_manager()
	return null

func _spawn_enemies_for_fight() -> void:
	"""Спавнить врагов для боя"""
	if enemy_spawner:
		enemy_spawner.spawn_all_enemies()
		DebugLogger.info("🏰 CityGates: Enemies spawning for fight", "Scene")
	else:
		DebugLogger.warning("🏰 CityGates: Cannot spawn enemies - spawner not found", "Scene")

func _on_all_enemies_defeated() -> void:
	"""Обработчик когда все враги убиты"""
	DebugLogger.info("🏰 CityGates: All enemies defeated, advancing state", "Scene")
	# Переходим к следующему state после победы
	if current_state == State.FIGHT_LOOP:
		advance_state()
