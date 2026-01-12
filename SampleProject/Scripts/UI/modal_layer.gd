extends CanvasLayer
class_name ModalLayer

signal modal_closed(result: String)

@export var modal_scene: PackedScene

var active_modal: Control = null

@onready var blocker: Control = $Blocker
@onready var container: Control = $Container

func _ready() -> void:
	visible = false
	if blocker:
		blocker.visible = false
		blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if container:
		container.visible = false

func show_modal(data: Dictionary) -> void:
	_clear_modal()

	if not modal_scene:
		push_error("ModalLayer: modal_scene not assigned")
		return

	active_modal = modal_scene.instantiate() as Control
	if not active_modal:
		push_error("ModalLayer: Failed to instantiate modal dialog")
		return

	container.add_child(active_modal)
	active_modal.setup(data)

	if not active_modal.confirmed.is_connected(_on_confirmed):
		active_modal.confirmed.connect(_on_confirmed)
	if not active_modal.cancelled.is_connected(_on_cancelled):
		active_modal.cancelled.connect(_on_cancelled)
	if active_modal.has_signal("chosen") and not active_modal.chosen.is_connected(_on_chosen):
		active_modal.chosen.connect(_on_chosen)

	visible = true
	blocker.visible = true
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	container.visible = true

func show_custom_modal(packed_scene: PackedScene) -> void:
	_clear_modal()
	if not packed_scene:
		push_error("ModalLayer: modal scene not assigned")
		return
	active_modal = packed_scene.instantiate() as Control
	if not active_modal:
		push_error("ModalLayer: Failed to instantiate modal scene")
		return
	container.add_child(active_modal)
	blocker.visible = true
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	container.visible = true

func _on_confirmed() -> void:
	_close_with_result("confirm")

func _on_cancelled() -> void:
	_close_with_result("cancel")

func _on_chosen(result: String) -> void:
	_close_with_result(result)

func _close_with_result(result: String) -> void:
	_clear_modal()
	modal_closed.emit(result)

func _clear_modal() -> void:
	if active_modal and is_instance_valid(active_modal):
		active_modal.queue_free()
	active_modal = null
	if blocker:
		blocker.visible = false
		blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if container:
		container.visible = false
	visible = false
