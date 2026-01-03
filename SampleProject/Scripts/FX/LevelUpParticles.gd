extends Node2D
class_name LevelUpParticles

## Level Up Particle Effect
## Golden burst when player levels up

@onready var particles: CPUParticles2D = $CPUParticles2D

func _ready() -> void:
	"""Start particle emission and auto-cleanup"""
	if particles:
		particles.emitting = true

	# Auto-delete after particles finish
	await get_tree().create_timer(2.0).timeout
	queue_free()
