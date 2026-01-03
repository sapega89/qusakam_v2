@abstract
class_name FSMState extends Node

var actor : Node

@abstract func _enter_state() -> void
@abstract func _exit_state() -> void
@abstract func _physics_process(delta: float) -> void
