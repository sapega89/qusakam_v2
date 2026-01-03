extends Node

# Signal emitted when the modal stack becomes empty (all dialogs closed)
signal stack_empty
# Signal emitted when a new modal is shown
signal modal_shown(modal_node)

var _layer: CanvasLayer
var _stack: Array[Control] = []
var _focus_history: Array[WeakRef] = []

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 101 # Above toasts (usually 100)
	# Ensure the layer doesn't steal input when empty
	_layer.visible = false
	add_child(_layer)

## Opens a modal with the given content.
## [param content] can be a PackedScene (instantiated automatically) or a Control node.
## [param options] dictionary for future extensibility (e.g. distinct animation configs).
func show_modal(content, options: Dictionary = {}) -> Control:
	var modal_scene = preload("res://addons/properUI_modal/Modal.tscn")
	var modal_instance: Control = modal_scene.instantiate()
	
	_layer.add_child(modal_instance)
	
	# If content is a scene, instantiate it. If node, reparent it.
	var content_node: Control
	if content is PackedScene:
		content_node = content.instantiate()
	elif content is Control:
		content_node = content
	else:
		push_error("ModalManager: content must be PackedScene or Control.")
		modal_instance.queue_free()
		return null
		
	# Pass content to the modal wrapper
	if modal_instance.has_method("set_content"):
		modal_instance.set_content(content_node)
	
	# Connect to dismiss signal to handle cleanup
	modal_instance.dismissed.connect(_on_modal_dismissed.bind(modal_instance))
	
	# Save current focus before showing (for restoration later)
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus:
		_focus_history.push_back(weakref(current_focus))
	else:
		_focus_history.push_back(weakref(null))

	# If there was a previous modal, make it non-interactive or visually dim?
	# For strict strict modality, usually only the top one is interactive.
	if not _stack.is_empty():
		var prev = _stack.back()
		if is_instance_valid(prev):
			# We could pause processing or just rely on the new modal's overlay to block clicks.
			# But to be safe from tab-navigation leaking, we should ideally disable focus on the one below.
			# However, the new modal is full screen and usually traps focus, so the one below is effectively unreachable.
			pass

	_stack.append(modal_instance)
	_layer.visible = true
	
	emit_signal("modal_shown", modal_instance)
	
	# Trigger opening animation
	if modal_instance.has_method("animate_in"):
		modal_instance.animate_in()
		
	return modal_instance

func dismiss_top() -> void:
	if _stack.is_empty():
		return
	var top = _stack.back()
	if is_instance_valid(top) and top.has_method("dismiss"):
		top.dismiss()

func _on_modal_dismissed(modal_instance: Control) -> void:
	if _stack.has(modal_instance):
		_stack.erase(modal_instance)
	
	# Restore focus
	var saved_focus_ref = _focus_history.pop_back()
	if saved_focus_ref:
		var saved_focus = saved_focus_ref.get_ref()
		if is_instance_valid(saved_focus) and saved_focus.is_inside_tree():
			saved_focus.grab_focus()
	
	if _stack.is_empty():
		_layer.visible = false
		emit_signal("stack_empty")
	else:
		# If there's another modal below, ensure it regains "active" status if needed
		# In this simple implementation, the focus simply returns to the element that sparked the *now closed* modal.
		# If that element was inside the *previous* modal, then focus naturally goes there.
		pass
