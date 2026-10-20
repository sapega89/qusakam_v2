extends Node2D

## Ефект касту навички (BACKLOG 21, D271). Сцена — дитина героя, дзеркалиться за поглядом (scale.x).
## AnimationPlayer сцени: «charge» — поки йде замах, «release» — вивільнення, після нього сцена зникає.
## Зірваний каст (D259) гасне одразу: ефекту немає.

@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_animation.play(&"charge")


func release() -> void:
	_animation.play(&"release")
	_animation.animation_finished.connect(func(_name: StringName) -> void: queue_free())


func cancel() -> void:
	queue_free()
