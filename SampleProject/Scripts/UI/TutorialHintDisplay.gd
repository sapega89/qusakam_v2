extends Control
class_name TutorialHintDisplay

## Tutorial Hint Display
## Shows contextual tutorial hints to guide the player

@onready var hint_label: Label = $Panel/MarginContainer/HintLabel
@onready var panel: Panel = $Panel

# Tutorial hints for different gameplay elements
const TUTORIAL_HINTS = {
	"movement": "Use A/D or Arrow Keys to move • Space to jump",
	"attack": "Press J or Z to attack enemies",
	"first_kill": "Defeating enemies grants XP and coins!",
	"level_up": "Level up to increase HP and damage",
	"xp_bar": "XP bar fills with each kill • Level up when full",
	"coins": "Collect coins to buy items and upgrades",
	"health_low": "Health is low! Avoid damage or find healing",
	"combo": "Chain attacks for better combat flow"
}

# Track which hints have been shown
var shown_hints: Dictionary = {}
var current_hint: String = ""
var is_showing: bool = false
var display_duration: float = 4.0

func _ready() -> void:
	"""Initialize - start hidden"""
	visible = false
	is_showing = false

func show_hint(hint_key: String, force: bool = false) -> void:
	"""Shows tutorial hint if not already shown"""
	# Skip if already shown (unless forced)
	if shown_hints.get(hint_key, false) and not force:
		return

	# Skip if currently showing another hint (unless forced)
	if is_showing and not force:
		return

	var hint_text = TUTORIAL_HINTS.get(hint_key, "")
	if hint_text == "":
		DebugLogger.warning("TutorialHintDisplay: Unknown hint key '%s'" % hint_key, "Tutorial")
		return

	shown_hints[hint_key] = true
	current_hint = hint_key
	hint_label.text = hint_text

	is_showing = true
	_animate_in()

	# Auto-hide after duration
	await get_tree().create_timer(display_duration).timeout
	if is_showing and current_hint == hint_key:  # Check if not already hidden
		_animate_out()

func _animate_in() -> void:
	"""Animates hint sliding in from bottom"""
	visible = true
	panel.modulate.a = 0.0
	panel.position.y = 50

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "position:y", 0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_out() -> void:
	"""Animates hint sliding out"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(panel, "position:y", 50, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	await tween.finished
	visible = false
	is_showing = false
	current_hint = ""

func force_hide() -> void:
	"""Immediately hides the hint"""
	is_showing = false
	visible = false
	panel.modulate.a = 0.0
	current_hint = ""

func reset_hints() -> void:
	"""Resets all shown hints (for testing)"""
	shown_hints.clear()
	DebugLogger.info("TutorialHintDisplay: All hints reset", "Tutorial")
