extends Node2D
class_name SlashTrail

## Slash Trail VFX
## Visual effect for player sword attacks

@onready var particles: CPUParticles2D = $CPUParticles2D

func _ready() -> void:
	"""Start particle emission and auto-cleanup"""
	if particles:
		particles.emitting = true

	# Auto-delete after particles finish
	await get_tree().create_timer(0.5).timeout
	queue_free()

func set_direction(direction: int) -> void:
	"""Set slash direction (1 = right, -1 = left)"""
	if not particles:
		particles = get_node_or_null("CPUParticles2D")
		
	if particles:
		# Flip emission direction based on attack direction
		if direction < 0:
			particles.direction = Vector2.LEFT
			particles.angle_min = 135
			particles.angle_max = 135
		else:
			particles.direction = Vector2.RIGHT
			particles.angle_min = 45
			particles.angle_max = 45
