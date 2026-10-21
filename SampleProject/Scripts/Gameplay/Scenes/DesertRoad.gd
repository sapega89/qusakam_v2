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
	if not ServiceLocator.is_node_ready():
		await ServiceLocator.ready

	# Находим EnemySpawner
	enemy_spawner = $EnemySpawner
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	DebugLogger.info("🌵 DesertRoad: EnemySpawner found and connected", "Scene")

	# Визначаємо початковий стан на основі quest flags.
	# Ручного _on_state_changed() тут бути не має: присвоєння current_state
	# всередині вже запускає сеттер, а другий виклик стартує той самий стан
	# удруге і перебиває власний діалог (та сама бага, що була у Village).
	# Гравець спустився з каньйону на дорогу — Canyon II у журналі закрито.
	# Canyon_ExitCutscene ставить його лише через CanyonExitTrigger, а на дорогу
	# можна спуститися й повз нього.
	Game.get_singleton().set_quest_flag("canyon_exit_complete", true)
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
			if game.get_quest_flag("desert_road_monologue_complete", false):
				DebugLogger.info("🌵 DesertRoad: ⏭️ Діалог DesertRoad_Monologue вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Continue on to the city", &"city_gates")
				# Не викликаємо advance_state(), щоб не переходити автоматично
				return
			_set_objective("Continue on to the city", &"city_gates")
			# Монолог запускає тригер на дорозі (після приземлення), а не вхід у кімнату.
			await _play_dialogue("DesertRoad_Monologue", run_id, false)
			if run_id != state_run_id: return
			advance_state()
		State.FIGHT_ENCOUNTER:
			# Перевіряємо, чи діалог вже був прочитаний
			if game.get_quest_flag("desert_road_fight_complete", false):
				DebugLogger.info("🌵 DesertRoad: ⏭️ Діалог DesertRoad_Fight вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Reach the city gates", &"city_gates")
				# Не викликаємо advance_state(), щоб не переходити автоматично
				return
			_set_objective("Defeat the enemies on the road")
			_start_fight("DesertRoad_Fight", run_id)
		State.TRANSITION_TO_CITY:
			_set_objective("Reach the city gates", &"city_gates")
			# Перехід до CityGates обробляється автоматично через MetSys room connections
			# Не викликаємо _execute_step(), щоб не переходити автоматично
			DebugLogger.info("🌵 DesertRoad: Стейт TRANSITION_TO_CITY - перехід обробляється через MetSys", "Scene")

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

## start = false — діалог запускає хтось інший (тригер), лише чекаємо на його кінець.
func _play_dialogue(dialogue_id: String, run_id: int, start: bool = true) -> void:
	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	if start:
		_get_dialogue_manager().start_dialogue(path)

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

func _set_objective(text: String, target: StringName = &"") -> void:
	"""Встановлює об'єктив для гравця; target — мітка ObjectiveTargets/<target>, куди вказує стрілка (D-28h)"""
	var game = Game.get_singleton()
	game.set_objective(text, target)

func _get_dialogue_manager() -> Node:
	# ServiceLocator — autoload (/root/ServiceLocator), не Engine-синглтон:
	# has_singleton() для нього завжди false, тож цей метод ЗАВЖДИ повертав null.
	return ServiceLocator.get_dialogue_manager()
	DebugLogger.warning("🌵 DesertRoad: ServiceLocator недоступний", "Scene")
	return null

func _spawn_enemies_for_fight() -> void:
	"""Спавнить врагов для боя"""
	enemy_spawner.spawn_all_enemies()
	DebugLogger.info("🌵 DesertRoad: Enemies spawning for fight", "Scene")

func _on_all_enemies_defeated() -> void:
	"""Обработчик когда все враги убиты"""
	DebugLogger.info("🌵 DesertRoad: All enemies defeated, advancing state", "Scene")
	# Переходим к следующему state после победы
	if current_state == State.FIGHT_ENCOUNTER:
		Game.get_singleton().set_quest_flag("desert_road_fight_complete", true)
		advance_state()
