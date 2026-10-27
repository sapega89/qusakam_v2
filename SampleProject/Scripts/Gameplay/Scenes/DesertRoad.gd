extends "res://SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd"

## 🌵 Desert Road Scene Manager
## States: FIGHT_ENCOUNTER, TRANSITION_TO_CITY (D439: no TRAVELING talk before the fight)
## Машина станів — RoomStoryFlow.

enum State {
	FIGHT_ENCOUNTER,
	TRANSITION_TO_CITY
}

# Enemy spawner reference
var enemy_spawner: RoomEnemySpawner = null

func _prepare() -> void:
	# Находим EnemySpawner
	enemy_spawner = $EnemySpawner
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	DebugLogger.info("🌵 DesertRoad: EnemySpawner found and connected", "Scene")

	# Гравець спустився з каньйону на дорогу — Canyon II у журналі закрито.
	# Canyon_ExitCutscene ставить його лише через CanyonExitTrigger, а на дорогу
	# можна спуститися й повз нього.
	Game.get_singleton().set_quest_flag("canyon_exit_complete", true)

## D439: на дорозі немає розмови перед боєм (ні монологу, ні «Enemies on the road!»): вороги вже стоять на
## дорозі, коли герой приходить, і нападають, коли він підійде (їхній detection_range). Бій закінчується
## лише смертю ворогів (_on_all_enemies_defeated). Гравець вийшов посеред бою — ті самі вороги назад (D152).
func _apply_state_logic(state: int, _run_id: int) -> void:
	match state:
		State.FIGHT_ENCOUNTER:
			_set_objective("Defeat the enemies on the road")
			_spawn_enemies_for_fight()
		State.TRANSITION_TO_CITY:
			# Перехід до CityGates обробляється автоматично через MetSys room connections
			_set_objective("Reach the city gates", &"city_gates")

## Бій виграно — далі до міста; інакше вороги стоять на дорозі (D439).
func _initial_state() -> int:
	if Game.get_singleton().get_quest_flag("desert_road_fight_complete", false):
		return State.TRANSITION_TO_CITY
	return State.FIGHT_ENCOUNTER

func _spawn_enemies_for_fight() -> void:
	"""Спавнить врагов для боя"""
	enemy_spawner.spawn_all_enemies()
	DebugLogger.info("🌵 DesertRoad: Enemies spawning for fight", "Scene")

func _on_all_enemies_defeated() -> void:
	"""Обработчик когда все враги убиты"""
	DebugLogger.info("🌵 DesertRoad: All enemies defeated, advancing state", "Scene")
	_fight_won(State.FIGHT_ENCOUNTER, "desert_road_fight_complete")
