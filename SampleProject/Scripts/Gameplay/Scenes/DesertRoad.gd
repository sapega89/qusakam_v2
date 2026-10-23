extends Node2D

## 🌵 Desert Road Scene Manager
## States: FIGHT_ENCOUNTER, TRANSITION_TO_CITY (D439: no TRAVELING talk before the fight)

enum State {
	FIGHT_ENCOUNTER,
	TRANSITION_TO_CITY
}

@export var current_state: State = State.FIGHT_ENCOUNTER:
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
	# удруге (та сама бага, що була у Village).
	# Гравець спустився з каньйону на дорогу — Canyon II у журналі закрито.
	# Canyon_ExitCutscene ставить його лише через CanyonExitTrigger, а на дорогу
	# можна спуститися й повз нього.
	Game.get_singleton().set_quest_flag("canyon_exit_complete", true)
	_determine_initial_state()

func _on_state_changed(new_state: State) -> void:
	state_run_id += 1
	DebugLogger.info("🌵 DesertRoad: Entering state %s (RunID: %d)" % [State.keys()[new_state], state_run_id], "Scene")
	_apply_state_logic(new_state)

## D439: на дорозі немає розмови перед боєм (ні монологу, ні «Enemies on the road!»): вороги вже стоять на
## дорозі, коли герой приходить, і нападають, коли він підійде (їхній detection_range). Бій закінчується
## лише смертю ворогів (_on_all_enemies_defeated). Гравець вийшов посеред бою — ті самі вороги назад (D152).
func _apply_state_logic(state: State) -> void:
	match state:
		State.FIGHT_ENCOUNTER:
			_set_objective("Defeat the enemies on the road")
			_spawn_enemies_for_fight()
		State.TRANSITION_TO_CITY:
			_set_objective("Reach the city gates", &"city_gates")
			# Перехід до CityGates обробляється автоматично через MetSys room connections
			DebugLogger.info("🌵 DesertRoad: Стейт TRANSITION_TO_CITY - перехід обробляється через MetSys", "Scene")

func advance_state() -> void:
	state_complete.emit(current_state)
	if current_state < State.TRANSITION_TO_CITY:
		current_state = (current_state + 1) as State
	else:
		# Перехід до CityGates обробляється автоматично через MetSys room connections
		DebugLogger.info("🌵 DesertRoad: Стейт TRANSITION_TO_CITY досягнуто - перехід обробляється через MetSys", "Scene")

## Бій виграно — далі до міста; інакше вороги стоять на дорозі (D439).
func _determine_initial_state() -> void:
	if Game.get_singleton().get_quest_flag("desert_road_fight_complete", false):
		current_state = State.TRANSITION_TO_CITY
	else:
		current_state = State.FIGHT_ENCOUNTER
	DebugLogger.info("🌵 DesertRoad: ✅ стейт = %s" % State.keys()[current_state], "Scene")

func _set_objective(text: String, target: StringName = &"") -> void:
	"""Встановлює об'єктив для гравця; target — мітка ObjectiveTargets/<target>, куди вказує стрілка (D-28h)"""
	var game = Game.get_singleton()
	game.set_objective(text, target)

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
