extends Node2D
class_name HitImpact

## Hit Impact VFX
## Particle burst effect when attacks land

@onready var particles: CPUParticles2D = $CPUParticles2D

func _ready() -> void:
	"""Start particle emission and auto-cleanup"""
	if particles:
		particles.emitting = true

	# Auto-delete after particles finish
	await get_tree().create_timer(0.6).timeout
	queue_free()


## Іскри летять від точки контакту в бік удару (1 — праворуч, -1 — ліворуч).
func set_direction(direction: int) -> void:
	particles.direction = Vector2(direction, -0.6)
	particles.spread = 50.0
