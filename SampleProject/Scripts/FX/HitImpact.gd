extends Node2D
class_name HitImpact

## Іскра влучання (D204): кадри Circle_explosion 1–5 (Assets/FX/HitSpark), зникає з останнім кадром.
## Короткий спалах (D268, Sapega 2026-10-21 «аури попадання досить маленькі») — Flash гасне за FLASH_TIME с.

const FLASH_TIME := 0.1

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var flash: Sprite2D = $Flash


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"hit")
	var tween := create_tween()
	tween.tween_property(flash, ^"modulate:a", 0.0, FLASH_TIME)
	tween.parallel().tween_property(flash, ^"scale", flash.scale * 1.5, FLASH_TIME)


## Іскра дивиться в бік удару (1 — праворуч, -1 — ліворуч).
func set_direction(direction: int) -> void:
	$Sprite.flip_h = direction < 0
