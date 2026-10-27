extends ManagerBase
class_name TutorialManager

## Tutorial Manager
## Triggers tutorial hints based on gameplay events

const HEALING_PALM := "healing_palm"
## D743: підказка першого кольору підказки удару ворога (EnemyLogic.TELL_*, D504) — тема tell_<колір>.
const TELL_TOPIC := "tell_%s"

## Вбивства за сесію — друге вбивство вчить важкого удару.
var _kills := 0

func _initialize() -> void:
	_connect_events()

## Усі підказки — «?» через TipTray.show_tip (D744): там же брама Hints і «раз за проходження» (D745, D746).
## Поза Game.tscn (меню, тести менеджерів) TipTray немає — і підказок немає.
func _tray() -> Node:
	return get_tree().get_first_node_in_group(&"tip_tray")

func _connect_events() -> void:
	"""Connects to relevant EventBus signals"""
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_leveled_up.connect(_on_player_leveled_up)
	EventBus.skill_unlocked.connect(_on_skill_unlocked)
	EventBus.player_staggered.connect(_on_player_staggered)
	EventBus.enemy_tell_shown.connect(_on_enemy_tell_shown)
	EventBus.leanings_changed.connect(_on_leanings_changed)

## Рух — TipTray сам, коли зʼявився в Game.

## Підказка про атаку — коли зʼявились перші вороги, а не після першого кліку: у каньйоні
## бити нікого, там лише ходять і стрибають (Sapega).
func _on_enemy_spawned(_enemy_id: String, _position: Vector2) -> void:
	_tray().show_tip("attack")

## Перше вбивство — XP і монети; друге — важкий удар (BACKLOG 4 + 12, D270, D289).
func _on_enemy_died(_enemy_id: String, _position: Vector2) -> void:
	_kills += 1
	_tray().show_tip("first_kill" if _kills == 1 else "heavy_attack")

## Перший удар ворога по героєві — блок і парирування (D265, D270, D289).
func _on_player_staggered(_duration: float) -> void:
	_tray().show_tip("block")

## D743 (Sapega, 2026-10-26: «знаки питання, щоб пояснити, що таке жовте свічення і червоне свічення у ворога»):
## уперше герой бачить відблиск цього кольору на ворогові — «?» з тим, що він означає і яка кнопка на нього.
## «Бачить» — ворог у кадрі камери, а не десь за краєм екрана.
func _on_enemy_tell_shown(enemy: Node, kind: StringName) -> void:
	var at: Vector2 = (enemy as CanvasItem).get_global_transform_with_canvas().origin
	if (enemy as CanvasItem).get_viewport_rect().has_point(at):
		_tray().show_tip(TELL_TOPIC % kind)

## D252/D261: Длань лікування відкривається на 2-му рівні — підвищення рівня просить її вивчити;
## «?» чекає, доки Длань не вивчено (Skills у меню гри). Інакше — звичайна підказка першого рівня.
func _on_player_leveled_up(_new_level: int, _old_level: int) -> void:
	# Show the hint after the level-up VFX finishes
	await get_tree().create_timer(3.5).timeout
	var tray: Node = _tray()
	if tray == null:  # поза Game.tscn (меню, тести менеджерів) підказок немає
		return
	if ServiceLocator.get_skill_manager().can_unlock(HEALING_PALM) == SkillManager.Result.OK:
		tray.show_tip(HEALING_PALM)
		return
	tray.show_tip("level_up")

## D725 (oath_affinity_plan п. 6): перший нахил до шляху — «?» про те, що стиль бою й вчинки ведуть до шляху; раз за проходження.
func _on_leanings_changed() -> void:
	var tray: Node = _tray()
	if tray != null:  # поза Game.tscn (тести менеджерів) підказок немає
		tray.show_tip("paths")

func _on_skill_unlocked(skill_id: String) -> void:
	var tray: Node = _tray()
	if skill_id == HEALING_PALM and tray != null:
		tray.retire(HEALING_PALM)
