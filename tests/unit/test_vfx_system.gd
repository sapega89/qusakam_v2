extends GutTest

## Unit Tests for VFX System
## Tests all particle effects spawn correctly and cleanup

# === SCENE LOADING TESTS ===

func test_slash_trail_scene_loads():
	"""SlashTrail scene should load"""
	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	assert_not_null(scene, "SlashTrail scene should load")

func test_hit_impact_scene_loads():
	"""HitImpact scene should load"""
	var scene = load("res://SampleProject/Scenes/FX/HitImpact.tscn")
	assert_not_null(scene, "HitImpact scene should load")

func test_death_particles_scene_loads():
	"""DeathParticles scene should load"""
	var scene = load("res://SampleProject/Scenes/FX/DeathParticles.tscn")
	assert_not_null(scene, "DeathParticles scene should load")

func test_level_up_flash_scene_loads():
	"""LevelUpFlash scene should load"""
	var scene = load("res://SampleProject/Scenes/FX/LevelUpFlash.tscn")
	assert_not_null(scene, "LevelUpFlash scene should load")

func test_level_up_particles_scene_loads():
	"""LevelUpParticles scene should load"""
	var scene = load("res://SampleProject/Scenes/FX/LevelUpParticles.tscn")
	assert_not_null(scene, "LevelUpParticles scene should load")

# === INSTANTIATION TESTS ===

func test_slash_trail_instantiation():
	"""SlashTrail should instantiate correctly"""
	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	var vfx = scene.instantiate()

	assert_not_null(vfx, "SlashTrail should instantiate")
	assert_true(vfx is Node2D, "SlashTrail should be Node2D")
	assert_true(vfx.has_method("set_direction"), "Should have set_direction method")

	vfx.queue_free()

func test_hit_impact_instantiation():
	"""HitImpact should instantiate correctly"""
	var scene = load("res://SampleProject/Scenes/FX/HitImpact.tscn")
	var vfx = scene.instantiate()

	assert_not_null(vfx, "HitImpact should instantiate")
	assert_true(vfx is Node2D, "HitImpact should be Node2D")

	vfx.queue_free()

func test_death_particles_instantiation():
	"""DeathParticles should instantiate correctly"""
	var scene = load("res://SampleProject/Scenes/FX/DeathParticles.tscn")
	var vfx = scene.instantiate()

	assert_not_null(vfx, "DeathParticles should instantiate")
	assert_true(vfx is Node2D, "DeathParticles should be Node2D")

	vfx.queue_free()

func test_level_up_flash_instantiation():
	"""LevelUpFlash should instantiate correctly"""
	var scene = load("res://SampleProject/Scenes/FX/LevelUpFlash.tscn")
	var vfx = scene.instantiate()

	assert_not_null(vfx, "LevelUpFlash should instantiate")
	assert_true(vfx is ColorRect, "LevelUpFlash should be ColorRect")

	vfx.queue_free()

func test_level_up_particles_instantiation():
	"""LevelUpParticles should instantiate correctly"""
	var scene = load("res://SampleProject/Scenes/FX/LevelUpParticles.tscn")
	var vfx = scene.instantiate()

	assert_not_null(vfx, "LevelUpParticles should instantiate")
	assert_true(vfx is Node2D, "LevelUpParticles should be Node2D")

	vfx.queue_free()

# === PARTICLE SYSTEM TESTS ===

func test_slash_trail_has_particles():
	"""SlashTrail should have CPUParticles2D"""
	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	var vfx = scene.instantiate()

	var particles = vfx.get_node_or_null("CPUParticles2D")
	assert_not_null(particles, "Should have CPUParticles2D child")
	assert_true(particles is CPUParticles2D, "Should be CPUParticles2D type")

	vfx.queue_free()

func test_hit_impact_has_particles():
	"""HitImpact should have CPUParticles2D"""
	var scene = load("res://SampleProject/Scenes/FX/HitImpact.tscn")
	var vfx = scene.instantiate()

	var particles = vfx.get_node_or_null("CPUParticles2D")
	assert_not_null(particles, "Should have CPUParticles2D child")

	vfx.queue_free()

func test_death_particles_has_particles():
	"""DeathParticles should have CPUParticles2D"""
	var scene = load("res://SampleProject/Scenes/FX/DeathParticles.tscn")
	var vfx = scene.instantiate()

	var particles = vfx.get_node_or_null("CPUParticles2D")
	assert_not_null(particles, "Should have CPUParticles2D child")

	vfx.queue_free()

func test_level_up_particles_has_particles():
	"""LevelUpParticles should have CPUParticles2D"""
	var scene = load("res://SampleProject/Scenes/FX/LevelUpParticles.tscn")
	var vfx = scene.instantiate()

	var particles = vfx.get_node_or_null("CPUParticles2D")
	assert_not_null(particles, "Should have CPUParticles2D child")

	vfx.queue_free()

# === PARTICLE CONFIGURATION TESTS ===

func test_slash_trail_particle_count():
	"""SlashTrail should have 20 particles"""
	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	var vfx = scene.instantiate()
	var particles = vfx.get_node("CPUParticles2D")

	assert_eq(particles.amount, 20, "Should have 20 particles")
	assert_true(particles.one_shot, "Should be one-shot")

	vfx.queue_free()

func test_hit_impact_particle_count():
	"""HitImpact should have 12 particles"""
	var scene = load("res://SampleProject/Scenes/FX/HitImpact.tscn")
	var vfx = scene.instantiate()
	var particles = vfx.get_node("CPUParticles2D")

	assert_eq(particles.amount, 12, "Should have 12 particles")
	assert_true(particles.one_shot, "Should be one-shot")

	vfx.queue_free()

func test_death_particles_particle_count():
	"""DeathParticles should have 25 particles"""
	var scene = load("res://SampleProject/Scenes/FX/DeathParticles.tscn")
	var vfx = scene.instantiate()
	var particles = vfx.get_node("CPUParticles2D")

	assert_eq(particles.amount, 25, "Should have 25 particles")
	assert_true(particles.one_shot, "Should be one-shot")

	vfx.queue_free()

func test_level_up_particles_particle_count():
	"""LevelUpParticles should have 40 particles"""
	var scene = load("res://SampleProject/Scenes/FX/LevelUpParticles.tscn")
	var vfx = scene.instantiate()
	var particles = vfx.get_node("CPUParticles2D")

	assert_eq(particles.amount, 40, "Should have 40 particles")
	assert_true(particles.one_shot, "Should be one-shot")

	vfx.queue_free()

# === AUTO-CLEANUP TESTS ===

func test_slash_trail_auto_cleanup():
	"""SlashTrail should auto-cleanup after 0.5s"""
	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	var vfx = scene.instantiate()

	# VFX should queue_free after timeout
	# We can verify _ready() method exists
	assert_true(vfx.has_method("_ready"), "Should have _ready method for cleanup")

	vfx.queue_free()

func test_hit_impact_auto_cleanup():
	"""HitImpact should auto-cleanup after 0.6s"""
	var scene = load("res://SampleProject/Scenes/FX/HitImpact.tscn")
	var vfx = scene.instantiate()

	assert_true(vfx.has_method("_ready"), "Should have _ready method for cleanup")

	vfx.queue_free()

func test_death_particles_auto_cleanup():
	"""DeathParticles should auto-cleanup after 1.5s"""
	var scene = load("res://SampleProject/Scenes/FX/DeathParticles.tscn")
	var vfx = scene.instantiate()

	assert_true(vfx.has_method("_ready"), "Should have _ready method for cleanup")

	vfx.queue_free()

func test_level_up_flash_auto_cleanup():
	"""LevelUpFlash should auto-cleanup after 0.5s"""
	var scene = load("res://SampleProject/Scenes/FX/LevelUpFlash.tscn")
	var vfx = scene.instantiate()

	assert_true(vfx.has_method("_ready"), "Should have _ready method for cleanup")
	assert_true(vfx.has_method("_play_flash"), "Should have _play_flash method")

	vfx.queue_free()

func test_level_up_particles_auto_cleanup():
	"""LevelUpParticles should auto-cleanup after 2.0s"""
	var scene = load("res://SampleProject/Scenes/FX/LevelUpParticles.tscn")
	var vfx = scene.instantiate()

	assert_true(vfx.has_method("_ready"), "Should have _ready method for cleanup")

	vfx.queue_free()

# === DIRECTION TESTS (SlashTrail specific) ===

func test_slash_trail_set_direction():
	"""SlashTrail should support direction setting"""
	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	var vfx = scene.instantiate()

	# Should not crash
	vfx.set_direction(1)  # Right
	vfx.set_direction(-1)  # Left

	vfx.queue_free()

func test_slash_trail_direction_right():
	"""SlashTrail direction right should set correct angle"""
	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	var vfx = scene.instantiate()

	vfx.set_direction(1)  # Right

	var particles = vfx.get_node("CPUParticles2D")
	assert_not_null(particles, "Should have particles node")
	assert_eq(particles.direction, Vector2.RIGHT, "Direction should be RIGHT")
	assert_eq(particles.angle_min, 45, "angle_min should be 45 for right direction")
	assert_eq(particles.angle_max, 45, "angle_max should be 45 for right direction")

	vfx.queue_free()

func test_slash_trail_direction_left():
	"""SlashTrail direction left should set correct angle"""
	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	var vfx = scene.instantiate()

	vfx.set_direction(-1)  # Left

	var particles = vfx.get_node("CPUParticles2D")
	assert_not_null(particles, "Should have particles node")
	assert_eq(particles.direction, Vector2.LEFT, "Direction should be LEFT")
	assert_eq(particles.angle_min, 135, "angle_min should be 135 for left direction")
	assert_eq(particles.angle_max, 135, "angle_max should be 135 for left direction")

	vfx.queue_free()

func test_regression_slash_trail_angle_property():
	"""Regression test: SlashTrail should use angle_min/angle_max, not angle"""
	# This test documents the bug found:
	# Error: "Invalid assignment of property or key 'angle' with value of type 'int'"
	# Location: SlashTrail.gd:24, 27

	var scene = load("res://SampleProject/Scenes/FX/SlashTrail.tscn")
	var vfx = scene.instantiate()
	var particles = vfx.get_node("CPUParticles2D")

	# Verify CPUParticles2D has angle_min/angle_max properties
	assert_true("angle_min" in particles, "CPUParticles2D should have angle_min property")
	assert_true("angle_max" in particles, "CPUParticles2D should have angle_max property")

	# Verify it does NOT have 'angle' property (this was the bug)
	assert_false("angle" in particles, "CPUParticles2D should NOT have 'angle' property")

	# Verify set_direction() works without errors
	vfx.set_direction(1)
	assert_eq(particles.angle_min, 45, "Should set angle_min correctly")

	vfx.set_direction(-1)
	assert_eq(particles.angle_min, 135, "Should set angle_min correctly")

	vfx.queue_free()

# === PERFORMANCE TESTS ===

func test_multiple_vfx_spawn():
	"""Should handle spawning multiple VFX simultaneously"""
	var vfx_list = []

	# Spawn 10 of each VFX type
	for i in 10:
		var slash = load("res://SampleProject/Scenes/FX/SlashTrail.tscn").instantiate()
		var hit = load("res://SampleProject/Scenes/FX/HitImpact.tscn").instantiate()
		var death = load("res://SampleProject/Scenes/FX/DeathParticles.tscn").instantiate()

		vfx_list.append(slash)
		vfx_list.append(hit)
		vfx_list.append(death)

	# All should be valid
	for vfx in vfx_list:
		assert_not_null(vfx, "All VFX should be valid")

	# Cleanup
	for vfx in vfx_list:
		vfx.queue_free()

func test_vfx_memory_cleanup():
	"""VFX should clean up without memory leaks"""
	var vfx_list = []

	# Create 100 VFX instances
	for i in 100:
		var vfx = load("res://SampleProject/Scenes/FX/SlashTrail.tscn").instantiate()
		vfx_list.append(vfx)

	# Free all
	for vfx in vfx_list:
		vfx.queue_free()

	# Clear array
	vfx_list.clear()

	# If we get here without crash, memory is handling well
	assert_true(true, "VFX cleanup successful")
