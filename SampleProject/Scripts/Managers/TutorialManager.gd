extends ManagerBase
class_name TutorialManager

## Tutorial Manager
## Triggers tutorial hints based on gameplay events

var tutorial_display: TutorialHintDisplay = null
var has_shown_movement: bool = false
var has_shown_attack: bool = false
var has_shown_first_kill: bool = false
var has_shown_level_up: bool = false
var has_shown_xp_bar: bool = false

func _initialize() -> void:
	"""Initialize tutorial manager and connect to events"""
	DebugLogger.info("TutorialManager: Initialized", "Tutorial")

	# Connect to EventBus signals
	_connect_events()

	# Show initial movement hint after a short delay
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(2.0).timeout
		_show_movement_hint()

func _get_tutorial_display() -> TutorialHintDisplay:
	"""Lazy getter - finds TutorialHintDisplay only when needed (after Game.tscn loads)"""
	if tutorial_display:
		return tutorial_display  # Already cached

	if not is_inside_tree() or not get_tree():
		return null

	tutorial_display = get_tree().get_first_node_in_group("tutorial_hint_display")
	if tutorial_display:
		DebugLogger.verbose("TutorialManager: Found TutorialHintDisplay", "Tutorial")
	else:
		DebugLogger.verbose("TutorialManager: TutorialHintDisplay not found yet", "Tutorial")

	return tutorial_display

func _connect_events() -> void:
	"""Connects to relevant EventBus signals"""
	# Connect to combat/progression events
	EventBus.player_attacked.connect(_on_player_attacked)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_leveled_up.connect(_on_player_leveled_up)

func _show_movement_hint() -> void:
	"""Shows movement tutorial hint"""
	if has_shown_movement:
		return

	has_shown_movement = true
	var display = _get_tutorial_display()
	if not display:
		return
	display.show_hint("movement")

func _on_player_attacked() -> void:
	"""Player performed an attack"""
	if has_shown_attack:
		return

	has_shown_attack = true
	var display = _get_tutorial_display()
	if not display:
		return
	# Wait a moment, then show attack hint
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(1.0).timeout
	display.show_hint("attack")

func _on_enemy_died(_enemy_id: String = "") -> void:
	"""Enemy was killed"""
	# Show first kill hint
	if not has_shown_first_kill:
		has_shown_first_kill = true
		var display = _get_tutorial_display()
		if display:
			display.show_hint("first_kill")

	# Show XP bar hint after second kill
	elif not has_shown_xp_bar:
		has_shown_xp_bar = true
		var display = _get_tutorial_display()
		if display:
			if is_inside_tree() and get_tree():
				await get_tree().create_timer(2.0).timeout  # Wait for XP animation
			display.show_hint("xp_bar")

func _on_player_leveled_up(_new_level: int, _old_level: int) -> void:
	"""Player leveled up"""
	if has_shown_level_up:
		return

	has_shown_level_up = true
	var display = _get_tutorial_display()
	if not display:
		return
	# Show level up hint after VFX finishes
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(3.5).timeout
	display.show_hint("level_up")

func reset_tutorial() -> void:
	"""Resets all tutorial flags (for testing)"""
	has_shown_movement = false
	has_shown_attack = false
	has_shown_first_kill = false
	has_shown_level_up = false
	has_shown_xp_bar = false

	var display = _get_tutorial_display()
	if display:
		display.reset_hints()

	DebugLogger.info("TutorialManager: Tutorial reset", "Tutorial")
