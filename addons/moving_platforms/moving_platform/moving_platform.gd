extends Interactable
class_name MovingPlatform

## Emitted when the platform comes to a complete stop
signal stopped
## Emitted when the platform starts moving forward (toward final_pos_marker)
signal moving_forward
## Emitted when the platform starts moving backward (toward original position)
signal moving_backward

# Configuration resource - controls MOVEMENT BEHAVIOR only
@export_category("Configuration")
@export var config: MovingPlatformConfig

# Tween resource - controls ALL TIMING and EASING
@export_category("Tween Settings")
@export var tween_resource: TweenResource

# Node references
@export_category("References")
@export var final_pos_marker : Marker2D
@export var subsequent_platforms : Array[MovingPlatform] = []
@export_group("Components")
@export var platform: AnimatableBody2D
@export var platform_line: Line2D

var original_position: Vector2
var current_tween: Tween  # We need to store this for TRIGGERED/TOGGLE states

func _ready() -> void:
	_check_connections()
	
	original_position = global_position 
	_update_path_visualization()        
	
	if activator:
		return
	
	if config and config.type == config.PlatformType.LOOP: 
		move()

func _update_path_visualization() -> void:
	if !final_pos_marker or !platform_line: 
		push_warning("MovingPlatform: Missing final_pos_marker or platform_line for visualization")
		return
	
	platform_line.clear_points()
	if final_pos_marker:
		platform_line.add_point(Vector2.ZERO)
		platform_line.add_point(to_local(final_pos_marker.global_position))
	platform_line.queue_redraw()

func _check_connections() -> void:
	# Create default TweenResource if none is assigned
	if not tween_resource:
		tween_resource = TweenResource.new()
		push_warning("No Tween Resource Created In Inspector -> Created a new one")
	else:
		tween_resource = tween_resource.duplicate() # Avoid shared references
	
	if not config:
		config = MovingPlatformConfig.new()
		push_warning("No Platform Config Created In Inspector -> Created a new one")
		
	if not activator:
		push_error(name + " is missing activator, cannot setup connections")
		return
		
	if !activator.activated.is_connected(_activated) and activator.activated.connect(_activated) != OK:
		push_error("Platform " + name + " failed to connect activated signal")
	if !activator.activated.is_connected(_activated) and activator.deactivated.connect(_deactivated) != OK:
		push_error("Platform " + name + " failed to connect deactivated signal")

func move() -> void:
	if !config:
		push_error("MovingPlatform: Cannot move - missing config")
		return
	
	if !final_pos_marker:
		push_error("MovingPlatform: Cannot move - missing final_pos_marker")
		return
	
	if config.delay:
		await get_tree().create_timer(config.delay).timeout
	
	# Clear any existing tween
	if current_tween:
		current_tween.kill()
		current_tween = null
	
	var current_pos = platform.global_position
	var end_pos = final_pos_marker.global_position
	var total_distance = original_position.distance_to(end_pos)
	var remaining_distance = current_pos.distance_to(end_pos)
	
	match config.type:
		MovingPlatformConfig.PlatformType.LOOP:
			#HACK: I should add looping functionality to tween_resource but i'm laazzzy
			# Create looping animation manually using TweenResource settings
			current_tween = create_tween()
			if not current_tween:
				push_error("MovingPlatform: Failed to create tween")
				return
				
			current_tween.set_process_mode(tween_resource.process_mode)
			current_tween.set_trans(tween_resource.trans)
			current_tween.set_ease(tween_resource.ease)
			
			# Calculate durations using TweenResource
			var forward_duration = tween_resource.get_duration_for_distance(total_distance)
			var return_duration = tween_resource.get_duration_for_distance(total_distance)
			
			current_tween.set_loops()
			current_tween.tween_property(platform, "global_position", end_pos, forward_duration)
			current_tween.tween_callback(func(): stopped.emit())
			current_tween.tween_interval(config.stopframe)
			current_tween.tween_property(platform, "global_position", original_position, return_duration)
			current_tween.tween_callback(func(): stopped.emit())
			current_tween.tween_interval(config.stopframe)
		
		MovingPlatformConfig.PlatformType.TRIGGERED, MovingPlatformConfig.PlatformType.TOGGLE, MovingPlatformConfig.PlatformType.ONE_WAY:
			# Use TweenResource to create the tween but store it for later control
			var tween = tween_resource.tween_property(platform, "global_position", current_pos, end_pos, remaining_distance)
			if not tween:
				push_error("MovingPlatform: Failed to create tween from resource")
				return
				
			current_tween = tween
			current_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			current_tween.tween_callback(func(): stopped.emit())
			
			if config.type in [MovingPlatformConfig.PlatformType.TRIGGERED, MovingPlatformConfig.PlatformType.TOGGLE]:
				current_tween.pause()
	
	moving_forward.emit()
	
	if config.subsequent_delay > 0 and subsequent_platforms.size() > 0:
		await get_tree().create_timer(config.subsequent_delay).timeout
		for other_platform in subsequent_platforms:
			if other_platform:
				other_platform.move()
			else:
				push_warning("MovingPlatform: Invalid platform in subsequent_platforms array")

func play_backwards() -> void:
	if !config:
		push_error("MovingPlatform: Cannot play backwards - missing config")
		return
	
	# Clear any existing tween
	if current_tween:
		current_tween.kill()
		current_tween = null
	
	var current_pos = platform.global_position
	var remaining_distance = current_pos.distance_to(original_position)
	
	# Calculate duration with backwards scale
	var base_duration = tween_resource.get_duration_for_distance(remaining_distance)
	var backwards_duration = base_duration / config.backwards_scale
	
	# Create manual tween for backwards movement using TweenResource settings
	current_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if not current_tween:
		push_error("MovingPlatform: Failed to create backwards tween")
		return
		
	current_tween.set_trans(tween_resource.trans)
	current_tween.set_ease(tween_resource.ease)
	current_tween.tween_property(platform, "global_position", original_position, backwards_duration)
	current_tween.tween_callback(func(): stopped.emit())
	
	moving_backward.emit()

func _activated() -> void:
	_check_connections()
	
	
	match config.type:
		MovingPlatformConfig.PlatformType.LOOP:
			if current_tween:
				if !current_tween.is_running():
					move()
			else:
				move()
		
		
		_:
			move()
			if current_tween:
				current_tween.play()  # Resume if paused

func _deactivated() -> void:
	if !config:
		push_warning("MovingPlatform: Cannot deactivate - missing config")
		return
	
	match config.type:
		MovingPlatformConfig.PlatformType.TRIGGERED:
			if current_tween:
				current_tween.pause()
			stopped.emit()
		
		MovingPlatformConfig.PlatformType.TOGGLE:
			play_backwards()

func _on_screen_detector_screen_entered() -> void:
	if config and config.move_on_screen_entered:
		move()
