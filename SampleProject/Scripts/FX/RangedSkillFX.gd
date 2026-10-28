extends "res://SampleProject/Scripts/FX/SkillCastFX.gd"

## Ефект касту навичок дальнього бою й зон (v2 зріз 4, D874, D875) — заглушка до арту (slice 7): світло в руці,
## що кастує (маркер з ім'ям пози замаху, RangedSkill.tscn), поки йде замах; на вивільненні гасне. Сам спис летить
## снарядом (skill_projectile.tscn), зона лежить на землі (skill_zone.tscn) — вони не діти героя.

## Світло гасне за стільки с після вивільнення.
const FADE_TIME := 0.15

var _phase: StringName = &"charge"

@onready var _glow: Sprite2D = $Glow


func _ready() -> void:
	_glow.position = (get_node(NodePath(skill.windup_pose)) as Marker2D).position


func release() -> void:
	_phase = &"release"
	var tween := create_tween()
	tween.tween_property(_glow, ^"modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func phase() -> StringName:
	return _phase
