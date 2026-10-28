extends Node2D

## Зона навички на землі (v2 зріз 4, D875): Hallowed Circle, Hellfire Stomp. Лежить там, де герой її поклав
## (вузол — дитина мапи, позиція — ступні героя), zone_radius px в обидва боки й HEIGHT px угору. Щосекунди (TICK)
## SkillManager.zone_tick б'є ворогів у ній на [member dps] і лікує героя й союзників у ній на [member heal]; після
## zone_time с (стільки ж ударів) гасне. Кадри-заглушки — дочірні Sprite2D з ім'ям id навички (skill_zone.tscn).

## Між ударами зони, с.
const TICK := 1.0
## Висота зони над землею, px: стоячий ворог (default_enemy) і герой — у ній, той, хто стрибнув вище, — ні.
const HEIGHT := 96.0
## За стільки с зона гасне після останнього удару.
const FADE_TIME := 0.3

var skill: SkillDefinition
## Хто поклав (герой): джерело ушкодження й лікування.
var source: Node2D
## Шкода ворогам і лікування своїм за секунду — уже з рангом і синергіями (SkillManager.zone_power).
var dps: int = 0
var heal: int = 0
var _ticks_left: int = 0
var _tick_left: float = TICK


func _ready() -> void:
	_ticks_left = roundi(skill.zone_time / TICK)
	var sprite: Sprite2D = get_node(NodePath(skill.id))
	sprite.show()
	sprite.scale.x *= skill.zone_radius * 2.0 / sprite.texture.get_width()


## Прямокутник зони в світі: від землі вгору на HEIGHT, zone_radius px від центру в обидва боки.
func area() -> Rect2:
	return Rect2(global_position.x - skill.zone_radius, global_position.y - HEIGHT, skill.zone_radius * 2.0, HEIGHT)


## Скільки ще ударів лишилось (для verify).
func ticks_left() -> int:
	return _ticks_left


func _physics_process(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left += TICK
	_ticks_left -= 1
	ServiceLocator.get_skill_manager().zone_tick(self)
	if _ticks_left <= 0:
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(self, ^"modulate:a", 0.0, FADE_TIME)
		tween.tween_callback(queue_free)
