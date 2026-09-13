extends Node2D

## 🧪 Laboratory Scene
## States: Explore, Companion_01, Companion_02, Companion_03, LimitTest, BossFight, AfterBoss
## Згідно з ЕТАПОМ 3: КРОК 2

enum State {
	EXPLORE,
	COMPANION_01,
	COMPANION_02,
	COMPANION_03,
	LIMIT_TEST,
	BOSS_FIGHT,
	AFTER_BOSS
}

enum StepType { DIALOGUE, COMBAT, LOOP, TRANSITION }

@export var current_state: State = State.EXPLORE:
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
		DebugLogger.info("🧪 Laboratory: EnemySpawner found and connected", "Scene")
	else:
		DebugLogger.warning("🧪 Laboratory: EnemySpawner not found", "Scene")
	
	_on_state_changed(current_state)

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	var run_id = state_run_id
	DebugLogger.info("🧪 Laboratory: Entering state %s (RunID: %d)" % [State.keys()[new_state], run_id], "Scene")
	
	_apply_state_logic(new_state, run_id)

func _apply_state_logic(state: State, run_id: int) -> void:
	var game = Game.get_singleton()
	match state:
		State.EXPLORE:
			_set_objective("Дослідити лабораторію")
			# EXPLORE не має автоматичного переходу - чекає на тригер
			DebugLogger.info("🧪 Laboratory: Стейт EXPLORE - очікування тригера", "Scene")
		State.COMPANION_01:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("lab_companion_01_complete", false):
				DebugLogger.info("🧪 Laboratory: ⏭️ Діалог Lab_Companion_01 вже був прочитаний, пропускаємо", "Scene")
				return
			_set_objective("Дослідити лабораторію")
			_execute_step(StepType.DIALOGUE, "Lab_Companion_01", run_id)
		State.COMPANION_02:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("lab_companion_02_complete", false):
				DebugLogger.info("🧪 Laboratory: ⏭️ Діалог Lab_Companion_02 вже був прочитаний, пропускаємо", "Scene")
				return
			_set_objective("Продовжити дослідження")
			_execute_step(StepType.DIALOGUE, "Lab_Companion_02", run_id)
		State.COMPANION_03:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("lab_companion_03_complete", false):
				DebugLogger.info("🧪 Laboratory: ⏭️ Діалог Lab_Companion_03 вже був прочитаний, пропускаємо", "Scene")
				return
			_set_objective("Готуватися до битви")
			_execute_step(StepType.DIALOGUE, "Lab_Companion_03", run_id)
		State.LIMIT_TEST:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("lab_limit_test_complete", false):
				DebugLogger.info("🧪 Laboratory: ⏭️ Діалог Lab_LimitTest вже був прочитаний, пропускаємо", "Scene")
				return
			_set_objective("Пройдіть тест обмежень")
			_execute_step(StepType.DIALOGUE, "Lab_LimitTest", run_id)
		State.BOSS_FIGHT:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("lab_boss_fight_complete", false):
				DebugLogger.info("🧪 Laboratory: ⏭️ Діалог Laboratory_BossFight вже був прочитаний, пропускаємо", "Scene")
				return
			_set_objective("Перемогти боса лабораторії")
			# Спавнимо врагів перед діалогом
			_spawn_enemies_for_fight()
			_execute_step(StepType.COMBAT, "Laboratory_BossFight", run_id)
		State.AFTER_BOSS:
			# Перевіряємо, чи діалог вже був прочитаний
			if game and game.get_quest_flag("lab_after_boss_complete", false):
				DebugLogger.info("🧪 Laboratory: ⏭️ Діалог Laboratory_AfterBoss вже був прочитаний, пропускаємо", "Scene")
				_set_objective("Вийти з лабораторії")
				return
			_set_objective("Вийти з лабораторії")
			_execute_step(StepType.DIALOGUE, "Laboratory_AfterBoss", run_id)

func _execute_step(type: StepType, dialogue_id: String, run_id: int) -> void:
	match type:
		StepType.DIALOGUE:
			await _play_dialogue(dialogue_id, run_id)
		StepType.COMBAT:
			# Fast Path: Імітуємо бій діалогом
			await _play_dialogue(dialogue_id, run_id)
		StepType.LOOP:
			# Fast Path: Чекаємо 1 сек
			await get_tree().create_timer(1.0).timeout
		StepType.TRANSITION:
			pass
	
	if run_id != state_run_id: return
	advance_state()

func _play_dialogue(dialogue_id: String, run_id: int) -> void:
	var dm = _get_dialogue_manager()
	if not dm: 
		await get_tree().create_timer(0.5).timeout
		return

	var path = "res://dialogue_quest/" + dialogue_id + ".dqd"
	dm.start_dialogue(path)
	
	if Engine.has_singleton("EventBus"):
		while true:
			var finished_id = await EventBus.dialogue_finished
			# Адресна перевірка: чекаємо саме наш діалог (або шлях до нього)
			if finished_id == path or finished_id == dialogue_id:
				# Завершуємо квест після діалогу
				_complete_quest_for_dialogue(dialogue_id)
				break
			# Якщо стейт змінився поки ми чекали - виходимо
			if run_id != state_run_id: return

func _complete_quest_for_dialogue(dialogue_id: String) -> void:
	"""Встановлює квестові флаги для діалогів"""
	var game = Game.get_singleton()
	if not game: return
	
	match dialogue_id:
		"Lab_Companion_01":
			game.set_quest_flag("lab_companion_01_complete", true)
		"Lab_Companion_02":
			game.set_quest_flag("lab_companion_02_complete", true)
		"Lab_Companion_03":
			game.set_quest_flag("lab_companion_03_complete", true)
		"Lab_LimitTest":
			game.set_quest_flag("lab_limit_test_complete", true)
		"Laboratory_BossFight":
			game.set_quest_flag("lab_boss_fight_complete", true)
		"Laboratory_AfterBoss":
			game.set_quest_flag("lab_after_boss_complete", true)

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.AFTER_BOSS:
		current_state = (current_state + 1) as State
	else:
		# Перехід до LaboratoryOutside обробляється автоматично через MetSys room connections
		DebugLogger.info("🧪 Laboratory: Стейт AFTER_BOSS досягнуто - перехід обробляється через MetSys", "Scene")

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
		DebugLogger.info("🧪 Laboratory: Enemies spawning for boss fight", "Scene")
	else:
		DebugLogger.warning("🧪 Laboratory: Cannot spawn enemies - spawner not found", "Scene")

func _on_all_enemies_defeated() -> void:
	"""Обработчик когда все враги убиты"""
	DebugLogger.info("🧪 Laboratory: All enemies defeated, advancing state", "Scene")
	# Переходим к следующему state после победы
	if current_state == State.BOSS_FIGHT:
		advance_state()
