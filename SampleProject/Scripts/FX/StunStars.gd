extends Node2D

## Зірки оглушення над головою ворога (D465): зірки-діти кружляють пласким еліпсом, поки триває оглушення
## (duration задає CompanionAssist до add_child); задні — тьмяніші й за головою.

@export var radius := Vector2(18.0, 5.0)
## Обертів за секунду, рад/с.
@export var spin := 7.0
var duration := 1.0
var _time := 0.0


func _ready() -> void:
	add_to_group(&"assist_fx")


## Нове оглушення, поки зірки ще кружляють, — подовжує їх, а не додає другі.
func extend(seconds: float) -> void:
	duration = _time + seconds


func _process(delta: float) -> void:
	_time += delta
	var stars := get_children()
	for i in stars.size():
		var angle := _time * spin + TAU * i / stars.size()
		var star: Node2D = stars[i]
		star.position = Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		star.z_index = 1 if sin(angle) > 0.0 else -1
		star.modulate.a = 1.0 if sin(angle) > 0.0 else 0.55
	if _time >= duration:
		queue_free()
