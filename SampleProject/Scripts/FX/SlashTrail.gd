extends Node2D
class_name SlashTrail

## Шлейф удару (D224, D232): суцільний півмісяць замаху (arc), пряма смуга уколу (thrust) або «вибух»
## удару кулаком (punch), кадри
## Assets/FX/Smear (Scripts/Tools/draw_hero_attack.py). Зникає з останнім кадром. Ставить і масштабує
## WeaponView — він знає зброю, вид удару й напрямок.

## Вузол із пулу ударів ворогів (EnemyStrikeFX, A17): з останнім кадром ховається, а не зникає.
var pooled := false

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.animation_finished.connect(_on_finished)


func _on_finished() -> void:
	if pooled:
		hide()
	else:
		queue_free()


## [param kind] — &"arc", &"thrust" чи &"punch"; [param upward] — другий удар серії, дуга знизу вгору.
func play(kind: StringName, upward: bool) -> void:
	sprite.centered = kind != &"thrust"  # укол росте від точки хвату вперед, решта — навколо центру
	sprite.offset = Vector2.ZERO if kind != &"thrust" else Vector2(0, -sprite.sprite_frames.get_frame_texture(kind, 0).get_height() / 2.0)
	sprite.flip_v = upward
	show()
	sprite.play(kind)
	sprite.set_frame_and_progress(0, 0.0)  # вузол із пулу міг дограти цю ж анімацію до кінця
