extends Control

## Світіння нових очок (D723, Sapega: «треба підсвічувати, щоб воно якось горіло: ось дивись, тут в тебе нові
## скіл-поінти і очки атрибутів»). Один компонент на HUD-кнопку й на вкладки Game Menu: сяйво (%Halo) м'яко пульсує,
## лічильник (%Badge) показує, скільки очок чекає. Нуль — нічого не світиться і вузол схований.
## Вигляд — тема: PointsGlow (кнопка), PointsGlowTab (табличка-стрілка вкладки), PointsBadge; ритм — UITokens.

## Тип теми сяйва: &"PointsGlow" або &"PointsGlowTab".
@export var halo_type: StringName = &"PointsGlow"
## Лічильник на самому сяйві (вкладки); HUD-кнопка пише число сама.
@export var show_badge := true

@onready var _halo: Panel = %Halo
@onready var _badge: PanelContainer = %Badge
@onready var _count: Label = %Count

var _pulse: Tween = null


func _ready() -> void:
	_halo.theme_type_variation = halo_type
	visible = false


## Скільки очок чекає: > 0 — світиться й пульсує, 0 — гасне.
func set_count(count: int) -> void:
	_count.text = str(count)
	_badge.visible = show_badge
	var glowing := count > 0
	if glowing == is_glowing():
		return
	visible = glowing
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	if glowing:
		_halo.modulate.a = UITokens.POINTS_GLOW_MIN
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_halo, ^"modulate:a", 1.0, UITokens.POINTS_GLOW_PULSE_TIME / 2.0).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_halo, ^"modulate:a", UITokens.POINTS_GLOW_MIN, UITokens.POINTS_GLOW_PULSE_TIME / 2.0).set_trans(Tween.TRANS_SINE)


## Для тестів і захоплень: світиться й пульсує.
func is_glowing() -> bool:
	return visible and _pulse != null and _pulse.is_valid()


func count_text() -> String:
	return _count.text if _badge.visible else ""
