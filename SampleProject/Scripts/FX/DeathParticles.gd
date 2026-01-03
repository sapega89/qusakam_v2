extends Node2D
class_name DeathParticles

## Enemy Death Particle Effect
## Explosive burst when enemy dies

@onready var particles: CPUParticles2D = $CPUParticles2D

func _ready() -> void:
	"""Start particle emission and auto-cleanup"""
	if particles:
		particles.emitting = true

	# Auto-delete after particles finish
	await get_tree().create_timer(1.5).timeout
	queue_free()
