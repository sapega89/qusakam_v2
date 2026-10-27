extends Node2D

## Житель міста (D740, Sapega 2026-10-26 «місто треба показати живим, щоб NPC ходили по ньому»). Ходить своїм
## маршрутом уздовж вулиці туди й назад — до прилавка, до криниці, у двері — і на кожній зупинці стоїть, роззирається.
## Тіла немає: герой проходить крізь нього, а житель, коли герой поруч, відступає на крок углиб вулиці (ASIDE_STEP)
## і йде далі, — ніколи не заступає дорогу. У двері (doorways) він заходить: гасне, якийсь час його немає, виходить.
## Анімації — в AnimationPlayer (.tscn): idle і walk; кадри ходи дивляться праворуч.

## Зупинки маршруту, x у кімнаті (ноги — на y вузла). Житель іде від першої до останньої й назад.
@export var stops: PackedFloat32Array = PackedFloat32Array()
## Ті зупинки, що є дверима: там житель заходить усередину.
@export var doorways: PackedFloat32Array = PackedFloat32Array()
## Крок, світових px/с: різні жителі ходять різно.
@export var speed: float = 36.0
## Скільки стоїть на зупинці, секунд (випадково між).
@export var pause_min: float = 2.0
@export var pause_max: float = 5.0
## Скільки сидить за дверима, секунд.
@export var inside_min: float = 4.0
@export var inside_max: float = 9.0

## Герой ближче за це (px по x) — житель відступає вглиб.
const ASIDE_RADIUS := 56.0
## На скільки px вгору (вглиб вулиці) відступає; і як швидко (px/с).
const ASIDE_STEP := 10.0
const ASIDE_SPEED := 40.0
## Двері: гасне й зʼявляється за стільки секунд.
const DOOR_FADE := 0.4
const ARRIVE := 1.0

enum Mode { WALK, PAUSE, INSIDE }

var mode: Mode = Mode.PAUSE
## Індекс зупинки, до якої йде; напрям обходу (+1 / −1).
var _target := 0
var _step := 1
var _left := 0.0
## Посередині паузи житель обертається (роззирається) — один раз.
var _turn_at := -1.0
## Лінія вулиці — y вузла в сцені.
var _base_y := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_base_y = position.y
	assert(stops.size() >= 2, "Townsfolk: a route needs at least two stops (%s)" % get_path())
	for door: float in doorways:
		assert(stops.has(door), "Townsfolk: doorway %s is not a stop (%s)" % [door, get_path()])
	position.x = stops[0]
	_target = 1
	_pause(randf_range(0.0, pause_max))  # сусіди не рушають в один кадр
	_anim.speed_scale = speed / 36.0  # кадри ходи — під крок 36 px/с


func _process(delta: float) -> void:
	_step_aside(delta)
	match mode:
		Mode.WALK:
			_walk(delta)
		Mode.PAUSE:
			_left -= delta
			if _turn_at >= 0.0 and _left <= _turn_at:
				_turn_at = -1.0
				_sprite.flip_h = not _sprite.flip_h
			if _left <= 0.0:
				_set_off()
		Mode.INSIDE:
			_left -= delta
			if _left <= 0.0:
				_come_out()


## Куди зараз іде (x) — тести й TownsfolkCrowd.
func target_x() -> float:
	return stops[_target]


## Видно на вулиці (не за дверима) — лише такий житель гукає героя.
func is_out() -> bool:
	return mode != Mode.INSIDE and modulate.a > 0.99


## Верх голови — вістря хвоста облачка (як NpcBase.chatter_anchor).
func chatter_anchor() -> Vector2:
	var rect: Rect2 = _sprite.get_rect()
	return _sprite.transform * Vector2(rect.get_center().x, rect.position.y)


func _walk(delta: float) -> void:
	var to := stops[_target]
	var dx := to - position.x
	_sprite.flip_h = dx < 0.0
	if absf(dx) <= ARRIVE:
		position.x = to
		_arrive()
		return
	position.x += signf(dx) * minf(absf(dx), speed * delta)


func _arrive() -> void:
	if doorways.has(stops[_target]):
		_go_inside()
	else:
		_pause(randf_range(pause_min, pause_max))
	_next_target()


func _next_target() -> void:
	if _target + _step < 0 or _target + _step >= stops.size():
		_step = -_step
	_target += _step


func _pause(seconds: float) -> void:
	mode = Mode.PAUSE
	_left = seconds
	_turn_at = seconds * 0.5 if randf() < 0.5 else -1.0
	_anim.play(&"idle")


func _set_off() -> void:
	mode = Mode.WALK
	_anim.play(&"walk")


func _go_inside() -> void:
	mode = Mode.INSIDE
	_left = randf_range(inside_min, inside_max) + DOOR_FADE
	_anim.play(&"idle")
	create_tween().tween_property(self, ^"modulate:a", 0.0, DOOR_FADE)


func _come_out() -> void:
	create_tween().tween_property(self, ^"modulate:a", 1.0, DOOR_FADE)
	_set_off()


## Герой поруч — крок углиб вулиці (спрайт вище, позаду героя); пішов — назад на лінію вулиці.
func _step_aside(delta: float) -> void:
	var hero: Node2D = Game.get_singleton().player
	var near := absf(hero.global_position.x - global_position.x) < ASIDE_RADIUS
	var to := -ASIDE_STEP if near else 0.0
	position.y = move_toward(position.y, _base_y + to, ASIDE_SPEED * delta)
