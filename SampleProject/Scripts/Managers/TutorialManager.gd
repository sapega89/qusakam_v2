extends ManagerBase
class_name TutorialManager

## Tutorial Manager
## Triggers tutorial hints based on gameplay events

const HEALING_PALM := "healing_palm"

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
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_leveled_up.connect(_on_player_leveled_up)
	EventBus.skill_unlocked.connect(_on_skill_unlocked)

func _show_movement_hint() -> void:
	"""Shows movement tutorial hint"""
	if has_shown_movement:
		return

	has_shown_movement = true
	var display = _get_tutorial_display()
	if not display:
		return
	display.show_hint("movement")

## Підказка про атаку — коли зʼявились перші вороги, а не після першого кліку: у каньйоні
## бити нікого, там лише ходять і стрибають (Sapega).
func _on_enemy_spawned(_enemy_id: String, _position: Vector2) -> void:
	# show_hint сам показує раз; зайнятий іншою підказкою — спробує на наступному ворогові
	_get_tutorial_display().show_hint("attack")

func _on_enemy_died(_enemy_id: String, _position: Vector2) -> void:
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

## D252/D261: Длань лікування відкривається на 2-му рівні — підвищення рівня просить її вивчити;
## підказка висить, доки Длань не вивчено (Skills у меню гри). Інакше — звичайна підказка першого рівня.
func _on_player_leveled_up(_new_level: int, _old_level: int) -> void:
	# Show the hint after the level-up VFX finishes
	await get_tree().create_timer(3.5).timeout
	var display: TutorialHintDisplay = _get_tutorial_display()
	if display == null:  # поза Game.tscn (меню, тести менеджерів) підказок немає
		return
	if ServiceLocator.get_skill_manager().can_unlock(HEALING_PALM) == SkillManager.Result.OK:
		display.show_hint(HEALING_PALM, true, true)
		return
	if has_shown_level_up:
		return
	has_shown_level_up = true
	display.show_hint("level_up")

func _on_skill_unlocked(skill_id: String) -> void:
	var display: TutorialHintDisplay = _get_tutorial_display()
	if skill_id == HEALING_PALM and display != null and display.current_hint == HEALING_PALM:
		display.force_hide()

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
