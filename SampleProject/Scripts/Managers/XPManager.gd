extends ManagerBase
class_name XPManager

## XP and Level Progression Manager
## Manages player experience points and levels.
## D841: рівень сам не дає статів — лише очки атрибутів (AttributeManager, D335) і JP (SkillManager, D497), що їх витрачає гравець.

## D488: найвищий рівень демо (було 99, D285); на ньому досвід більше не рахується, смуга показує MAX.
const MAX_LEVEL := 20
## D297, D492: крива досвіду — дані: to_next[рівень − 1] досвіду до наступного рівня, по числу на рівні 1 … MAX_LEVEL − 1.
const CURVE_PATH := "res://SampleProject/Resources/Data/xp_curve.json"

# Current XP and level state
var current_xp: int = 0
var current_level: int = 1
var xp_for_next_level: int = 0
var _curve: Dictionary

# Signals
signal xp_gained(amount: int, new_total: int)
signal level_up(new_level: int, old_level: int)

func _initialize():
	"""Initialize XPManager"""
	_curve = JSON.parse_string(FileAccess.get_file_as_string(CURVE_PATH))
	assert(_curve.to_next.size() == MAX_LEVEL - 1, "XPManager: xp_curve.json needs %d steps" % (MAX_LEVEL - 1))
	xp_for_next_level = _calculate_xp_requirement(current_level)
	DebugLogger.info("XPManager: Initialized", "XPManager")

## Add XP to player
func add_xp(amount: int) -> void:
	if amount < 0:
		amount = 0 # Ignore negative XP gain to prevent exploits/bugs
	if current_level >= MAX_LEVEL:
		return
	current_xp += amount
	xp_gained.emit(amount, current_xp)
	DebugLogger.verbose("XPManager: Gained %d XP, total: %d/%d" % [amount, current_xp, xp_for_next_level], "XPManager")
	_check_level_up()

## Check if player should level up
func _check_level_up() -> void:
	while current_level < MAX_LEVEL and current_xp >= xp_for_next_level:
		var old_level = current_level
		current_level += 1
		current_xp -= xp_for_next_level
		xp_for_next_level = _calculate_xp_requirement(current_level)

		if current_level >= MAX_LEVEL:
			current_xp = 0

		DebugLogger.info("XPManager: Level up! %d -> %d" % [old_level, current_level], "XPManager")

		# Emit to both internal and EventBus
		level_up.emit(current_level, old_level)
		EventBus.player_leveled_up.emit(current_level, old_level)

## Calculate XP requirement for given level; на MAX_LEVEL наступного рівня немає — 0.
func _calculate_xp_requirement(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(_curve.to_next[level - 1])

## D488: найвищий рівень досягнуто — досвід не рахується, смуга показує MAX.
func is_max_level() -> bool:
	return current_level >= MAX_LEVEL

## Get current XP as percentage (0.0 to 1.0)
func get_xp_percentage() -> float:
	if is_max_level():
		return 1.0
	if xp_for_next_level <= 0:
		return 0.0
	return float(current_xp) / float(xp_for_next_level)

## Get current level
func get_level() -> int:
	return current_level

## Reset XP and level (for new game)
func reset() -> void:
	current_xp = 0
	current_level = 1
	xp_for_next_level = _calculate_xp_requirement(1)
	DebugLogger.info("XPManager: Reset to level 1", "XPManager")

## Рівень і досвід із сейва (B79) — без сигналу підвищення рівня; панелі XP оновлюються через xp_gained.
## Сейв зі старим капом 99 (D488) лягає на MAX_LEVEL.
func restore(level: int, xp: int) -> void:
	current_level = mini(level, MAX_LEVEL)
	current_xp = 0 if current_level >= MAX_LEVEL else xp
	xp_for_next_level = _calculate_xp_requirement(level)
	xp_gained.emit(0, current_xp)
