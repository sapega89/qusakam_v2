extends Area2D
class_name PlayerProjectile

## Simple player projectile for MVP.
## - Moves in a straight line (X only)
## - Damages first enemy it hits
## - Auto-destroys after lifetime seconds

@export var speed: float = 520.0
@export var lifetime: float = 1.2
@export var damage: int = 10

var direction: int = 1 # -1 left, 1 right
var _life_left: float = 0.0

func _ready() -> void:
	_life_left = lifetime
	# Ensure we can detect bodies
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Minimal visual if none provided in scene
	if get_node_or_null("Visual") == null:
		var visual := Polygon2D.new()
		visual.name = "Visual"
		visual.color = Color(1, 0.9, 0.6, 0.9)
		visual.z_index = 50
		var points := PackedVector2Array()
		var r := 4.0
		for i in range(9):
			var a := float(i) * TAU / 8.0
			points.append(Vector2(cos(a) * r, sin(a) * r))
		visual.polygon = points
		add_child(visual)

func _physics_process(delta: float) -> void:
	global_position.x += float(direction) * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not body or body == self:
		return

	# Only damage enemies (CombatBody2D in enemies group)
	if body is CombatBody2D and body.is_in_group(GameGroups.ENEMIES):
		body.take_damage(damage, self)
		queue_free()

func _exit_tree() -> void:
	"""Відключаємося від сигналів при видаленні"""
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

