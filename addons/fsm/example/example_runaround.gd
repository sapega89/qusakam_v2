class_name ExampleRunaround
extends FSMState

@export var move_speed = 600
@export var grav = 600
@export var jump_speed = 500

signal enter_noclip

func _enter_state(): print("We entered the runaround state!")

func _physics_process(delta: float) -> void:
	var v = actor.velocity
	var grounded = actor.is_on_floor()
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if not grounded: v.y += grav * delta

	if Input.is_action_just_pressed("ui_accept") and grounded: v.y = -jump_speed 
	if Input.is_action_just_pressed("ui_accept") and not grounded: enter_noclip.emit()
		
	if v.y < 0 and Input.is_action_just_released("ui_accept"): v.y *= 0.5

	if direction: v.x = direction * move_speed
	else: v.x = move_toward(v.x, 0, move_speed)
	
	actor.velocity = v
	actor.move_and_slide()

func _exit_state(): 
	print("Goodbye, leaving runaround state.")
