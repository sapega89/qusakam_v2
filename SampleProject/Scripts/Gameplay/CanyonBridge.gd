extends Node2D

## Мотузковий місток над ущелиною каньйону (D231, вигляд — D255). Колізія настилу — шар TileMap/Gate2 (його
## відчиняє GateController за прапорцем village_left_complete, Canyon.gd), тут — лише вигляд і обвал.
## До спуску місток стоїть, уступів ущелини не видно (вузол Gorge схований). Обвал — перший кадр кат-сцени
## спуску (Canyon.gd, D255): смуги містка падають одна за одною, відкриваються уступи; обвал запам'ятовується
## прапорцем canyon_bridge_collapsed. Стовпи лишаються. Розмітка — build_canyon.gd.

const COLLAPSED_FLAG := "canyon_bridge_collapsed"
const FALL := 420.0
const FALL_TIME := 0.8
const PLANK_DELAY := 0.035
const GORGE_FADE_TIME := 0.6

@onready var pieces: Node2D = $Pieces
@onready var gorge: CanvasItem = get_parent().get_node(^"Gorge")


func _ready() -> void:
	var collapsed: bool = Game.get_singleton().get_quest_flag(COLLAPSED_FLAG)
	pieces.visible = not collapsed
	gorge.visible = collapsed


func is_collapsed() -> bool:
	return Game.get_singleton().get_quest_flag(COLLAPSED_FLAG)


## Смуги містка падають від краю плато до дальньої стіни, ущелина з'являється; await — до кінця обвалу.
func collapse() -> void:
	Game.get_singleton().set_quest_flag(COLLAPSED_FLAG, true)
	gorge.visible = true
	gorge.modulate.a = 0.0
	create_tween().tween_property(gorge, ^"modulate:a", 1.0, GORGE_FADE_TIME)
	var parts := pieces.get_children()
	parts.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.x > b.position.x)
	for i in parts.size():
		var part: Node2D = parts[i]
		var tween := create_tween().set_parallel()
		tween.tween_property(part, ^"position:y", part.position.y + FALL, FALL_TIME).set_delay(i * PLANK_DELAY).set_ease(Tween.EASE_IN)
		tween.tween_property(part, ^"rotation", randf_range(-1.4, 1.4), FALL_TIME).set_delay(i * PLANK_DELAY)
		tween.tween_property(part, ^"modulate:a", 0.0, FALL_TIME).set_delay(i * PLANK_DELAY)
	await get_tree().create_timer(parts.size() * PLANK_DELAY + FALL_TIME).timeout
