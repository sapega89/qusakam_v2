extends ManagerBase
class_name TutorialManager

## Tutorial Manager
## Triggers tutorial hints based on gameplay events

const HEALING_PALM := "healing_palm"

var tutorial_display: TutorialHintDisplay = null
## Вбивства за сесію — друге вбивство вчить важкого удару.
var _kills := 0

func _initialize() -> void:
	_connect_events()

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
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_leveled_up.connect(_on_player_leveled_up)
	EventBus.skill_unlocked.connect(_on_skill_unlocked)
	EventBus.player_staggered.connect(_on_player_staggered)

## Кожна тема показується раз на гру (seen_tutorials у сейві, D289) — show_hint сам це знає.
## Рух — TutorialHintDisplay сам, коли зʼявився в Game.

## Підказка про атаку — коли зʼявились перші вороги, а не після першого кліку: у каньйоні
## бити нікого, там лише ходять і стрибають (Sapega).
func _on_enemy_spawned(_enemy_id: String, _position: Vector2) -> void:
	_get_tutorial_display().show_hint("attack")

## Перше вбивство — XP і монети; друге — важкий удар (BACKLOG 4 + 12, D270, D289).
func _on_enemy_died(_enemy_id: String, _position: Vector2) -> void:
	_kills += 1
	_get_tutorial_display().show_hint("first_kill" if _kills == 1 else "heavy_attack")

## Перший удар ворога по героєві — блок і парирування (D265, D270, D289).
func _on_player_staggered(_duration: float) -> void:
	_get_tutorial_display().show_hint("block")

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
	display.show_hint("level_up")

func _on_skill_unlocked(skill_id: String) -> void:
	var display: TutorialHintDisplay = _get_tutorial_display()
	if skill_id == HEALING_PALM and display != null and display.current_hint == HEALING_PALM:
		display.force_hide()
