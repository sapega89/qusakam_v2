extends ManagerBase
class_name XPManager

## XP and Level Progression Manager
## Manages player experience points, levels, and stat bonuses

# Current XP and level state
var current_xp: int = 0
var current_level: int = 1
var xp_for_next_level: int = 100

# Stat bonuses per level
var stat_bonuses: Dictionary = {
	"hp_per_level": 20,
	"damage_per_level": 5
}

# Signals
signal xp_gained(amount: int, new_total: int)
signal level_up(new_level: int, old_level: int)

func _initialize():
	"""Initialize XPManager"""
	DebugLogger.info("XPManager: Initialized", "XPManager")

## Add XP to player
func add_xp(amount: int) -> void:
	current_xp += amount
	xp_gained.emit(amount, current_xp)
	DebugLogger.verbose("XPManager: Gained %d XP, total: %d/%d" % [amount, current_xp, xp_for_next_level], "XPManager")
	_check_level_up()

## Check if player should level up
func _check_level_up() -> void:
	while current_xp >= xp_for_next_level:
		var old_level = current_level
		current_level += 1
		current_xp -= xp_for_next_level
		xp_for_next_level = _calculate_xp_requirement(current_level)

		DebugLogger.info("XPManager: Level up! %d -> %d" % [old_level, current_level], "XPManager")

		# Emit to both internal and EventBus
		level_up.emit(current_level, old_level)
		EventBus.player_leveled_up.emit(current_level, old_level)

## Calculate XP requirement for given level
func _calculate_xp_requirement(level: int) -> int:
	# Linear progression: 100, 200, 300, 400...
	return level * 100

## Get current XP as percentage (0.0 to 1.0)
func get_xp_percentage() -> float:
	if xp_for_next_level <= 0:
		return 0.0
	return float(current_xp) / float(xp_for_next_level)

## Get HP bonus for current level
func get_hp_bonus() -> int:
	return (current_level - 1) * stat_bonuses["hp_per_level"]

## Get damage bonus for current level
func get_damage_bonus() -> int:
	return (current_level - 1) * stat_bonuses["damage_per_level"]

## Get current level
func get_level() -> int:
	return current_level

## Reset XP and level (for new game)
func reset() -> void:
	current_xp = 0
	current_level = 1
	xp_for_next_level = 100
	DebugLogger.info("XPManager: Reset to level 1", "XPManager")
