extends Node2D
class_name HitImpact

## Іскра влучання (D204): кадри Circle_explosion 1–5 (Assets/FX/HitSpark), зникає з останнім кадром.

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"hit")


## Іскра дивиться в бік удару (1 — праворуч, -1 — ліворуч).
func set_direction(direction: int) -> void:
	$Sprite.flip_h = direction < 0
