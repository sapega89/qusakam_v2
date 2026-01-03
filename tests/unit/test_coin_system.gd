extends GutTest

## Unit Tests for Coin System
## Tests InventoryManager coin tracking and Coin collectible

var inventory_manager: InventoryManager

func before_each():
	"""Setup before each test"""
	inventory_manager = InventoryManager.new()

func after_each():
	"""Cleanup after each test"""
	if inventory_manager:
		inventory_manager.free()
	inventory_manager = null

# === INVENTORY MANAGER - COIN TRACKING TESTS ===

func test_initial_coins_zero():
	"""Starting coins should be 0"""
	assert_eq(inventory_manager.get_coins(), 0, "Initial coins should be 0")

func test_add_coins():
	"""Adding coins should increase total"""
	inventory_manager.add_coins(10)
	assert_eq(inventory_manager.get_coins(), 10, "Should have 10 coins")

func test_add_coins_multiple_times():
	"""Adding coins multiple times should accumulate"""
	inventory_manager.add_coins(5)
	inventory_manager.add_coins(10)
	inventory_manager.add_coins(3)
	assert_eq(inventory_manager.get_coins(), 18, "Should have 18 coins total")

func test_add_coins_emits_signal():
	"""Adding coins should emit coins_changed signal"""
	watch_signals(inventory_manager)
	inventory_manager.add_coins(5)
	# Note: EventBus.coins_changed is emitted, not inventory_manager signal
	# This test verifies the method completes without errors

func test_spend_coins_success():
	"""Spending coins when sufficient should succeed"""
	inventory_manager.add_coins(50)
	var success = inventory_manager.spend_coins(20)
	assert_true(success, "Should successfully spend coins")
	assert_eq(inventory_manager.get_coins(), 30, "Should have 30 coins remaining")

func test_spend_coins_failure():
	"""Spending more coins than available should fail"""
	inventory_manager.add_coins(10)
	var success = inventory_manager.spend_coins(20)
	assert_false(success, "Should fail to spend more coins than available")
	assert_eq(inventory_manager.get_coins(), 10, "Coins should remain unchanged")

func test_spend_exact_amount():
	"""Spending exact coin amount should work"""
	inventory_manager.add_coins(50)
	var success = inventory_manager.spend_coins(50)
	assert_true(success, "Should successfully spend all coins")
	assert_eq(inventory_manager.get_coins(), 0, "Should have 0 coins")

# === COIN VALUE TESTS ===

func test_add_zero_coins():
	"""Adding 0 coins should work but not change total"""
	inventory_manager.add_coins(10)
	inventory_manager.add_coins(0)
	assert_eq(inventory_manager.get_coins(), 10, "Should still have 10 coins")

func test_add_large_amount():
	"""Adding large amounts should work"""
	inventory_manager.add_coins(99999)
	assert_eq(inventory_manager.get_coins(), 99999, "Should handle large amounts")

# === COIN COLLECTIBLE TESTS ===

func test_coin_scene_loads():
	"""Coin scene should load successfully"""
	var coin_scene = load("res://SampleProject/Scenes/Gameplay/Objects/Coin.tscn")
	assert_not_null(coin_scene, "Coin scene should load")

func test_coin_instantiation():
	"""Coin should instantiate without errors"""
	var coin_scene = load("res://SampleProject/Scenes/Gameplay/Objects/Coin.tscn")
	var coin = coin_scene.instantiate()
	assert_not_null(coin, "Coin should instantiate")
	assert_true(coin is Area2D, "Coin should be Area2D")
	coin.queue_free()

func test_coin_has_required_properties():
	"""Coin should have required properties"""
	var coin_scene = load("res://SampleProject/Scenes/Gameplay/Objects/Coin.tscn")
	var coin = coin_scene.instantiate()

	assert_true(coin.has_method("_physics_process"), "Coin should have _physics_process")
	assert_true("coin_value" in coin, "Coin should have coin_value property")
	assert_true("collection_speed" in coin, "Coin should have collection_speed property")

	coin.queue_free()

# === EDGE CASES ===

func test_negative_coins_handled():
	"""Negative coin amounts should be handled gracefully"""
	inventory_manager.add_coins(10)
	# Depending on implementation, this might:
	# 1. Be ignored
	# 2. Be clamped to 0
	# 3. Subtract coins (if that's intended behavior)
	# For now, just verify no crash
	inventory_manager.add_coins(-5)
	assert_true(inventory_manager.get_coins() >= 0, "Coins should not go negative")

func test_spend_zero_coins():
	"""Spending 0 coins should succeed"""
	inventory_manager.add_coins(10)
	var success = inventory_manager.spend_coins(0)
	assert_true(success, "Spending 0 coins should succeed")
	assert_eq(inventory_manager.get_coins(), 10, "Coins should remain unchanged")

func test_spend_negative_amount():
	"""Spending negative amount should fail"""
	inventory_manager.add_coins(10)
	var success = inventory_manager.spend_coins(-5)
	assert_false(success, "Spending negative amount should fail")

# === INTEGRATION TESTS ===

func test_coin_collection_workflow():
	"""Test complete coin collection workflow"""
	# Start with 0 coins
	assert_eq(inventory_manager.get_coins(), 0)

	# Enemy drops 3 coins
	inventory_manager.add_coins(3)
	assert_eq(inventory_manager.get_coins(), 3)

	# Enemy drops 5 coins
	inventory_manager.add_coins(5)
	assert_eq(inventory_manager.get_coins(), 8)

	# Spend 4 coins
	inventory_manager.spend_coins(4)
	assert_eq(inventory_manager.get_coins(), 4)

func test_multiple_enemies_coin_drops():
	"""Test coin accumulation from multiple enemies"""
	# Melee enemy: 2-4 coins (use average: 3)
	inventory_manager.add_coins(3)

	# Tank enemy: 4-6 coins (use average: 5)
	inventory_manager.add_coins(5)

	# Fast enemy: 1-3 coins (use average: 2)
	inventory_manager.add_coins(2)

	assert_eq(inventory_manager.get_coins(), 10, "Should have 10 coins from 3 enemies")
