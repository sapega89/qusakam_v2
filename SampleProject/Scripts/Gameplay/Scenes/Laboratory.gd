extends Node2D

## 🧪 Коридори лабораторії (D303, D306, [[lab_story_plan]] зріз 7): звичайна кімната з ціллю, без сюжетних реплік.
## Три бої — по одному на поверх (Fight_Upper / Fight_Middle / Fight_Lower, RoomEnemySpawner з trigger_area, як
## секції DesertRoad, D296): вороги зʼявляються, коли герой заходить у зону бою; кожен бій памʼятає своїх убитих
## у Game.room_state під своїм ключем (D152), тож добитий бій не повертається ні після виходу, ні після завантаження.
## Усі три добиті → прапорець lab_corridors_complete (журнал) і ціль далі — у залу джина (LabBoss, D307).

const FIGHTS: Array[NodePath] = [^"Fight_Upper", ^"Fight_Middle", ^"Fight_Lower"]
const CLEARED_FLAG := "lab_corridors_complete"


func _ready() -> void:
	for path in FIGHTS:
		# Відкладено: спавнер викидає сигнал раніше, ніж стирає вбитого зі стану кімнати.
		(get_node(path) as RoomEnemySpawner).all_enemies_defeated.connect(_update, CONNECT_DEFERRED)
	_update()


func is_fight_cleared(path: NodePath) -> bool:
	return (get_node(path) as RoomEnemySpawner).fight_cleared()


func cleared_count() -> int:
	return FIGHTS.filter(is_fight_cleared).size()


func _update() -> void:
	var game := Game.get_singleton()
	if cleared_count() == FIGHTS.size() and not game.get_quest_flag(CLEARED_FLAG):
		game.set_quest_flag(CLEARED_FLAG, true)
	if game.get_quest_flag("lab_after_boss_complete"):
		game.set_objective("Leave the laboratory")
	elif game.get_quest_flag(CLEARED_FLAG):
		game.set_objective("Go deeper into the laboratory")
	else:
		game.set_objective("Fight through the laboratory")
