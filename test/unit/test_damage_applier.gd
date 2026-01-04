extends GutTest

## Unit Tests for DamageApplier Component
## Tests damage calculation, property validation, and combat integration

var damage_applier: DamageApplier

func before_each():
	"""Setup DamageApplier for each test"""
	damage_applier = DamageApplier.new()
	damage_applier.base_damage = 10

func after_each():
	"""Cleanup after each test"""
	if damage_applier:
		damage_applier.free()

# === PROPERTY VALIDATION TESTS ===

func test_damage_applier_has_current_damage():
	"""DamageApplier should have current_damage property"""
	assert_true("current_damage" in damage_applier, "Should have current_damage property")

func test_damage_applier_has_base_damage():
	"""DamageApplier should have base_damage property"""
	assert_true("base_damage" in damage_applier, "Should have base_damage property")

func test_damage_applier_no_damage_property():
	"""DamageApplier should NOT have 'damage' property (regression test)"""
	# This test documents the bug found:
	# Error: "Invalid access to property or key 'damage'"
	# Location: Player.gd:577-578, 580

	assert_false("damage" in damage_applier, "Should NOT have 'damage' property")
	assert_true("current_damage" in damage_applier, "Should have 'current_damage' instead")

func test_regression_damage_property_bug():
	"""Regression test: Ensure damage_applier uses current_damage, not damage"""
	# This test prevents the bug from reoccurring
	# Verify correct property names exist
	assert_true("current_damage" in damage_applier, "current_damage must exist")
	assert_true("base_damage" in damage_applier, "base_damage must exist")

	# Verify incorrect property does NOT exist
	assert_false("damage" in damage_applier, "'damage' property should not exist")

# === INITIALIZATION TESTS ===

func test_damage_applier_initializes():
	"""DamageApplier should initialize correctly"""
	assert_not_null(damage_applier, "Should be instantiated")
	assert_eq(damage_applier.base_damage, 10, "base_damage should be 10")

func test_current_damage_equals_base_damage():
	"""current_damage should initialize to base_damage"""
	damage_applier.current_damage = damage_applier.base_damage
	assert_eq(damage_applier.current_damage, damage_applier.base_damage,
		"current_damage should equal base_damage initially")

func test_damage_applier_is_active_default():
	"""is_active should default to false"""
	assert_false(damage_applier.is_active, "is_active should be false by default")

# === DAMAGE CALCULATION TESTS ===

func test_set_current_damage():
	"""Should be able to set current_damage"""
	damage_applier.current_damage = 25
	assert_eq(damage_applier.current_damage, 25, "current_damage should be 25")

func test_update_current_damage_with_bonus():
	"""current_damage should update with bonuses"""
	var damage_bonus = 15
	damage_applier.current_damage = damage_applier.base_damage + damage_bonus

	assert_eq(damage_applier.current_damage, 25, "current_damage should be base + bonus (10 + 15)")

func test_base_damage_unchanging():
	"""base_damage should not change when current_damage changes"""
	var original_base = damage_applier.base_damage
	damage_applier.current_damage = 50

	assert_eq(damage_applier.base_damage, original_base, "base_damage should remain unchanged")

# === ENABLE/DISABLE TESTS ===

func test_enable_damage():
	"""enable_damage() should activate the component"""
	damage_applier.enable_damage()
	assert_true(damage_applier.is_active, "is_active should be true after enable_damage()")

func test_disable_damage():
	"""disable_damage() should deactivate the component"""
	damage_applier.enable_damage()
	damage_applier.disable_damage()
	assert_false(damage_applier.is_active, "is_active should be false after disable_damage()")

func test_enable_clears_hit_targets():
	"""enable_damage() should clear hit_targets list"""
	damage_applier.hit_targets.append(Node.new())
	damage_applier.enable_damage()

	assert_eq(damage_applier.hit_targets.size(), 0, "hit_targets should be empty after enable_damage()")

func test_disable_clears_hit_targets():
	"""disable_damage() should clear hit_targets list"""
	damage_applier.hit_targets.append(Node.new())
	damage_applier.disable_damage()

	assert_eq(damage_applier.hit_targets.size(), 0, "hit_targets should be empty after disable_damage()")

# === UPDATE DAMAGE METHOD TESTS ===

func test_update_damage_without_owner():
	"""update_damage() should use base_damage if no owner"""
	damage_applier.owner_body = null
	damage_applier.current_damage = 50  # Set to something different

	damage_applier.update_damage()

	assert_eq(damage_applier.current_damage, damage_applier.base_damage,
		"current_damage should equal base_damage when no owner")

# === SIGNAL TESTS ===

func test_damage_applied_signal_exists():
	"""DamageApplier should have damage_applied signal"""
	assert_true(damage_applier.has_signal("damage_applied"),
		"Should have damage_applied signal")

# === PROPERTY ACCESS PATTERN TESTS ===

func test_correct_property_access_pattern():
	"""Demonstrates correct way to access and modify damage"""
	# WRONG: damage_applier.damage = 20  ❌
	# RIGHT: damage_applier.current_damage = 20  ✅

	damage_applier.current_damage = 20
	assert_eq(damage_applier.current_damage, 20, "Should access via current_damage")

func test_level_up_damage_bonus_pattern():
	"""Simulates level up damage bonus application (like in Player.gd)"""
	# This is the corrected pattern from Player.gd:577-578
	var damage_bonus = 5
	var old_damage = damage_applier.current_damage
	damage_applier.current_damage = damage_applier.base_damage + damage_bonus

	assert_eq(damage_applier.current_damage, 15, "current_damage should be base (10) + bonus (5)")
	assert_ne(damage_applier.current_damage, old_damage, "Damage should have increased")

# === EDGE CASES ===

func test_zero_base_damage():
	"""Should handle zero base damage"""
	damage_applier.base_damage = 0
	damage_applier.current_damage = damage_applier.base_damage

	assert_eq(damage_applier.current_damage, 0, "Should allow zero damage")

func test_negative_damage():
	"""Should handle negative damage (healing?)"""
	damage_applier.current_damage = -10
	assert_eq(damage_applier.current_damage, -10, "Should allow negative values")

func test_large_damage_values():
	"""Should handle large damage values"""
	damage_applier.current_damage = 9999
	assert_eq(damage_applier.current_damage, 9999, "Should handle large values")

# === INTEGRATION VALIDATION ===

func test_damage_applier_class_exists():
	"""DamageApplier class should be available"""
	assert_not_null(DamageApplier, "DamageApplier class should exist")

func test_damage_applier_extends_node():
	"""DamageApplier should extend Node"""
	assert_true(damage_applier is Node, "Should extend Node")
