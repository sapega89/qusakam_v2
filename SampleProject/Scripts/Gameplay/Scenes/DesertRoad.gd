extends Node2D

## 🌵 Desert Road Scene Manager
## States: TRAVELING (LOOP), FIGHT_ENCOUNTER, TRANSITION_TO_CITY

enum State {
	TRAVELING,
	FIGHT_ENCOUNTER,
	TRANSITION_TO_CITY
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.TRAVELING:
	set(val):
		current_state = val
		_on_state_changed(val)

var state_run_id: int = 0
signal state_complete(state: State)

# Enemy spawner reference
var enemy_spawner: RoomEnemySpawner = null

func _ready() -> void:
	if ServiceLocator and not ServiceLocator.is_node_ready():
		await ServiceLocator.ready

	# Находим EnemySpawner
	enemy_spawner = get_node_or_null("EnemySpawner") as RoomEnemySpawner
	if enemy_spawner:
		enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
		DebugLogger.info("🌵 DesertRoad: EnemySpawner found and connected", "Scene")
	else:
		DebugLogger.warning("🌵 DesertRoad: EnemySpawner not found", "Scene")
	
	# Визначаємо початковий стан на основі quest flags.
	# Ручного _on_state_changed() тут бути не має: присвоєння current_state
	# всередині вже запускає сеттер, а другий виклик стартує той самий стан
	# удруге і перебиває власний діалог (та сама бага, що була у Village).
	_determine_initial_state()

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	DebugLogger.info("🌵 DesertRoad: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	
	_apply_state_logic(new_state, run_id)

func _apply_state_logic(state: State, run_id: int) -> void:
	var game = Game.get_singleton()
	match state:
		State.TRAVELING:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("desert_road_monologue_complete", false):
				DebugLogger.info("🌵 DesertRoad: ⏭️ Діалог DesertRoad_Monologue вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Продовжуйте шлях до міста")
				# Не викликаємо advance_state(), щоб не переходити автоматично
				return
			_set_objective("Продовжуйте шлях до міста")
			_execute_step(StepType.DIALOGUE, "DesertRoad_Monologue", run_id)
		State.FIGHT_ENCOUNTER:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("desert_road_fight_complete", false):
				DebugLogger.info("🌵 DesertRoad: ⏭️ Діалог DesertRoad_Fight вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Дійти до воріт міста")
				# Не викликаємо advance_state(), щоб не переходити автоматично
				return
			_set_objective("Перемогти ворогів на дорозі")
			# Спавнимо врагів перед діалогом
			_spawn_enemies_for_fight()
			_execute_step(StepType.COMBAT, "DesertRoad_Fight", run_id)
		State.TRANSITION_TO_CITY:
			_set_objective("Дійти до воріт міста")
			# Перехід до CityGates обробляється автоматично через MetSys room connections
			# Не викликаємо _execute_step(), щоб не переходити автоматично
			DebugLogger.info("🌵 DesertRoad: Стейт TRANSITION_TO_CITY - перехід обробляється через MetSys", "Scene")

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

	# EventBus — autoload; has_singleton() завжди давав false, тож цикл очікування
	# не виконувався жодного разу. _play_dialogue() повертався одразу після
	# start_dialogue(), _execute_step() робив advance_state(), і вся сцена
	# пролітала TRAVELING -> FIGHT_ENCOUNTER -> TRANSITION_TO_CITY за один кадр,
	# спавнячи ворогів ще до того, як RoomEnemySpawner знайшов точки спавну.
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
		"DesertRoad_Monologue":
			game.set_quest_flag("desert_road_monologue_complete", true)
		"DesertRoad_Fight":
			game.set_quest_flag("desert_road_fight_complete", true)

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.TRANSITION_TO_CITY:
		current_state = (current_state + 1) as State
	else:
		# Перехід до CityGates обробляється автоматично через MetSys room connections
		# Не викликаємо ручний перехід
		DebugLogger.info("🌵 DesertRoad: Стейт TRANSITION_TO_CITY досягнуто - перехід обробляється через MetSys", "Scene")

func _determine_initial_state() -> void:
	"""Визначає початковий стан на основі квестових флагів"""
	DebugLogger.info("🌵 DesertRoad: Визначаємо початковий стан...", "Scene")
	
	var game = Game.get_singleton()
	if not game:
		DebugLogger.warning("🌵 DesertRoad: Game singleton не знайдено, використовуємо TRAVELING за замовчуванням", "Scene")
		current_state = State.TRAVELING
		return
	
	# Перевіряємо quest flags, щоб визначити, на якому етапі знаходиться гравець
	if game.get_quest_flag("desert_road_fight_complete", false):
		# Бій завершено - переходимо до TRANSITION_TO_CITY
		current_state = State.TRANSITION_TO_CITY
		DebugLogger.info("🌵 DesertRoad: ✅ Бій завершено, стейт = TRANSITION_TO_CITY", "Scene")
	elif game.get_quest_flag("desert_road_monologue_complete", false):
		# Монолог прочитано - переходимо до FIGHT_ENCOUNTER
		current_state = State.FIGHT_ENCOUNTER
		DebugLogger.info("🌵 DesertRoad: ✅ Монолог прочитано, стейт = FIGHT_ENCOUNTER", "Scene")
	else:
		# Початок - TRAVELING
		current_state = State.TRAVELING
		DebugLogger.info("🌵 DesertRoad: ✅ Початок, стейт = TRAVELING", "Scene")

func _set_objective(text: String) -> void:
	"""Встановлює об'єктив для гравця"""
	var game = Game.get_singleton()
	if game and game.has_method("set_objective"):
		game.set_objective(text)

func _get_dialogue_manager() -> Node:
	# ServiceLocator — autoload (/root/ServiceLocator), не Engine-синглтон:
	# has_singleton() для нього завжди false, тож цей метод ЗАВЖДИ повертав null.
	if ServiceLocator:
		return ServiceLocator.get_dialogue_manager()
	DebugLogger.warning("🌵 DesertRoad: ServiceLocator недоступний", "Scene")
	return null

func _spawn_enemies_for_fight() -> void:
	"""Спавнить врагов для боя"""
	if enemy_spawner:
		enemy_spawner.spawn_all_enemies()
		DebugLogger.info("🌵 DesertRoad: Enemies spawning for fight", "Scene")
	else:
		DebugLogger.warning("🌵 DesertRoad: Cannot spawn enemies - spawner not found", "Scene")

func _on_all_enemies_defeated() -> void:
	"""Обработчик когда все враги убиты"""
	DebugLogger.info("🌵 DesertRoad: All enemies defeated, advancing state", "Scene")
	# Переходим к следующему state после победы
	if current_state == State.FIGHT_ENCOUNTER:
		advance_state()
