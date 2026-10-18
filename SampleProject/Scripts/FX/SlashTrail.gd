extends Node2D
class_name SlashTrail

## Розчерк замаху (D204): кадри Assets/FX/SwingTrail, зникає з останнім кадром.

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"swing")


## Розчерк летить у бік удару (1 — праворуч, -1 — ліворуч).
func set_direction(direction: int) -> void:
	$Sprite.flip_h = direction < 0
