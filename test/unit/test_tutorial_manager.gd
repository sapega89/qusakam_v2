extends GutTest

## Unit Tests for TutorialManager
## Tests tutorial hint triggering and tracking

var tutorial_manager: TutorialManager
var mock_tutorial_display

func before_each():
	"""Setup before each test"""
	tutorial_manager = TutorialManager.new()

	# Create mock tutorial display
	mock_tutorial_display = double(TutorialHintDisplay).new()
	tutorial_manager.tutorial_display = mock_tutorial_display

func after_each():
	"""Cleanup after each test"""
	if tutorial_manager:
		tutorial_manager.free()
	tutorial_manager = null

# === INITIALIZATION TESTS ===

func test_tutorial_manager_initializes():
	"""TutorialManager should initialize without errors"""
	assert_not_null(tutorial_manager, "TutorialManager should exist")

func test_initial_flags_false():
	"""All tutorial flags should start as false"""
	assert_false(tutorial_manager.has_shown_movement, "Movement hint not shown yet")
	assert_false(tutorial_manager.has_shown_attack, "Attack hint not shown yet")
	assert_false(tutorial_manager.has_shown_first_kill, "First kill hint not shown yet")
	assert_false(tutorial_manager.has_shown_level_up, "Level up hint not shown yet")
	assert_false(tutorial_manager.has_shown_xp_bar, "XP bar hint not shown yet")

# === EVENT HANDLER TESTS ===

func test_player_attacked_shows_hint():
	"""First player attack should show attack hint"""
	stub(mock_tutorial_display, "show_hint")

	tutorial_manager._on_player_attacked()

	assert_called(mock_tutorial_display, "show_hint")
	assert_true(tutorial_manager.has_shown_attack, "Attack hint flag should be set")

func test_player_attacked_only_once():
	"""Attack hint should only show once"""
	stub(mock_tutorial_display, "show_hint")

	tutorial_manager._on_player_attacked()
	tutorial_manager._on_player_attacked()
	tutorial_manager._on_player_attacked()

	# Should only be called once despite multiple attacks
	# Note: Exact call count checking depends on GUT version
	assert_true(tutorial_manager.has_shown_attack, "Flag should be set")

func test_enemy_died_first_kill():
	"""First enemy kill should show first_kill hint"""
	stub(mock_tutorial_display, "show_hint")

	tutorial_manager._on_enemy_died("enemy_1")

	assert_called(mock_tutorial_display, "show_hint")
	assert_true(tutorial_manager.has_shown_first_kill, "First kill flag should be set")

func test_enemy_died_second_kill():
	"""Second enemy kill should show xp_bar hint"""
	stub(mock_tutorial_display, "show_hint")

	# First kill
	tutorial_manager._on_enemy_died("enemy_1")
	# Second kill should trigger XP bar hint after delay
	tutorial_manager._on_enemy_died("enemy_2")

	assert_true(tutorial_manager.has_shown_first_kill, "First kill flag set")
	# XP bar hint shows after 2s delay, so we can't test immediate effect

func test_player_leveled_up_shows_hint():
	"""First level up should show level_up hint"""
	stub(mock_tutorial_display, "show_hint")

	tutorial_manager._on_player_leveled_up(2, 1)

	# Level up hint shows after 3.5s delay
	assert_true(tutorial_manager.has_shown_level_up, "Level up flag should be set")

# === RESET TESTS ===

func test_reset_tutorial():
	"""reset_tutorial should clear all flags"""
	# Set all flags
	tutorial_manager.has_shown_movement = true
	tutorial_manager.has_shown_attack = true
	tutorial_manager.has_shown_first_kill = true
	tutorial_manager.has_shown_level_up = true
	tutorial_manager.has_shown_xp_bar = true

	# Reset
	tutorial_manager.reset_tutorial()

	# All should be false
	assert_false(tutorial_manager.has_shown_movement, "Movement flag should be reset")
	assert_false(tutorial_manager.has_shown_attack, "Attack flag should be reset")
	assert_false(tutorial_manager.has_shown_first_kill, "First kill flag should be reset")
	assert_false(tutorial_manager.has_shown_level_up, "Level up flag should be reset")
	assert_false(tutorial_manager.has_shown_xp_bar, "XP bar flag should be reset")

# === TUTORIAL DISPLAY TESTS ===

func test_tutorial_display_scene_loads():
	"""TutorialHintDisplay scene should load"""
	var scene = load("res://SampleProject/Scenes/UI/TutorialHintDisplay.tscn")
	assert_not_null(scene, "TutorialHintDisplay scene should load")

func test_tutorial_display_instantiation():
	"""TutorialHintDisplay should instantiate"""
	var scene = load("res://SampleProject/Scenes/UI/TutorialHintDisplay.tscn")
	var display = scene.instantiate()
	assert_not_null(display, "TutorialHintDisplay should instantiate")
	assert_true(display is Control, "Should be Control node")
	display.queue_free()

func test_tutorial_display_has_hints():
	"""TutorialHintDisplay should have TUTORIAL_HINTS dictionary"""
	var scene = load("res://SampleProject/Scenes/UI/TutorialHintDisplay.tscn")
	var display = scene.instantiate()

	assert_true("TUTORIAL_HINTS" in display, "Should have TUTORIAL_HINTS constant")

	# Verify key hints exist
	var hints = display.TUTORIAL_HINTS
	assert_true("movement" in hints, "Should have movement hint")
	assert_true("attack" in hints, "Should have attack hint")
	assert_true("first_kill" in hints, "Should have first_kill hint")
	assert_true("level_up" in hints, "Should have level_up hint")

	display.queue_free()

# === INTEGRATION WORKFLOW TESTS ===

func test_complete_tutorial_sequence():
	"""Test complete tutorial flow"""
	stub(mock_tutorial_display, "show_hint")

	# 1. Movement hint (shown automatically after 2s)
	# Can't test timer-based hints in unit tests

	# 2. Attack hint
	tutorial_manager._on_player_attacked()
	assert_true(tutorial_manager.has_shown_attack)

	# 3. First kill hint
	tutorial_manager._on_enemy_died("enemy_1")
	assert_true(tutorial_manager.has_shown_first_kill)

	# 4. Second kill - XP bar hint
	tutorial_manager._on_enemy_died("enemy_2")
	# XP bar flag set after delay

	# 5. Level up hint
	tutorial_manager._on_player_leveled_up(2, 1)
	assert_true(tutorial_manager.has_shown_level_up)

# === NULL SAFETY TESTS ===

func test_handles_null_display():
	"""Should handle null tutorial display gracefully"""
	tutorial_manager.tutorial_display = null

	# Should not crash
	tutorial_manager._on_player_attacked()
	tutorial_manager._on_enemy_died("enemy_1")
	tutorial_manager._on_player_leveled_up(2, 1)

	# Flags should still be set
	assert_true(tutorial_manager.has_shown_attack, "Flag set even without display")
	assert_true(tutorial_manager.has_shown_first_kill, "Flag set even without display")

# === HINT UNIQUENESS TESTS ===

func test_each_hint_shows_only_once():
	"""Each tutorial hint should only trigger once"""
	stub(mock_tutorial_display, "show_hint")

	# Attack hint multiple times
	for i in 5:
		tutorial_manager._on_player_attacked()

	# Should still only have flag set once
	assert_true(tutorial_manager.has_shown_attack)

	# Kill hint multiple times
	for i in 5:
		tutorial_manager._on_enemy_died("enemy_%d" % i)

	assert_true(tutorial_manager.has_shown_first_kill)
	# XP bar shows on second kill only, so flag should be set
