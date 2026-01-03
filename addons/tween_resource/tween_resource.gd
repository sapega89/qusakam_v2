extends Resource
class_name TweenResource

## Duration mode: DURATION or CONSTANT_SPEED
enum DurationMode { DURATION, CONSTANT_SPEED }

@export var duration_mode: DurationMode = DurationMode.DURATION

# For DURATION mode
@export_range(0, 60, 0.1, "or_greater") var duration: float = 1.0

@export var process_mode: Tween.TweenProcessMode = Tween.TweenProcessMode.TWEEN_PROCESS_IDLE

## Transition curve shape (e.g. LINEAR, CUBIC, EXPO, BACK).
@export var trans: Tween.TransitionType = Tween.TRANS_LINEAR

## Ease direction (IN, OUT, IN_OUT, OUT_IN).
@export var ease: Tween.EaseType = Tween.EASE_IN_OUT

## Delay in seconds before the tween starts.
@export_range(0, 60, 0.1, "or_greater") var delay: float = 0.0

## Loop if true, the tween will loop indefinitely.
@export var loop: bool = false

## Loops number of times to loop (0 means infinite). Only used if loop is true.
@export_range(0, 100, 1) var loops: int = 0

@export_group("Constant Speed Mode Only (Overrides Duration)")
# For CONSTANT_SPEED mode
@export_range(0, 1000, 1, "or_greater") var speed: float = 100.0

var tween: Tween

func tween_property(node: Node, property: NodePath, initial_value, target_value, distance: float = 0.0) -> Tween:
	if node == null:
		push_error("TweenResource: Node is null")
		return null
	
	# Clear any existing tween
	if tween != null:
		tween.kill()
		tween = null
	
	# Calculate final duration based on mode
	var final_duration: float
	if duration_mode == DurationMode.CONSTANT_SPEED and distance > 0.0:
		final_duration = distance / speed  # Speed-based timing
	else:
		final_duration = duration  # Fixed duration
	
	# If duration is 0, set immediately
	if final_duration == 0.0:
		node.set(String(property), target_value)
		return null
	
	# Create new tween
	tween = node.create_tween()
	tween.set_process_mode(process_mode)
	tween.set_trans(trans)
	tween.set_ease(ease)
	
	# Configure looping
	if loop:
		if loops > 0:
			tween.set_loops(loops)
		else:
			tween.set_loops()  # Infinite loops
	
	# Set initial value
	node.set(String(property), initial_value)
	
	# Apply tween with delay
	if delay > 0.0:
		tween.tween_property(node, property, target_value, final_duration).set_delay(delay)
	else:
		tween.tween_property(node, property, target_value, final_duration)
	
	return tween

func tween_method(node: Node, method: StringName, initial_value, target_value, distance: float = 0.0) -> Tween:
	if node == null:
		push_error("TweenResource: Node is null")
		return null
	
	# Clear any existing tween
	if tween != null:
		tween.kill()
		tween = null
	
	# Calculate final duration based on mode
	var final_duration: float
	if duration_mode == DurationMode.CONSTANT_SPEED and distance > 0.0:
		final_duration = distance / speed  # Speed-based timing
	else:
		final_duration = duration  # Fixed duration
	
	# If duration is 0, call immediately
	if final_duration == 0.0:
		node.call(method, target_value)
		return null
	
	# Create new tween
	tween = node.create_tween()
	tween.set_trans(trans)
	tween.set_ease(ease)
	
	# Configure looping
	if loop:
		if loops > 0:
			tween.set_loops(loops)
		else:
			tween.set_loops()  # Infinite loops
	
	# Call method with initial value
	node.call(method, initial_value)
	
	# Tween method call
	var callback = Callable(node, method)
	if delay > 0.0:
		tween.tween_method(callback, initial_value, target_value, final_duration).set_delay(delay)
	else:
		tween.tween_method(callback, initial_value, target_value, final_duration)
	
	return tween

# Helper method to get duration for a distance
func get_duration_for_distance(distance: float) -> float:
	if duration_mode == DurationMode.CONSTANT_SPEED and distance > 0.0:
		return distance / speed
	else:
		return duration

# Update static method to include duration mode and speed
static func create(duration_mode: DurationMode = DurationMode.DURATION,
		custom_duration: float = 1.0,
		custom_speed: float = 100.0,
		custom_trans: Tween.TransitionType = Tween.TRANS_CUBIC,
		custom_ease: Tween.EaseType = Tween.EASE_OUT,
		custom_delay: float = 0.0,
		custom_loop: bool = false,
		custom_loops: int = 0) -> TweenResource:
	
	var resource = TweenResource.new()
	resource.duration_mode = duration_mode
	resource.duration = custom_duration
	resource.speed = custom_speed
	resource.trans = custom_trans
	resource.ease = custom_ease
	resource.delay = custom_delay
	resource.loop = custom_loop
	resource.loops = custom_loops
	return resource
