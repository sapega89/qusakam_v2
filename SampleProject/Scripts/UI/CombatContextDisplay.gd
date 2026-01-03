extends Control
class_name CombatContextDisplay

## Combat Context Display
## Shows brief narrative hints when entering combat zones

@onready var context_label: Label = $Panel/MarginContainer/ContextLabel
@onready var panel: Panel = $Panel

var display_duration: float = 3.5
var is_showing: bool = false

# Context messages for different combat situations
const CONTEXT_MESSAGES = {
	"first_enemy": "The corruption spreads through these halls. Defeat the corrupted to weaken its grip.",
	"mini_boss": "A powerful guardian blocks your path. Steel yourself for battle.",
	"enemy_group": "Multiple foes ahead. Your skills will be tested.",
	"boss_room": "The source of corruption lies beyond. This is your final trial.",
	"treasure_guard": "Ancient treasures are protected by dark forces. Fight to claim your reward.",
	"generic": "Dark creatures lurk in every shadow. Stay vigilant."
}

func _ready() -> void:
	"""Initialize - start hidden"""
	visible = false
	is_showing = false

func show_context(context_key: String = "generic") -> void:
	"""Shows combat context message"""
	if is_showing:
		return  # Don't interrupt current message

	var message = CONTEXT_MESSAGES.get(context_key, CONTEXT_MESSAGES["generic"])
	context_label.text = message

	is_showing = true
	_animate_in()

	# Auto-hide after duration
	await get_tree().create_timer(display_duration).timeout
	if is_showing:  # Check if not already hidden
		_animate_out()

func _animate_in() -> void:
	"""Animates panel sliding in from top"""
	visible = true
	panel.modulate.a = 0.0
	panel.position.y = -50

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "position:y", 0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_out() -> void:
	"""Animates panel sliding out"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(panel, "position:y", -50, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	await tween.finished
	visible = false
	is_showing = false

func force_hide() -> void:
	"""Immediately hides the context display"""
	is_showing = false
	visible = false
	panel.modulate.a = 0.0
