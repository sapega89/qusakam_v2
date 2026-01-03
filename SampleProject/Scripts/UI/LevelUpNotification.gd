extends Control
class_name LevelUpNotification

## Level Up Notification UI
## Displays when player levels up with stat increases

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var level_label: Label = $Panel/VBoxContainer/LevelLabel
@onready var stats_label: Label = $Panel/VBoxContainer/StatsLabel

var display_duration: float = 3.0

func _ready() -> void:
	"""Initialize and connect to level up events"""
	visible = false
	modulate = Color(1, 1, 1, 0)  # Start transparent

	# Connect to EventBus
	EventBus.player_leveled_up.connect(_on_player_leveled_up)

	DebugLogger.info("LevelUpNotification: Initialized", "UI")

func _on_player_leveled_up(new_level: int, old_level: int) -> void:
	"""Called when player levels up"""
	show_notification(new_level)

func show_notification(level: int) -> void:
	"""Shows the level up notification with animation"""
	var xp_manager = ServiceLocator.get_xp_manager()
	if not xp_manager:
		DebugLogger.warning("LevelUpNotification: XPManager not found", "UI")
		return

	# Update labels
	level_label.text = "Level %d" % level
	stats_label.text = "HP +%d, Damage +%d" % [
		xp_manager.stat_bonuses["hp_per_level"],
		xp_manager.stat_bonuses["damage_per_level"]
	]

	# Show and animate
	visible = true
	_animate_in()

	# Auto-hide after duration
	await get_tree().create_timer(display_duration).timeout
	_animate_out()

func _animate_in() -> void:
	"""Animates the notification appearing"""
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(self, "modulate", Color.WHITE, 0.4)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)

func _animate_out() -> void:
	"""Animates the notification disappearing"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)

	await tween.finished
	visible = false
