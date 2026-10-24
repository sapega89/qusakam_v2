extends "res://SampleProject/Scripts/Gameplay/Characters/Enemies/ShieldBearer.gd"

## Вартовий з баштовим щитом (D652, D693): великий щитоносець, еліта за видом (D681). Поведінка щитоносця: удар
## спереду — у щит, у спину — по тілу. Щит намальовано в кадрах, і він не відлітає: важкий удар спереду відбиває його
## вбік (кадр hurt), вартовий у збої guard_break_stagger с, і поки збій триває, удари спереду йдуть по тілу; після
## збою щит знову попереду. Вузол Sprite2D/Shield — точка щита в кадрах (іскри блоку), за поглядом.
## Сцена — enemy_tower_shield_guard.tscn.


## Варту розбито: щит убік, вартовий у збої; щит повертається, коли збій мине.
func break_shield(from_x: float) -> void:
	shield_up = false
	EventBus.enemy_shield_broken.emit(self, shield.global_position)
	stagger(EnemyVariety.shield().guard_break_stagger, from_x)
	get_tree().create_timer(enemy_logic.stun_left).timeout.connect(_raise_shield)


func _raise_shield() -> void:
	if is_staggered():  # новий збій поверх (парирування, навичка) — щит піднімає після нього
		get_tree().create_timer(enemy_logic.stun_left).timeout.connect(_raise_shield)
		return
	shield_up = true


## Точка щита — перед вартовим, за поглядом (кадри дзеркалить flip_h).
func _face_shapes(direction: int) -> void:
	super._face_shapes(direction)
	if direction != 0:
		shield.position.x = absf(shield.position.x) * direction
