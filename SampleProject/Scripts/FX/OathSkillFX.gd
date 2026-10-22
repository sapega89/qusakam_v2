extends "res://SampleProject/Scripts/FX/SkillCastFX.gd"

## Спільний ефект активних навичок клятв (D279): кадри з Assets/FX/Skills/<id>/ (README поруч).
## charge_1–4 — у руці, що кастує (маркер з ім'ям пози касту), 1–2 раз, далі 3–4 по колу до вивільнення;
## release_1–3 — раз, прикріплений до маркера й краю текстури, як каже README навички. Розмітка — у .tscn.

const FRAMES_DIR := "res://SampleProject/Assets/FX/Skills/%s/%s_%d.png"
const CHARGE_FRAMES := 4
const RELEASE_FRAMES := 3
## Кадр, з якого charge іде по колу.
const CHARGE_LOOP_FROM := 2
const CHARGE_FPS := 12.0
const RELEASE_FPS := 10.0

## id → [маркер вивільнення, край текстури на маркері]. Краї: &"right", &"left", &"bottom", &"center".
const RELEASE_PIN := {
	"radiant_smite": [&"ArcEdge", &"right"],  # зовнішній край дуги — праворуч, як Smear/arc
	"eclipse_cleave": [&"ArcEdge", &"right"],
	"balanced_strike": [&"Hand", &"left"],  # смуга росте від руки вперед, вістря на правому краю, як Smear/thrust
	"searing_hex": [&"Hand", &"left"],
	"withering_grasp": [&"Hand", &"left"],  # рука кігтя починається з лівого краю
	"skyfall_blessing": [&"GroundFront", &"bottom"],  # промінь з неба, нижнє вістря на землі перед героєм
	"judgement_of_the_sky": [&"GroundFront", &"bottom"],  # спис падає вістрям униз
	"second_wind": [&"Feet", &"bottom"],  # вітер піднімається від ніг героя
	"dervish_whirl": [&"Centre", &"center"],  # кільце вихору — по центру героя
}

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add(frames, &"charge", CHARGE_FRAMES, CHARGE_FPS)
	_add(frames, &"release", RELEASE_FRAMES, RELEASE_FPS)
	_sprite.sprite_frames = frames
	_sprite.position = (get_node(NodePath(skill.cast_pose)) as Marker2D).position
	_sprite.offset = Vector2.ZERO
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"charge")


func release() -> void:
	var pin: Array = RELEASE_PIN[skill.id]
	var size: Vector2 = _sprite.sprite_frames.get_frame_texture(&"release", 0).get_size()
	_sprite.position = (get_node(NodePath(pin[0])) as Marker2D).position
	_sprite.offset = {&"right": Vector2(-size.x / 2.0, 0), &"left": Vector2(size.x / 2.0, 0),
			&"bottom": Vector2(0, -size.y / 2.0), &"center": Vector2.ZERO}[pin[1]]
	_sprite.play(&"release")


func phase() -> StringName:
	return _sprite.animation


func _add(frames: SpriteFrames, animation: StringName, count: int, fps: float) -> void:
	frames.add_animation(animation)
	frames.set_animation_loop(animation, false)
	frames.set_animation_speed(animation, fps)
	for i in count:
		frames.add_frame(animation, load(FRAMES_DIR % [skill.id, animation, i + 1]))


func _on_animation_finished() -> void:
	if _sprite.animation == &"release":
		queue_free()
		return
	_sprite.set_frame_and_progress(CHARGE_LOOP_FROM, 0.0)
	_sprite.play(&"charge")
