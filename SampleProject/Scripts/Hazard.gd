# Universal hazard script for spikes, lava, and other dangers
extends Area2D
class_name Hazard

## If true, the hazard is currently active and can kill the player
@export var is_active: bool = true
## Delay before the hazard can kill again (prevents multiple triggers)
@export var cooldown: float = 0.5

var can_trigger: bool = true

func _ready() -> void:
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)
	# Set collision layer and mask for detecting player
	collision_layer = 0
	collision_mask = 1  # Detect player on layer 1

func _on_body_entered(body: Node2D) -> void:
	if not is_active or not can_trigger:
		return
	
	if body.is_in_group(&"player"):
		# Kill the player
		if body.has_method("kill"):
			body.kill()
			# Start cooldown to prevent multiple triggers
			can_trigger = false
			await get_tree().create_timer(cooldown).timeout
			can_trigger = true

## Activate the hazard
func activate() -> void:
	is_active = true

## Deactivate the hazard
func deactivate() -> void:
	is_active = false

## Toggle hazard state
func toggle() -> void:
	is_active = not is_active

