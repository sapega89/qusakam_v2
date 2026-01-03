extends Node2D
class_name Interactable

@export var activator : Activator : set = _set_activator
@export var start_active: bool = false

var is_active: bool = false

func _ready() -> void:
	_setup_connections()
	await get_tree().process_frame
	if start_active:
		_activated()

func _set_activator(value): # Setter
	activator = value
	_setup_connections()

func _setup_connections():
	if activator:
		activator.activated.connect(_on_activated)
		activator.deactivated.connect(_on_deactivated)

func _on_activated():
	_activated()

func _on_deactivated():
	_deactivated()

# Override this method for custom activation behavior
func _activated():
	is_active = true


# Override this method for custom deactivation behavior
func _deactivated():
	is_active = false
