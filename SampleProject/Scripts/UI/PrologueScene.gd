extends Control
class_name PrologueScene

## Prologue Story Screen
## Shows narrative context before game starts

@onready var story_label: Label = $Panel/MarginContainer/VBoxContainer/StoryLabel
@onready var continue_label: Label = $Panel/MarginContainer/VBoxContainer/ContinueLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

const STORY_TEXT = """The Dark Realm has awakened.

Ancient evil stirs beneath the forgotten crypts,
corrupting all who dare enter.

You are the last guardian, chosen by fate
to venture into the darkness and restore light.

Each enemy you defeat weakens the corruption.
Each level you gain brings you closer to the truth.

Your journey begins now..."""

var can_continue: bool = false

func _ready() -> void:
	"""Initialize prologue sequence"""
	story_label.text = STORY_TEXT
	continue_label.visible = false
	fade_overlay.modulate = Color.BLACK

	_play_prologue_sequence()

func _play_prologue_sequence() -> void:
	"""Plays fade in, wait, then allow continue"""
	# Fade in from black (2s)
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate", Color.TRANSPARENT, 2.0)
	await tween.finished

	# Wait a bit, then show "Press any key"
	await get_tree().create_timer(3.0).timeout

	continue_label.visible = true
	can_continue = true

	# Pulse continue text
	_pulse_continue_label()

func _pulse_continue_label() -> void:
	"""Pulses the 'continue' text to draw attention"""
	while can_continue:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(continue_label, "modulate:a", 0.3, 0.8)
		tween.tween_property(continue_label, "modulate:a", 1.0, 0.8)
		await get_tree().create_timer(1.6).timeout

func _input(event: InputEvent) -> void:
	"""Handle player input to continue"""
	if not can_continue:
		return

	# Any key/button press continues
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed():
			_transition_to_game()

func _transition_to_game() -> void:
	"""Fades out and loads main game"""
	can_continue = false

	# Fade to black
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate", Color.BLACK, 1.0)
	await tween.finished

	# Load main game scene
	# Check if Game.tscn exists, otherwise load MainMenu
	var game_scene = "res://SampleProject/Game.tscn"
	if ResourceLoader.exists(game_scene):
		get_tree().change_scene_to_file(game_scene)
	else:
		# Fallback to main menu
		get_tree().change_scene_to_file("res://SampleProject/MainMenu.tscn")
