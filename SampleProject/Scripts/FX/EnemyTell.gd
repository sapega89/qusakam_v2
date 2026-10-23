extends Node2D

## Підказка удару ворога (4b, D504): відблиск на зброї за EnemyLogic.TELL_LEAD до удару, кольором — що робити:
## білий — блокувати, жовтий — парирувати, червоний — лише ухилитись; для ривка — червона лінія по землі на всю
## його довжину. Без спалахів екрана (D268): лише сам відблиск і лінія. Ставить EnemyView.show_tell.

const GLINT_OUTER := {&"block": Color(0.92, 0.95, 1.0), &"parry": Color(1.0, 0.8, 0.12), &"dodge": Color(1.0, 0.18, 0.12)}
const GLINT_CORE := Color(1.0, 0.98, 0.92)
const LINE_COLOR := Color(1.0, 0.15, 0.1, 0.7)
## Довжина променя відблиску (px), товщина лінії ривка, крок її шевронів.
const GLINT_RAY := 11.0
const LINE_WIDTH := 2.0
const CHEVRON_STEP := 14.0

## Відблиск відносно вузла; лінія ривка — від ніг [member feet] на [member line_length] px у бік [member direction].
var glint_at := Vector2.ZERO
var feet := Vector2.ZERO
var line_length := 0.0
var direction := 1
## Колір підказки (EnemyLogic.TELL_*).
var kind: StringName = &"parry"
var _t := 0.0
var _life := 0.45


func setup(life: float, tell_kind: StringName) -> void:
	_life = life
	kind = tell_kind
	z_index = 50


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / _life
	# Відблиск: швидко розгортається, тримається, а наприкінці стискається в точку — удар
	var grow := minf(1.0, k * 4.0) * (1.0 - maxf(0.0, k - 0.8) * 5.0)
	_star(glint_at, GLINT_RAY * grow, GLINT_OUTER[kind])
	_star(glint_at, GLINT_RAY * 0.5 * grow, GLINT_CORE)
	if line_length > 0.0:
		var end := feet + Vector2(direction * line_length * minf(1.0, k * 3.0), 0)
		draw_line(feet, end, LINE_COLOR, LINE_WIDTH)
		var x := CHEVRON_STEP
		while x < absf(end.x - feet.x):
			var tip := feet + Vector2(direction * x, 0)
			draw_polyline([tip + Vector2(-direction * 4, -4), tip, tip + Vector2(-direction * 4, 4)], LINE_COLOR, LINE_WIDTH)
			x += CHEVRON_STEP


## Чотирипроменева зірка — аніме-відблиск на лезі.
func _star(c: Vector2, ray: float, color: Color) -> void:
	if ray < 1.0:
		return
	var w := ray * 0.22
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -ray), c + Vector2(w, -w), c + Vector2(ray, 0), c + Vector2(w, w),
		c + Vector2(0, ray), c + Vector2(-w, w), c + Vector2(-ray, 0), c + Vector2(-w, -w),
	]), color)
