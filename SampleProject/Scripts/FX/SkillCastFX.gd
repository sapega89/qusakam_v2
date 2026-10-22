extends Node2D

## Ефект касту навички (BACKLOG 21, D271). Сцена — дитина героя, дзеркалиться за поглядом (scale.x).
## AnimationPlayer сцени: «charge» — поки йде замах, «release» — вивільнення, після нього сцена зникає.
## Зірваний каст (D259) гасне одразу: ефекту немає.

## Навичка, яку кастують; PlayerCombat задає її до add_child. Спільна сцена навичок клятв бере з неї кадри.
var skill: SkillDefinition


func _ready() -> void:
	_animation().play(&"charge")


func release() -> void:
	_animation().play(&"release")
	_animation().animation_finished.connect(func(_name: StringName) -> void: queue_free())


func cancel() -> void:
	queue_free()


## &"charge" чи &"release" — що зараз грає (для verify).
func phase() -> StringName:
	return _animation().current_animation


func _animation() -> AnimationPlayer:
	return $AnimationPlayer
