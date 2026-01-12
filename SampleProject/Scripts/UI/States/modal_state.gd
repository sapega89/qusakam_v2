extends "res://SampleProject/Scripts/UI/States/ui_state.gd"
class_name ModalState

var modal_layer: Node = null
var modal_active: bool = false

func _enter_state() -> void:
	modal_layer = _get_modal_layer()
	if modal_layer and modal_layer.has_method("show_modal"):
		modal_layer.show_modal(enter_payload)
		if modal_layer.has_signal("modal_closed"):
			modal_layer.modal_closed.connect(_on_modal_closed, CONNECT_ONE_SHOT)
		modal_active = true

func _exit_state() -> void:
	modal_active = false

func _physics_process(_delta: float) -> void:
	pass

func _on_modal_closed(_result: String) -> void:
	finish({"result": _result})

func _get_modal_layer() -> Node:
	if ui_manager and ui_manager.has_method("get_modal_layer"):
		return ui_manager.get_modal_layer()
	return null
