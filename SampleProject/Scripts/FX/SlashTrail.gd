extends Node2D
class_name SlashTrail

## Шлейф удару (D224): суцільний півмісяць замаху (arc) або пряма смуга уколу (thrust), кадри
## Assets/FX/Smear (Scripts/Tools/draw_hero_attack.py). Зникає з останнім кадром. Ставить і масштабує
## WeaponView — він знає зброю, вид удару й напрямок.

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)


## [param kind] — &"arc" чи &"thrust"; [param upward] — другий удар серії, дуга знизу вгору.
func play(kind: StringName, upward: bool) -> void:
	sprite.centered = kind == &"arc"
	sprite.offset = Vector2.ZERO if kind == &"arc" else Vector2(0, -sprite.sprite_frames.get_frame_texture(kind, 0).get_height() / 2.0)
	sprite.flip_v = upward
	sprite.play(kind)
