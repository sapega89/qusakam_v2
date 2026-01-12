extends "res://addons/fsm/FSMState.gd"
class_name UIState

signal finished(payload: Dictionary)

var ui_manager: Node = null
var enter_payload: Dictionary = {}
var return_state: String = ""
var return_payload: Dictionary = {}

func setup(manager: Node, payload: Dictionary = {}, return_state_name: String = "", return_payload_data: Dictionary = {}) -> void:
	ui_manager = manager
	enter_payload = payload
	return_state = return_state_name
	return_payload = return_payload_data

func finish(payload: Dictionary = {}) -> void:
	finished.emit(payload)

func _enter_state() -> void:
	pass

func _exit_state() -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass
