extends Node2D
class_name HitImpact

## Влучання (D204, D268, Sapega 2026-10-21 «хак-енд-слеш»): розтин навскіс через ціль (Assets/FX/Hit/cut_1–4,
## Scripts/Tools/comfy_fx.py) і кілька осколків у бік удару. Без спалахів і круглих вибухів. Зникає з останнім кадром.

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shards: CPUParticles2D = $Shards


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"hit")
	shards.emitting = true


## Удар іде праворуч (1) чи ліворуч (-1): розтин і осколки — туди ж.
func set_direction(direction: int) -> void:
	$Sprite.flip_h = direction < 0
	$Shards.direction.x = absf($Shards.direction.x) * (-1.0 if direction < 0 else 1.0)
