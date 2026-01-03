extends Control
class_name XPBar

## XP Bar UI Component
## Displays player XP progress towards next level
## Connects to XPManager for automatic updates

# UI References
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var xp_label: Label = $XPLabel
@onready var level_label: Label = $LevelLabel

# Cached reference to XPManager
var xp_manager: XPManager = null

func _ready() -> void:
	"""Initialize XP Bar and connect to XPManager"""
	# Get XPManager from ServiceLocator
	xp_manager = ServiceLocator.get_xp_manager()

	if not xp_manager:
		push_error("XPBar: XPManager not found!")
		return

	# Connect to XPManager signals
	xp_manager.xp_gained.connect(_on_xp_gained)
	xp_manager.level_up.connect(_on_level_up)

	# Initialize display with current values
	_update_display()

	DebugLogger.info("XPBar: Initialized and connected to XPManager", "UI")

func _update_display() -> void:
	"""Updates the XP bar and labels"""
	if not xp_manager:
		return

	# Update progress bar
	var xp_percentage = xp_manager.get_xp_percentage()
	progress_bar.value = xp_percentage * 100.0

	# Update XP label (shows current/required XP)
	xp_label.text = "%d / %d XP" % [xp_manager.current_xp, xp_manager.xp_for_next_level]

	# Update level label
	level_label.text = "Level %d" % xp_manager.current_level

func _on_xp_gained(amount: int, new_total: int) -> void:
	"""Called when player gains XP"""
	_update_display()

	# Optional: Add visual feedback animation
	_play_xp_gain_animation(amount)

func _on_level_up(new_level: int, old_level: int) -> void:
	"""Called when player levels up"""
	_update_display()

	# Optional: Add celebratory animation
	_play_level_up_animation(new_level)

	DebugLogger.info("XPBar: Player leveled up! %d -> %d" % [old_level, new_level], "UI")

func _play_xp_gain_animation(amount: int) -> void:
	"""Plays a visual animation when gaining XP"""
	# Simple pulse animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(xp_label, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(xp_label, "modulate", Color(1.0, 1.0, 0.6), 0.1)
	tween.chain().set_parallel(true)
	tween.tween_property(xp_label, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(xp_label, "modulate", Color.WHITE, 0.1)

func _play_level_up_animation(new_level: int) -> void:
	"""Plays a celebratory animation when leveling up"""
	# Flash the entire bar
	var tween = create_tween()
	tween.set_parallel(true)

	# Pulse level label
	tween.tween_property(level_label, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(level_label, "modulate", Color(1.0, 0.8, 0.0), 0.2)

	# Flash progress bar
	tween.tween_property(progress_bar, "modulate", Color(1.0, 1.0, 0.5), 0.2)

	tween.chain().set_parallel(true)
	tween.tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(level_label, "modulate", Color.WHITE, 0.2)
	tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.2)
