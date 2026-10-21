extends Node2D

## Ударна хвиля від удару боса об підлогу (D301) — лише вигляд: хвиля пилу біжить в обидва боки на radius px.
## Шкоду рахує BossLogic у мить удару (герой на підлозі в межах radius).

const TIME := 0.45

var radius := 240.0


func _ready() -> void:
	var tween := create_tween().set_parallel()
	for side: Sprite2D in [$Left, $Right]:
		var dir := -1.0 if side == $Left else 1.0
		side.flip_h = dir < 0
		tween.tween_property(side, ^"position:x", dir * radius, TIME)
		tween.tween_property(side, ^"modulate:a", 0.0, TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
