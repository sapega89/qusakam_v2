extends Control
class_name LevelUpNotification

## Сповіщення про рівень (D436, Figma UI/Notification/LevelUp 484:6490): угорі по центру, під панеллю квесту.
## Рядки — те, що реально дає один рівень: Max HP і шкода (XPManager.stat_bonuses), очки атрибутів
## (attributes.json → AttributeManager.points_per_level), очки навичок (SkillManager.JP_PER_LEVEL).
## Гру не ставить на паузу; кілька рівнів поспіль ідуть у черзі. На кепі (D541) XPManager рівня не дає — сповіщення немає.

const FADE_IN := 0.3
const HOLD := 3.0
const FADE_OUT := 0.3

@onready var _level: Label = %LevelLabel
@onready var _max_hp: Label = $Panel/Column/Rows/MaxHp/Value
@onready var _damage: Label = $Panel/Column/Rows/Damage/Value
@onready var _attribute_points: Label = $Panel/Column/Rows/AttributePoints/Value
@onready var _job_points: Label = $Panel/Column/Rows/JobPoints/Value

## Рівні, що ще чекають показу (перший — той, що на екрані).
var _queue: Array[int] = []
var _tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	EventBus.player_leveled_up.connect(_on_player_leveled_up)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and not _queue.is_empty():
		_level.text = tr("Level %d") % _queue[0]


func _on_player_leveled_up(new_level: int, _old_level: int) -> void:
	show_notification(new_level)


## Рівень [param level] — у чергу; показується, щойно згасне попередній.
func show_notification(level: int) -> void:
	_queue.append(level)
	if _queue.size() == 1:
		_show_next()


## Скільки рівнів ще в черзі разом із показаним — для тестів.
func pending() -> int:
	return _queue.size()


func _show_next() -> void:
	var xp: XPManager = ServiceLocator.get_xp_manager()
	_level.text = tr("Level %d") % _queue[0]
	_max_hp.text = "+%d" % int(xp.stat_bonuses["hp_per_level"])
	_damage.text = "+%d" % int(xp.stat_bonuses["damage_per_level"])
	_attribute_points.text = "+%d" % ServiceLocator.get_attribute_manager().points_per_level
	_job_points.text = "+%d" % SkillManager.JP_PER_LEVEL
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, ^"modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(_on_shown)


func _on_shown() -> void:
	_queue.pop_front()
	if _queue.is_empty():
		visible = false
	else:
		_show_next()
