@tool
extends Interactable
class_name MovingPlatformDep

#TODO: Using an exported tween would be nice

signal stopped  # Signal for the when the platform hits it's starting position
signal moving_forward # Signal for the when the platform hits it's final position
signal moving_backward

# Configuration resource
@export_category("Configuration")
@export var config: MovingPlatformConfig

# Node references
@export_category("References")
@export var final_pos_marker : Marker2D # Marker defining the end position of movement
@export var other_platforms : Array[MovingPlatform] = []
@export_group("Components")
@export var platform: AnimatableBody2D  # The physical platform that moves
@export var platform_line: Line2D       # Visual representation of movement path

var tween: Tween             # Reference to active tween animation
var original_position: Vector2  # Stores starting position for movement calculations
var sub = false

# Editor-only process for visualizing the path
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_path_visualization()

# Initialization when entering the scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		original_position = global_position 
		_update_path_visualization()        
		
		# Set up activator connections if an activator exists
		if activator: 
			_setup_connections()
			return
		
		if config and config.animate_on_screen_entered:
			return
		
		# Start animation if not a triggered type
		if config and config.type == config.PlatformType.LOOP and config.automatically_animate: 
			animate()

# Updates the visual path line in the editor and during gameplay
func _update_path_visualization() -> void:
	if !final_pos_marker or !platform_line: 
		return  # Skip if no marker is set
	
	platform_line.clear_points()
	if final_pos_marker:
		# Draw line from platform to target position
		platform_line.add_point(Vector2.ZERO)  # Platform's local position
		platform_line.add_point(to_local(final_pos_marker.global_position))
	platform_line.queue_redraw()

# Sets up signal connections with the activator
func _setup_connections() -> void:
	if activator and config:
		# Connect signals based on platform type
		if config.type in [MovingPlatformConfig.PlatformType.ONE_WAY, MovingPlatformConfig.PlatformType.TRIGGERED, MovingPlatformConfig.PlatformType.TOGGLE]:
			activator.activated.connect(_activated)
			activator.deactivated.connect(_deactivated)

# Creates and configures the movement animation
func animate() -> void:
	if !config or !final_pos_marker: 
		return  # Safety check
	
	print(platform.name, " ", config.delay)
	
	if config.delay:
		await get_tree().create_timer(config.delay).timeout
	
	# Clean up any existing tween
	if tween: 
		tween.kill()
	
	var current_pos = platform.global_position
	var end_pos = final_pos_marker.global_position
	var remaining_distance = current_pos.distance_to(end_pos)
	var duration = remaining_distance / config.speed  # Calculate movement time
	
	# Create new tween with physics processing
	tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_trans(Tween.TRANS_LINEAR)
	
	# Configure tween based on platform type
	match config.type:
		MovingPlatformConfig.PlatformType.LOOP:
			# Continuous looping between start and end positions
			tween.set_loops()
			tween.tween_property(platform, "global_position", end_pos, duration)
			tween.tween_callback(func(): stopped.emit())
			tween.tween_interval(config.stopframe)  # Pause at end position
			# Return movement
			var return_duration = original_position.distance_to(end_pos) / config.speed
			tween.tween_property(platform, "global_position", original_position, return_duration)
			tween.tween_callback(func(): stopped.emit())
			tween.tween_interval(config.stopframe)  # Pause at start position
		
		MovingPlatformConfig.PlatformType.TRIGGERED, MovingPlatformConfig.PlatformType.TOGGLE, MovingPlatformConfig.PlatformType.ONE_WAY:
			# Single movement to end position
			tween.tween_property(platform, "global_position", end_pos, duration)
			tween.tween_callback(func(): stopped.emit())
			# Pause initially for triggered types
			if config.type in [MovingPlatformConfig.PlatformType.TRIGGERED, MovingPlatformConfig.PlatformType.TOGGLE]:
				tween.pause()
				
	moving_forward.emit()
	
	# After animation completes, trigger next platforms
	if config.subsequent_delay > 0 and other_platforms.size() > 0:
		await get_tree().create_timer(config.subsequent_delay).timeout
		for platform in other_platforms:
			if platform:
				platform.animate()

# Plays animation in reverse (back to original position)
func play_backwards() -> void:
	if !config:
		return
	
	if tween:
		tween.kill()
	
	var current_pos = platform.global_position
	var remaining_distance = current_pos.distance_to(original_position)
	var duration = (remaining_distance / config.speed) / config.backwards_scale
	
	# Create return tween
	tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_trans(Tween.TRANS_LINEAR)
	
	# Start with a brief pause if needed
	if config.stopframe:
		stopped.emit()
		await tween.tween_interval(config.stopframe).finished
	
	# Create return tween
	tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_trans(Tween.TRANS_LINEAR)
	
	# Main movement
	tween.tween_property(platform, "global_position", original_position, duration)
	tween.tween_callback(func(): stopped.emit())  # Emit stopped again when complete
	
	tween.play()
	moving_backward.emit()  # Then emit moving backward

# Called when activator is activated
func _activated() -> void:
	if !config or !final_pos_marker: 
		return
	
	match config.type:
		MovingPlatformConfig.PlatformType.TRIGGERED, MovingPlatformConfig.PlatformType.ONE_WAY:
			# Start or resume forward movement
			animate()
			tween.play()
		
		MovingPlatformConfig.PlatformType.TOGGLE:
			animate()
			tween.play()

# Called when activator is deactivated
func _deactivated() -> void:
	if !config:
		return
	
	match config.type:
		MovingPlatformConfig.PlatformType.TRIGGERED:
			# Pause movement when deactivated
			tween.pause()
			stopped.emit()
		
		MovingPlatformConfig.PlatformType.TOGGLE:
			# Return to start position when deactivated
			play_backwards()

# Called when platform enters the screen
func _on_screen_detector_screen_entered() -> void:
	if config and config.animate_on_screen_entered and not Engine.is_editor_hint():
		animate()  # Start animation if configured to do so

# Setter for activator with additional behavior
func _set_activator(value):
		super(value)
		if config:
			config.animate_on_screen_entered = false  # Disable screen entry animation when activator exists
