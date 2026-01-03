extends GutTest

## Integration Tests for Combat → Progression Flow
## Tests complete workflow: Kill enemy → XP → Coins → Level up

var xp_manager: XPManager
var inventory_manager: InventoryManager
var test_scene: Node

func before_each():
	"""Setup test environment"""
	xp_manager = XPManager.new()
	xp_manager._initialize()

	inventory_manager = InventoryManager.new()

	test_scene = Node.new()
	add_child_autofree(test_scene)

func after_each():
	"""Cleanup"""
	if xp_manager:
		xp_manager.free()
	if inventory_manager:
		inventory_manager.free()

# === COMBAT TO XP TESTS ===

func test_enemy_death_awards_xp():
	"""Killing an enemy should award XP"""
	# Simulate enemy death awarding 25 XP
	xp_manager.add_xp(25)

	assert_eq(xp_manager.current_xp, 25, "Should have 25 XP")
	assert_eq(xp_manager.current_level, 1, "Should still be level 1")

func test_multiple_kills_accumulate_xp():
	"""Multiple kills should accumulate XP"""
	# Kill 3 melee enemies (25 XP each)
	xp_manager.add_xp(25)  # Enemy 1
	xp_manager.add_xp(25)  # Enemy 2
	xp_manager.add_xp(25)  # Enemy 3

	assert_eq(xp_manager.current_xp, 75, "Should have 75 XP")
	assert_eq(xp_manager.current_level, 1, "Should still be level 1")

func test_four_kills_trigger_level_up():
	"""Four melee enemy kills should trigger level up"""
	watch_signals(xp_manager)

	# Kill 4 melee enemies (25 XP each = 100 XP)
	for i in 4:
		xp_manager.add_xp(25)

	assert_eq(xp_manager.current_level, 2, "Should be level 2")
	assert_eq(xp_manager.current_xp, 0, "XP should reset")
	assert_signal_emitted(xp_manager, "level_up", "Should emit level_up signal")

# === COMBAT TO COINS TESTS ===

func test_enemy_death_drops_coins():
	"""Enemy death should drop coins"""
	# Melee enemy drops 3 coins (average)
	inventory_manager.add_coins(3)

	assert_eq(inventory_manager.get_coins(), 3, "Should have 3 coins")

func test_multiple_enemies_drop_coins():
	"""Multiple enemy deaths should accumulate coins"""
	# Melee: 3 coins
	inventory_manager.add_coins(3)
	# Tank: 5 coins
	inventory_manager.add_coins(5)
	# Fast: 2 coins
	inventory_manager.add_coins(2)

	assert_eq(inventory_manager.get_coins(), 10, "Should have 10 coins")

# === XP + COINS TOGETHER ===

func test_enemy_death_awards_both():
	"""Enemy death should award both XP and coins"""
	# Simulate melee enemy death
	xp_manager.add_xp(25)  # XP reward
	inventory_manager.add_coins(3)  # Coin drop

	assert_eq(xp_manager.current_xp, 25, "Should have 25 XP")
	assert_eq(inventory_manager.get_coins(), 3, "Should have 3 coins")

func test_complete_progression_loop():
	"""Test complete progression from kills to level up"""
	watch_signals(xp_manager)

	# Kill 4 melee enemies
	for i in 4:
		# Each enemy gives XP and coins
		xp_manager.add_xp(25)
		inventory_manager.add_coins(3)

	# Verify level up
	assert_eq(xp_manager.current_level, 2, "Should level up to 2")
	assert_signal_emitted(xp_manager, "level_up")

	# Verify coins accumulated
	assert_eq(inventory_manager.get_coins(), 12, "Should have 12 coins")

	# Verify stat bonuses available
	assert_eq(xp_manager.get_hp_bonus(), 20, "Should have +20 HP bonus")
	assert_eq(xp_manager.get_damage_bonus(), 5, "Should have +5 damage bonus")

# === DIFFERENT ENEMY TYPES ===

func test_tank_enemy_progression():
	"""Tank enemies give more XP and coins"""
	# Tank: 40 XP, 5 coins
	xp_manager.add_xp(40)
	inventory_manager.add_coins(5)

	assert_eq(xp_manager.current_xp, 40, "Should have 40 XP")
	assert_eq(inventory_manager.get_coins(), 5, "Should have 5 coins")

func test_mixed_enemy_types():
	"""Killing different enemy types should work correctly"""
	# Melee: 25 XP, 3 coins
	xp_manager.add_xp(25)
	inventory_manager.add_coins(3)

	# Tank: 40 XP, 5 coins
	xp_manager.add_xp(40)
	inventory_manager.add_coins(5)

	# Fast: 20 XP, 2 coins
	xp_manager.add_xp(20)
	inventory_manager.add_coins(2)

	assert_eq(xp_manager.current_xp, 85, "Should have 85 XP total")
	assert_eq(inventory_manager.get_coins(), 10, "Should have 10 coins total")

# === LEVEL UP STAT BONUSES ===

func test_level_up_increases_stats():
	"""Level up should provide stat bonuses"""
	# Level up to 2
	xp_manager.add_xp(100)

	# Check bonuses
	var hp_bonus = xp_manager.get_hp_bonus()
	var dmg_bonus = xp_manager.get_damage_bonus()

	assert_eq(hp_bonus, 20, "Should have +20 HP")
	assert_eq(dmg_bonus, 5, "Should have +5 damage")

func test_multiple_level_ups():
	"""Multiple level ups should stack bonuses"""
	# Level to 3 (300 XP)
	xp_manager.add_xp(300)

	assert_eq(xp_manager.current_level, 3, "Should be level 3")
	assert_eq(xp_manager.get_hp_bonus(), 40, "Should have +40 HP (2 levels)")
	assert_eq(xp_manager.get_damage_bonus(), 10, "Should have +10 damage (2 levels)")

# === REALISTIC COMBAT SCENARIOS ===

func test_realistic_combat_scenario():
	"""Simulate realistic combat progression"""
	var kills = 0
	var target_level = 3

	# Keep killing enemies until we reach level 3
	while xp_manager.current_level < target_level:
		# Melee enemy
		xp_manager.add_xp(25)
		inventory_manager.add_coins(3)
		kills += 1

		# Safety check (prevent infinite loop)
		if kills > 100:
			break

	# Should reach level 3 after ~12 kills
	assert_eq(xp_manager.current_level, 3, "Should reach level 3")
	assert_true(kills >= 12 and kills <= 13, "Should take 12-13 kills to reach level 3")
	assert_true(inventory_manager.get_coins() >= 36, "Should have at least 36 coins")

func test_combat_with_coin_spending():
	"""Test progression with coin economy"""
	# Kill 5 enemies
	for i in 5:
		xp_manager.add_xp(25)
		inventory_manager.add_coins(3)

	# Spend some coins
	var spent = inventory_manager.spend_coins(10)
	assert_true(spent, "Should successfully spend coins")

	# Continue progression
	for i in 3:
		xp_manager.add_xp(25)
		inventory_manager.add_coins(3)

	# Check final state
	assert_eq(xp_manager.current_xp, 200 % 200, "XP should wrap correctly")
	assert_eq(inventory_manager.get_coins(), 14, "Should have 24 - 10 = 14 coins")

# === EDGE CASES ===

func test_level_up_with_overflow():
	"""Large XP gain should level up multiple times"""
	# Add 500 XP at once
	xp_manager.add_xp(500)

	# Should level up multiple times
	assert_true(xp_manager.current_level >= 3, "Should level up multiple times")

func test_zero_rewards():
	"""Zero rewards should not break progression"""
	xp_manager.add_xp(0)
	inventory_manager.add_coins(0)

	assert_eq(xp_manager.current_xp, 0, "XP unchanged")
	assert_eq(inventory_manager.get_coins(), 0, "Coins unchanged")

# === PERFORMANCE TESTS ===

func test_rapid_enemy_kills():
	"""Should handle rapid enemy kills (100 enemies)"""
	for i in 100:
		xp_manager.add_xp(25)
		inventory_manager.add_coins(3)

	# Should not crash
	assert_true(xp_manager.current_level > 1, "Should level up")
	assert_eq(inventory_manager.get_coins(), 300, "Should have 300 coins")

func test_boss_fight_simulation():
	"""Simulate boss fight (high XP/coin reward)"""
	# Boss gives 200 XP and 20 coins
	xp_manager.add_xp(200)
	inventory_manager.add_coins(20)

	# Should level up
	assert_eq(xp_manager.current_level, 2, "Should level up from boss")
	assert_eq(xp_manager.current_xp, 100, "Should have 100 XP overflow")
	assert_eq(inventory_manager.get_coins(), 20, "Should have 20 coins")
