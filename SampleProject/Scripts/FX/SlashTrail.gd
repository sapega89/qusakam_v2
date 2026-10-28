extends Node2D
class_name SlashTrail

## Шлейф удару (D224, D232): суцільний півмісяць замаху (arc), пряма смуга уколу (thrust) або «вибух»
## удару кулаком (punch), кадри
## Assets/FX/Smear (Scripts/Tools/draw_hero_attack.py). Зникає з останнім кадром. Ставить і масштабує
## WeaponView — він знає зброю, вид удару й напрямок.

## Смуги, що ростуть від точки хвату вперед (вістря на x 70 текстури).
const FROM_GRIP: Array[StringName] = [&"thrust", &"wind_step"]
## Дуги, що стоять правим краєм на краю arc.
const RIGHT_ANCHORED: Array[StringName] = [&"blood_rush"]

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


## [param kind] — &"arc", &"thrust" чи &"punch"; власні удари навичок руху (H3, D812): &"blood_rush" (дуга крові,
## замість arc) і &"wind_step" (вітер, замість thrust). [param upward] — другий удар серії, дуга знизу вгору.
func play(kind: StringName, upward: bool) -> void:
	var size: Vector2 = sprite.sprite_frames.get_frame_texture(kind, 0).get_size()
	var from_grip: bool = kind in FROM_GRIP
	sprite.centered = not from_grip  # укол росте від точки хвату вперед, решта — навколо центру
	if from_grip:
		sprite.offset = Vector2(0, -size.y / 2.0)
	elif kind in RIGHT_ANCHORED:
		# вужча за arc дуга — правим краєм там, де край arc (Assets/FX/README.md, H3)
		sprite.offset = Vector2((sprite.sprite_frames.get_frame_texture(&"arc", 0).get_width() - size.x) / 2.0, 0)
	else:
		sprite.offset = Vector2.ZERO
	sprite.flip_v = upward
	show()
	sprite.play(kind)
	sprite.set_frame_and_progress(0, 0.0)  # вузол із пулу міг дограти цю ж анімацію до кінця
