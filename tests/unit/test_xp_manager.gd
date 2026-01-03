extends GutTest

## Unit Tests for XPManager
## Tests XP tracking, level progression, and stat bonuses

var xp_manager: XPManager

func before_each():
	"""Setup before each test"""
	xp_manager = XPManager.new()
	xp_manager._initialize()

func after_each():
	"""Cleanup after each test"""
	if xp_manager:
		xp_manager.free()
	xp_manager = null

# === XP GAIN TESTS ===

func test_add_xp_increases_current_xp():
	"""Adding XP should increase current_xp"""
	xp_manager.add_xp(50)
	assert_eq(xp_manager.current_xp, 50, "Current XP should be 50")

func test_add_xp_emits_signal():
	"""Adding XP should emit xp_gained signal"""
	watch_signals(xp_manager)
	xp_manager.add_xp(25)
	assert_signal_emitted(xp_manager, "xp_gained", "xp_gained signal should be emitted")

func test_xp_percentage_calculation():
	"""XP percentage should calculate correctly"""
	xp_manager.add_xp(50)  # 50/100 = 0.5
	var percentage = xp_manager.get_xp_percentage()
	assert_almost_eq(percentage, 0.5, 0.01, "XP percentage should be 0.5")

# === LEVEL UP TESTS ===

func test_level_up_at_100_xp():
	"""Should level up when reaching 100 XP"""
	xp_manager.add_xp(100)
	assert_eq(xp_manager.current_level, 2, "Should be level 2")
	assert_eq(xp_manager.current_xp, 0, "XP should reset to 0")

func test_level_up_emits_signal():
	"""Leveling up should emit level_up signal"""
	watch_signals(xp_manager)
	xp_manager.add_xp(100)
	assert_signal_emitted(xp_manager, "level_up", "level_up signal should be emitted")

func test_multiple_levels_at_once():
	"""Adding 300 XP at level 1 should level to 3"""
	xp_manager.add_xp(300)
	# Level 1->2: 100 XP, Level 2->3: 200 XP = 300 total
	assert_eq(xp_manager.current_level, 3, "Should be level 3")
	assert_eq(xp_manager.current_xp, 0, "XP should be 0")

func test_xp_overflow_carried_over():
	"""Excess XP should carry over to next level"""
	xp_manager.add_xp(150)  # Should level up with 50 XP remaining
	assert_eq(xp_manager.current_level, 2, "Should be level 2")
	assert_eq(xp_manager.current_xp, 50, "Should have 50 XP remaining")

# === STAT BONUS TESTS ===

func test_hp_bonus_level_1():
	"""Level 1 should have 0 HP bonus"""
	var bonus = xp_manager.get_hp_bonus()
	assert_eq(bonus, 0, "Level 1 should have 0 HP bonus")

func test_hp_bonus_level_2():
	"""Level 2 should have +20 HP bonus"""
	xp_manager.add_xp(100)  # Level up to 2
	var bonus = xp_manager.get_hp_bonus()
	assert_eq(bonus, 20, "Level 2 should have +20 HP bonus")

func test_hp_bonus_level_3():
	"""Level 3 should have +40 HP bonus"""
	xp_manager.add_xp(300)  # Level up to 3
	var bonus = xp_manager.get_hp_bonus()
	assert_eq(bonus, 40, "Level 3 should have +40 HP bonus")

func test_damage_bonus_level_1():
	"""Level 1 should have 0 damage bonus"""
	var bonus = xp_manager.get_damage_bonus()
	assert_eq(bonus, 0, "Level 1 should have 0 damage bonus")

func test_damage_bonus_level_2():
	"""Level 2 should have +5 damage bonus"""
	xp_manager.add_xp(100)  # Level up to 2
	var bonus = xp_manager.get_damage_bonus()
	assert_eq(bonus, 5, "Level 2 should have +5 damage bonus")

func test_damage_bonus_level_5():
	"""Level 5 should have +20 damage bonus"""
	xp_manager.add_xp(1000)  # Level up to 5
	var bonus = xp_manager.get_damage_bonus()
	assert_eq(bonus, 20, "Level 5 should have +20 damage bonus (4 × 5)")

# === XP REQUIREMENT TESTS ===

func test_xp_requirement_linear_scaling():
	"""XP requirement should scale linearly (Level × 100)"""
	assert_eq(xp_manager.xp_for_next_level, 100, "Level 1->2 should require 100 XP")

	xp_manager.add_xp(100)  # Level 2
	assert_eq(xp_manager.xp_for_next_level, 200, "Level 2->3 should require 200 XP")

	xp_manager.add_xp(200)  # Level 3
	assert_eq(xp_manager.xp_for_next_level, 300, "Level 3->4 should require 300 XP")

# === EDGE CASE TESTS ===

func test_zero_xp_gain():
	"""Adding 0 XP should do nothing"""
	xp_manager.add_xp(0)
	assert_eq(xp_manager.current_xp, 0, "Current XP should remain 0")
	assert_eq(xp_manager.current_level, 1, "Level should remain 1")

func test_negative_xp_not_allowed():
	"""Negative XP should be ignored or handled gracefully"""
	xp_manager.add_xp(-50)
	# Should either ignore or clamp to 0
	assert_true(xp_manager.current_xp >= 0, "XP should not go negative")

func test_large_xp_gain():
	"""Should handle large XP gains (10000 XP)"""
	xp_manager.add_xp(10000)
	assert_true(xp_manager.current_level > 1, "Should level up multiple times")
	assert_true(xp_manager.current_xp >= 0, "XP should be non-negative")

# === INTEGRATION TESTS ===

func test_stat_bonuses_scale_with_levels():
	"""Stat bonuses should increase consistently"""
	for level in range(2, 6):
		xp_manager.add_xp(xp_manager.xp_for_next_level)
		var expected_hp = (level - 1) * 20
		var expected_dmg = (level - 1) * 5
		assert_eq(xp_manager.get_hp_bonus(), expected_hp, "HP bonus incorrect at level %d" % level)
		assert_eq(xp_manager.get_damage_bonus(), expected_dmg, "Damage bonus incorrect at level %d" % level)
