extends Node2D

## 🧪 Поверхи лабораторії (D303, D306; v3 — D863, D865): звичайні кімнати з ціллю, без сюжетних реплік. Цей скрипт —
## у кожного з трьох поверхів (Laboratory — нижній, LabMiddleFloor, LabTopFloor). Три бої — по одному на поверх
## (RoomEnemySpawner з trigger_area, як секції DesertRoad, D296); імена Fight_Upper / Fight_Middle / Fight_Lower —
## порядок зустрічі ще з до-v3 (перший, другий, третій), їх ключі стану лишились, щоб сейви не губили боїв. Вороги
## зʼявляються, коли герой заходить у зону бою; кожен бій памʼятає своїх убитих у Game.room_state своєї кімнати під
## своїм ключем (D152) — до наступної медитації чи повернення в регіон лабораторії: це звичайні бої (respawns, D492),
## вони вертаються повними, і на них можна докачатись до 20-го рівня.
## Усі три добиті → прапорець lab_corridors_complete (журнал) і ціль далі — у залу джина (LabBoss, D307);
## прапорець лишається, коли бої повертаються.

## Поверх → [бій, ключ стану]: від нижнього (перший на шляху вгору) до верхнього.
const FIGHTS := {
	"res://SampleProject/Maps/Laboratory.tscn": [^"Fight_Upper", "enemies_upper"],
	"res://SampleProject/Maps/LabMiddleFloor.tscn": [^"Fight_Middle", "enemies_middle"],
	"res://SampleProject/Maps/LabTopFloor.tscn": [^"Fight_Lower", "enemies_lower"],
}
const CLEARED_FLAG := "lab_corridors_complete"


func _ready() -> void:
	# Відкладено: спавнер викидає сигнал раніше, ніж стирає вбитого зі стану кімнати.
	(get_node(FIGHTS[scene_file_path][0]) as RoomEnemySpawner).all_enemies_defeated.connect(_update, CONNECT_DEFERRED)
	_update()


func is_fight_cleared(path: NodePath) -> bool:
	return (get_node(path) as RoomEnemySpawner).fight_won()  # D492: повернуті вороги не скасовують перемоги


## Скільки з трьох боїв поверхів виграно — і тут, і на інших поверхах (їхній стан кімнат, без сцен).
func cleared_count() -> int:
	return FIGHTS.keys().filter(func(scene: String) -> bool:
		return RoomEnemySpawner.won_in(MetSys.map_data.get_room_from_scene_path(scene, false), FIGHTS[scene][1])).size()


func _update() -> void:
	var game := Game.get_singleton()
	if cleared_count() == FIGHTS.size() and not game.get_quest_flag(CLEARED_FLAG):
		game.set_quest_flag(CLEARED_FLAG, true)
	if game.get_quest_flag("lab_after_boss_complete"):
		game.set_objective("Leave the laboratory")
	elif game.get_quest_flag(CLEARED_FLAG):
		game.set_objective("Climb up out of the laboratory")
	else:
		game.set_objective("Fight through the laboratory")
