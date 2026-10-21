extends Area2D

## Вогняна куля боса (D302): летить по прямій на висоті героя, б'є героя один раз (блок / парирування / перекат
## працюють — шкода йде через Player.take_damage з босом як джерелом) і гасне об стіну або за RANGE px.

const SPEED := 360.0
const RANGE := 1100.0

var direction := 1
var damage := 10
var source: Node2D
var _flown := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Sprite2D.flip_h = direction < 0
	$AnimationPlayer.play(&"fly")


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_flown += SPEED * delta
	if _flown >= RANGE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(GameGroups.PLAYER):
		body.take_damage(damage, source if is_instance_valid(source) else null)
		queue_free()
	elif not body is CharacterBody2D:  # стіна, підлога
		queue_free()
