extends Line2D

## Блискавка (Electric Strike, D271): ламана від from до to, що перемальовується кожні jitter_time с, поки видно.

@export var from := Vector2.ZERO
@export var to := Vector2(80, 0)
@export var segments := 7
## Наскільки px злам відхиляється від прямої.
@export var spread := 8.0
@export var jitter_time := 0.04

var _left := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = jitter_time
	var normal := (to - from).orthogonal().normalized()
	var points_now := PackedVector2Array([from])
	for i in range(1, segments):
		points_now.append(from.lerp(to, float(i) / segments) + normal * randf_range(-spread, spread))
	points_now.append(to)
	points = points_now
