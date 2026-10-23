extends Node

## Що NPC робить, коли з ним не говорять (BACKLOG 5, D295): кілька циклів дії (work) чергуються з
## паузою спокою (idle) випадкової довжини — щоб не виглядало механічно. Поки з NPC говорять — поза
## розмови (talk); після розмови він одразу повертається до дії. Анімації — в AnimationPlayer поруч (.tscn).

## Скільки циклів дії підряд (випадково між min і max).
@export var work_loops_min: int = 2
@export var work_loops_max: int = 4
## Пауза спокою між діями, секунди.
@export var rest_min: float = 1.5
@export var rest_max: float = 4.0

@onready var _anim: AnimationPlayer = $"../AnimationPlayer"

## Поки true — поза розмови; ставить NpcBase.
var talking: bool = false:
	set = set_talking

var _working: bool = false
var _left: float = 0.0


func _ready() -> void:
	_rest()
	_left = randf_range(0.0, rest_max)  # сусіди не починають в один кадр


func _process(delta: float) -> void:
	if talking:
		return
	_left -= delta
	if _left > 0.0:
		return
	if _working:
		_rest()
	else:
		_work()


func is_working() -> bool:
	return _working and not talking


func set_talking(value: bool) -> void:
	if value == talking:
		return
	talking = value
	if talking:
		_working = false
		_anim.play(&"talk")
	else:
		_work()


func _work() -> void:
	_working = true
	_anim.play(&"work")
	_left = _anim.get_animation(&"work").length * randi_range(work_loops_min, work_loops_max)


func _rest() -> void:
	_working = false
	_anim.play(&"idle")
	_left = randf_range(rest_min, rest_max)
