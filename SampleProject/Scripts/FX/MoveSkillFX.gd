extends "res://SampleProject/Scripts/FX/SkillCastFX.gd"

## Ефект навичок руху (v2 зріз 3, D-sv2m) з наявних кадрів, доки арт-лінія не намалює свої (звіт skills-v2-move):
## замах — без ефекту; удар — шлейф удару героя (SlashTrail: дуга, укол, «вибух»), стовпи світла — промінь
## Skyfall Blessing по обидва боки, хвиля піску — пил приземлення (LandingDust), збільшений. Розмітка — у .tscn.
## Щит Shield Charge — заклинання, що падає з неба (skills_audit, S19); поки його арту немає, щита не видно.

const SLASH_TRAIL := preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
const LANDING_DUST := preload("res://SampleProject/Scenes/FX/LandingDust.tscn")
const BEAM_FRAMES := "res://SampleProject/Assets/FX/Skills/skyfall_blessing/release_%d.png"
const BEAM_FRAME_COUNT := 3
const BEAM_FPS := 10.0
## id → що грає удар: &"arc" / &"thrust" / &"punch" — шлейф біля руки; &"pillars" — стовпи; &"wave" — хвиля пилу.
const RELEASE := {
	"dash_strike": &"arc",
	"blood_rush": &"arc",
	"wind_step": &"thrust",
	"shield_charge": &"punch",
	"heavens_anvil": &"pillars",
	"dune_quake": &"wave",
}
## Стовп світла стоїть на такій частці move_reach від героя.
const PILLAR_AT := 0.6
## Хвиля піску — пил приземлення, у стільки разів більший.
const WAVE_SCALE := 3.0
## Ефект удару живе стільки с, потім вузол зникає.
const RELEASE_LIFE := 0.5

var _phase: StringName = &"charge"


func _ready() -> void:
	pass  # замах навички руху — без ефекту


func release() -> void:
	_phase = &"release"
	var kind: StringName = RELEASE[skill.id]
	match kind:
		&"pillars":
			for side in [-1.0, 1.0]:
				_beam(Vector2(side * skill.move_reach * PILLAR_AT, $Feet.position.y))
		&"wave":
			var dust: CPUParticles2D = LANDING_DUST.instantiate()
			dust.scale = Vector2.ONE * WAVE_SCALE
			add_child(dust)
			dust.position = $Feet.position
			dust.emitting = true
			dust.get_node(^"Left").emitting = true
		_:
			var trail: Node2D = SLASH_TRAIL.instantiate()
			add_child(trail)
			trail.position = $Hand.position
			trail.scale = $Hand.scale
			trail.play(kind, false)
	get_tree().create_timer(RELEASE_LIFE).timeout.connect(queue_free)


func phase() -> StringName:
	return _phase


## Промінь світла з неба, нижнім вістрям на землі в [param at].
func _beam(at: Vector2) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_loop(&"default", false)
	frames.set_animation_speed(&"default", BEAM_FPS)
	for i in BEAM_FRAME_COUNT:
		frames.add_frame(&"default", load(BEAM_FRAMES % (i + 1)))
	var beam := AnimatedSprite2D.new()
	beam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	beam.sprite_frames = frames
	beam.scale = $Pillar.scale
	beam.offset = Vector2(0, -frames.get_frame_texture(&"default", 0).get_height() / 2.0)
	add_child(beam)
	beam.position = at
	beam.play(&"default")
