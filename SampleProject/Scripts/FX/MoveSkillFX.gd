extends "res://SampleProject/Scripts/FX/SkillCastFX.gd"

## Ефекти навичок руху (H3, D812, D828; Assets/FX/README.md → Movement skills). Розкладка й кадри — у MoveSkill.tscn.
## Ривок (dash): шлейф за спиною, поки герой мчить (1 ↔ 2), і dash_3, коли спинився. Стрибок (leap): кільце удару
## на землі під ногами. Удар: у порізів — шлейф SlashTrail біля руки (дуга крові Blood Rush, вітер Wind Step, удар героя
## Dash Strike / Shield Charge), у Heaven's Anvil — два стовпи світла з землі, у Dune Quake — дві хвилі піску в обидва
## боки. Shield Charge несе магічний щит Shield Block (H2) над позами ShieldCharge/1–3; Blood Rush — струмінь крові
## від цілі до героя (EventBus.skill_drained).

const SLASH_TRAIL := preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
## id → удар: [анімація SlashTrail біля руки, маркер масштабу] — &"arc" / &"punch" (удар героя, $Hand) чи власний
## арт &"blood_rush" / &"wind_step" ($Art, масштаб героя); &"pillars" — стовпи світла; &"wave" — хвилі піску.
const RELEASE := {
	"dash_strike": [&"arc", ^"Hand"],
	"blood_rush": [&"blood_rush", ^"Art"],
	"wind_step": [&"wind_step", ^"Art"],
	"shield_charge": [&"punch", ^"Hand"],
	"heavens_anvil": [&"pillars", ^""],
	"dune_quake": [&"wave", ^""],
}
## Навички, що несуть небесний щит (S19: щит — закляття, не спорядження).
const SKY_SHIELD := ["shield_charge"]
## Стовп світла стоїть на такій частці move_reach від героя.
const PILLAR_AT := 0.6
## За стільки с хвиля піску добігає до move_reach (кадри WaveFrames: 1, 2 удвічі довше, 3 — 0.4 с на 10 fps).
const WAVE_TIME := 0.4
## Щит гасне за стільки с після удару.
const SHIELD_FADE_AT := 0.3
## Ефект удару живе стільки с, потім вузол зникає.
const RELEASE_LIFE := 0.5
## Ширина струменя крові на екрані, px (64 px текстури × 1.5): масштаб x тягне його до цілі.
const DRAIN_LENGTH := 96.0

var _phase: StringName = &"charge"

@onready var _trail: AnimatedSprite2D = $DashTrail
@onready var _shield: AnimatedSprite2D = $SkyShield


func _ready() -> void:
	_trail.animation_finished.connect(_trail.hide)
	_shield.animation_finished.connect(_on_shield_finished)
	if skill.id in SKY_SHIELD:
		_shield.position = $ShieldWindup.position
		_shield.show()
		_shield.play(&"drop")


func move() -> void:
	if skill.move_kind == "dash":
		_trail.show()
		_trail.play(&"move")
	if skill.id in SKY_SHIELD:
		_shield.position = $ShieldMove.position


func release() -> void:
	_phase = &"release"
	if skill.move_kind == "dash":
		_trail.show()
		_trail.play(&"stop")
	else:
		_play_at($SlamRing, $Feet.position)
	if skill.id in SKY_SHIELD:
		_shield.position = $ShieldStrike.position
		get_tree().create_timer(SHIELD_FADE_AT).timeout.connect(_shield.play.bind(&"fade"))
	if skill.lifesteal > 0.0:
		EventBus.skill_drained.connect(_on_drained, CONNECT_ONE_SHOT)
	var kind: StringName = RELEASE[skill.id][0]
	match kind:
		&"pillars":
			_play_at($PillarBack, Vector2(-skill.move_reach * PILLAR_AT, $Feet.position.y))
			_play_at($PillarFront, Vector2(skill.move_reach * PILLAR_AT, $Feet.position.y))
		&"wave":
			for wave: AnimatedSprite2D in [$WaveBack, $WaveFront]:
				_play_at(wave, $Feet.position)
				var to: float = -skill.move_reach if wave.flip_h else skill.move_reach
				create_tween().tween_property(wave, ^"position:x", to, WAVE_TIME)
		_:
			var at: Marker2D = get_node(RELEASE[skill.id][1])
			var trail: Node2D = SLASH_TRAIL.instantiate()
			add_child(trail)
			trail.position = at.position
			trail.scale = at.scale
			trail.play(kind, false)
	get_tree().create_timer(RELEASE_LIFE).timeout.connect(queue_free)


func phase() -> StringName:
	return _phase


## Вузли сцени, які грає ця навичка (verify_skill_fx: власні кадри, D279); удар біля руки — RELEASE.
func sprites() -> Array[AnimatedSprite2D]:
	var used: Array[AnimatedSprite2D] = [_trail if skill.move_kind == "dash" else $SlamRing]
	if skill.id in SKY_SHIELD:
		used.append(_shield)
	if skill.lifesteal > 0.0:
		used.append($Drain)
	match RELEASE[skill.id][0]:
		&"pillars":
			used.append_array([$PillarBack, $PillarFront])
		&"wave":
			used.append_array([$WaveBack, $WaveFront])
	return used


func _play_at(sprite: AnimatedSprite2D, at: Vector2) -> void:
	sprite.position = at
	sprite.show()
	sprite.play(&"default")


func _on_shield_finished() -> void:
	if _shield.animation == &"drop":
		_shield.play(&"hold")
	elif _shield.animation == &"fade":
		_shield.hide()


## Струмінь крові від цілі (правий кінець) до грудей героя (лівий), розтягнутий на відстань між ними.
func _on_drained(source: Node, target: Node, _amount: int) -> void:
	if source != get_parent():
		return
	var drain: AnimatedSprite2D = $Drain
	var span: Vector2 = to_local(target.global_position) - $Chest.position
	drain.rotation = span.angle()
	drain.scale.x = drain.scale.y * span.length() / DRAIN_LENGTH
	_play_at(drain, $Chest.position)
