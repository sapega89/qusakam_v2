extends "res://SampleProject/Scripts/FX/SkillCastFX.gd"

## Ефекти навичок контролю (v2 зріз 6a, D-sv2ca1). Свого арту ще немає (ComfyUI, звіт skills-v2-control-a): удар —
## позичений шлейф героя SlashTrail біля руки, у Ground Slam — кільце удару стрибків (Smear/slam_ring). Розкладка —
## ControlSkill.tscn. Замах нічого не показує.

const SLASH_TRAIL := preload("res://SampleProject/Scenes/FX/SlashTrail.tscn")
## id → [анімація SlashTrail чи &"ring", маркер, дуга знизу вгору].
const RELEASE := {
	"rising_slash": [&"arc", ^"Hand", true],
	"sweeping_arc": [&"arc", ^"Low", false],
	"shield_bash": [&"punch", ^"Hand", false],
	"stone_palm": [&"punch", ^"Palm", false],
	"ground_slam": [&"ring", ^"Feet", false],
}
## Ефект удару живе стільки с, потім вузол зникає.
const RELEASE_LIFE := 0.5

var _phase: StringName = &"charge"


func _ready() -> void:
	pass


func release() -> void:
	_phase = &"release"
	var at: Marker2D = get_node(RELEASE[skill.id][1])
	if RELEASE[skill.id][0] == &"ring":
		var ring: AnimatedSprite2D = $SlamRing
		ring.position = at.position
		ring.show()
		ring.play(&"default")
	else:
		var trail: Node2D = SLASH_TRAIL.instantiate()
		add_child(trail)
		trail.position = at.position
		trail.scale = at.scale
		trail.play(RELEASE[skill.id][0], RELEASE[skill.id][2])
	get_tree().create_timer(RELEASE_LIFE).timeout.connect(queue_free)


func phase() -> StringName:
	return _phase
