extends Node2D
class_name Activator

signal activated
signal deactivated

var is_active := false

func toggle():
	if is_active:
		deactivate()
	else:
		activate()

func activate():
	if !is_active:
		is_active = true
		activated.emit()

func deactivate():
	if is_active:
		is_active = false
		deactivated.emit()
