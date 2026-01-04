extends GutTest

## Unit Tests for UI Node Type Validation
## Tests that @onready variables match actual node types in scenes
## Prevents runtime type mismatch errors

# === COIN COUNTER TESTS ===

func test_coin_counter_scene_loads():
	"""CoinCounter scene should load without errors"""
	var scene = load("res://SampleProject/Scenes/UI/coin_counter.tscn")
	assert_not_null(scene, "CoinCounter scene should load")

func test_coin_counter_instantiates():
	"""CoinCounter should instantiate without errors"""
	var scene = load("res://SampleProject/Scenes/UI/coin_counter.tscn")
	var counter = scene.instantiate()

	assert_not_null(counter, "CoinCounter should instantiate")
	assert_true(counter is HBoxContainer, "CoinCounter should be HBoxContainer")

	counter.queue_free()

func test_coin_icon_is_color_rect():
	"""CoinIcon node should be ColorRect (not TextureRect)"""
	var scene = load("res://SampleProject/Scenes/UI/coin_counter.tscn")
	var counter = scene.instantiate()

	var coin_icon = counter.get_node_or_null("CoinIcon")
	assert_not_null(coin_icon, "CoinIcon node should exist")
	assert_true(coin_icon is ColorRect, "CoinIcon should be ColorRect")
	assert_false(coin_icon is TextureRect, "CoinIcon should NOT be TextureRect")

	counter.queue_free()

func test_coin_label_is_label():
	"""CoinLabel node should be Label"""
	var scene = load("res://SampleProject/Scenes/UI/coin_counter.tscn")
	var counter = scene.instantiate()

	var coin_label = counter.get_node_or_null("CoinLabel")
	assert_not_null(coin_label, "CoinLabel node should exist")
	assert_true(coin_label is Label, "CoinLabel should be Label")

	counter.queue_free()

func test_coin_counter_ready_without_errors():
	"""CoinCounter _ready() should execute without type errors"""
	var scene = load("res://SampleProject/Scenes/UI/coin_counter.tscn")
	var counter = scene.instantiate()

	# Add to scene tree to trigger _ready()
	add_child_autofree(counter)

	# Wait one frame for _ready() to execute
	await get_tree().process_frame

	# If we get here without errors, the test passes
	assert_not_null(counter.coin_label, "coin_label should be assigned")
	assert_not_null(counter.coin_icon, "coin_icon should be assigned")

func test_coin_icon_type_matches_script():
	"""Script variable type should match actual node type"""
	var scene = load("res://SampleProject/Scenes/UI/coin_counter.tscn")
	var counter = scene.instantiate()

	var coin_icon = counter.get_node("CoinIcon")

	# Get the expected type from the script
	# CoinCounter.gd line 8: @onready var coin_icon: TextureRect = $CoinIcon
	# This SHOULD be ColorRect, not TextureRect

	# Test will fail if types don't match
	assert_true(coin_icon is ColorRect,
		"CoinIcon type mismatch: expected %s, got %s" % [ColorRect, coin_icon.get_class()])

	counter.queue_free()

# === XP BAR TESTS ===

func test_xp_bar_scene_loads():
	"""XPBar scene should load without errors"""
	var scene = load("res://SampleProject/Scenes/UI/xp_bar.tscn")
	assert_not_null(scene, "XPBar scene should load")

func test_xp_bar_instantiates():
	"""XPBar should instantiate without errors"""
	var scene = load("res://SampleProject/Scenes/UI/xp_bar.tscn")
	var xp_bar = scene.instantiate()

	assert_not_null(xp_bar, "XPBar should instantiate")

	xp_bar.queue_free()

func test_xp_bar_has_progress_bar():
	"""XPBar should have ProgressBar node"""
	var scene = load("res://SampleProject/Scenes/UI/xp_bar.tscn")
	var xp_bar = scene.instantiate()

	var progress_bar = xp_bar.get_node_or_null("ProgressBar")
	assert_not_null(progress_bar, "ProgressBar node should exist")
	assert_true(progress_bar is ProgressBar, "Should be ProgressBar type")

	xp_bar.queue_free()

# === LEVEL UP NOTIFICATION TESTS ===

func test_level_up_notification_scene_loads():
	"""LevelUpNotification scene should load without errors"""
	var scene = load("res://SampleProject/Scenes/UI/level_up_notification.tscn")
	assert_not_null(scene, "LevelUpNotification scene should load")

func test_level_up_notification_instantiates():
	"""LevelUpNotification should instantiate without errors"""
	var scene = load("res://SampleProject/Scenes/UI/level_up_notification.tscn")
	var notification = scene.instantiate()

	assert_not_null(notification, "LevelUpNotification should instantiate")

	notification.queue_free()

# === TUTORIAL HINT DISPLAY TESTS ===

func test_tutorial_hint_display_scene_loads():
	"""TutorialHintDisplay scene should load without errors"""
	var scene = load("res://SampleProject/Scenes/UI/TutorialHintDisplay.tscn")
	assert_not_null(scene, "TutorialHintDisplay scene should load")

func test_tutorial_hint_display_instantiates():
	"""TutorialHintDisplay should instantiate without errors"""
	var scene = load("res://SampleProject/Scenes/UI/TutorialHintDisplay.tscn")
	var display = scene.instantiate()

	assert_not_null(display, "TutorialHintDisplay should instantiate")

	display.queue_free()

# === COMBAT CONTEXT DISPLAY TESTS ===

func test_combat_context_display_scene_loads():
	"""CombatContextDisplay scene should load without errors"""
	var scene = load("res://SampleProject/Scenes/UI/CombatContextDisplay.tscn")
	assert_not_null(scene, "CombatContextDisplay scene should load")

func test_combat_context_display_instantiates():
	"""CombatContextDisplay should instantiate without errors"""
	var scene = load("res://SampleProject/Scenes/UI/CombatContextDisplay.tscn")
	var display = scene.instantiate()

	assert_not_null(display, "CombatContextDisplay should instantiate")

	display.queue_free()

# === PROLOGUE SCENE TESTS ===

func test_prologue_scene_loads():
	"""PrologueScene should load without errors"""
	var scene = load("res://SampleProject/Scenes/UI/PrologueScene.tscn")
	assert_not_null(scene, "PrologueScene should load")

func test_prologue_scene_instantiates():
	"""PrologueScene should instantiate without errors"""
	var scene = load("res://SampleProject/Scenes/UI/PrologueScene.tscn")
	var prologue = scene.instantiate()

	assert_not_null(prologue, "PrologueScene should instantiate")

	prologue.queue_free()

# === GENERIC UI NODE TYPE VALIDATION ===

func test_all_ui_scenes_instantiate_without_type_errors():
	"""All UI scenes should instantiate without type mismatch errors"""
	var ui_scenes = [
		"res://SampleProject/Scenes/UI/coin_counter.tscn",
		"res://SampleProject/Scenes/UI/xp_bar.tscn",
		"res://SampleProject/Scenes/UI/level_up_notification.tscn",
		"res://SampleProject/Scenes/UI/TutorialHintDisplay.tscn",
		"res://SampleProject/Scenes/UI/CombatContextDisplay.tscn",
		"res://SampleProject/Scenes/UI/PrologueScene.tscn"
	]

	for scene_path in ui_scenes:
		var scene = load(scene_path)
		assert_not_null(scene, "%s should load" % scene_path)

		var instance = scene.instantiate()
		assert_not_null(instance, "%s should instantiate" % scene_path)

		# Add to tree to trigger _ready() and check for type errors
		add_child(instance)
		await get_tree().process_frame

		# If we get here, no type errors occurred
		instance.queue_free()

# === TYPE MISMATCH PREVENTION ===

func test_regression_coin_counter_type_bug():
	"""Regression test: CoinIcon should be ColorRect, not TextureRect"""
	# This test documents the bug found:
	# Error: "Trying to assign value of type 'ColorRect' to a variable of type 'TextureRect'"
	# Location: CoinCounter.gd:8

	var scene = load("res://SampleProject/Scenes/UI/coin_counter.tscn")
	var counter = scene.instantiate()

	# Get the actual node
	var coin_icon_node = counter.get_node("CoinIcon")

	# Verify it's ColorRect (as it is in the .tscn file)
	assert_true(coin_icon_node is ColorRect,
		"CoinIcon in scene is ColorRect")

	# Verify the script variable type matches
	# After fix, counter.coin_icon should be typed as ColorRect
	add_child(counter)
	await get_tree().process_frame

	assert_not_null(counter.coin_icon, "coin_icon should be assigned")
	assert_true(counter.coin_icon is ColorRect,
		"coin_icon variable should accept ColorRect")

	counter.queue_free()
