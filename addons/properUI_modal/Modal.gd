extends Control

signal dismissed

## If true, clicking the dimmer (background) closes the modal.
@export var close_on_outside_click: bool = true
## If true, pressing ESC closes the modal.
@export var close_on_esc: bool = true

@onready var _dimmer: ColorRect = $Dimmer
@onready var _dialog: PanelContainer = $Placement/Dialog
@onready var _content_root: MarginContainer = $Placement/Dialog/ContentRoot

var _focus_trap_active: bool = false
# To manage reduced motion if needed
var _tween: Tween

func _ready() -> void:
	# Hide initially for animation
	modulate.a = 0.0
	_dialog.scale = Vector2(0.9, 0.9)
	_dialog.pivot_offset = _dialog.size / 2.0
	
	# Connect dimmer click
	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	
	# Recalculate pivot when size changes to keep animation centered
	_dialog.resized.connect(func(): _dialog.pivot_offset = _dialog.size / 2.0)

func set_content(node: Node) -> void:
	# Clear existing if any (though usually empty)
	for child in _content_root.get_children():
		child.queue_free()
	
	if node.get_parent():
		node.reparent(_content_root)
	else:
		_content_root.add_child(node)

func animate_in() -> void:
	visible = true
	_kill_tween()
	
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dialog, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# After animation (or immediately), initiate focus trap
	await _tween.finished
	_initiate_focus()

func dismiss() -> void:
	if not is_inside_tree(): return
	
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(_dialog, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await _tween.finished
	emit_signal("dismissed")
	queue_free()

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if close_on_outside_click and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# Handle specific modal actions
	if event.is_action_pressed("ui_cancel") and close_on_esc:
		dismiss()
		get_viewport().set_input_as_handled()
		return

	# Focus Trap Logic
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		_handle_focus_trap(event)

func _initiate_focus() -> void:
	# Try to find a valid focus target inside the content
	var first_focus = _find_first_focusable(_content_root)
	if first_focus:
		first_focus.grab_focus()
	else:
		# Fallback: focus the dialog container itself if it can take focus, or just keep focus here safely?
		# ideally we don't want focus remaining on the underlying window.
		pass

func _handle_focus_trap(event: InputEvent) -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	
	# If focus is somehow outside the modal, force it back in
	if not is_ancestor_of(focus_owner):
		_initiate_focus()
		get_viewport().set_input_as_handled()
		return

	# If we are safely inside, we need to check if we are tabbing OUT of the boundaries
	# This is "simple" cyclic trap: 
	# If next -> and current is Last -> go to First
	# If prev -> and current is First -> go to Last
	
	# NOTE: Godot's built-in focus system usually handles "next" logic well, but "wrapping" 
	# usually requires explicit Neighbor setup or manual handling. 
	# Finding "First" and "Last" recursively is expensive every frame, 
	# but for a modal it's usually acceptable or we can cache it.
	
	# However, Godot's default behavior is to lose focus or go to a neighbor. 
	# To make this robust without modifying every child node's neighbor properties:
	# We can check specific boundary conditions.
	
	# Let's try a simpler approach: 
	# Let Godot handle the focus change. 
	# If the NEW focus owner is NOT inside us, we pull it back.
	# But `_input` happens *before* gui navigation usually if we consume it? 
	# No, `ui_focus_next` is treated by the viewport.
	
	# Actually, the best way to trap focus in Godot 4 without modifying neighbors
	# is to check if the proposed next focus is valid.
	# But `Control` nodes don't easily expose "who is next".
	
	# Fallback strategy:
	# We let the event propagate. 
	# We use `_process` or a timer to check if focus slipped out? No, that's hacky.
	
	# Better Strategy:
	# Find all focusable nodes in order.
	# If current is last and pressing Tab, grab first.
	# If current is first and pressing Shift+Tab, grab last.
	
	var all_focusable = []
	_collect_focusable(_content_root, all_focusable)
	
	if all_focusable.is_empty():
		return # Nothing to focus
		
	var current = get_viewport().gui_get_focus_owner()
	var index = all_focusable.find(current)
	
	if index == -1:
		# Focus is not on a known element, reset to first
		all_focusable[0].grab_focus()
		get_viewport().set_input_as_handled()
		return
		
	if event.is_action_pressed("ui_focus_next"):
		if index == all_focusable.size() - 1:
			# Wrap to start
			all_focusable[0].grab_focus()
			get_viewport().set_input_as_handled()
			
	elif event.is_action_pressed("ui_focus_prev"):
		if index == 0:
			# Wrap to end
			all_focusable.back().grab_focus()
			get_viewport().set_input_as_handled()

func _collect_focusable(root: Node, list: Array) -> void:
	if not root.visible: return
	
	if root is Control and root.focus_mode != Control.FOCUS_NONE and root.is_visible_in_tree():
		list.append(root)
	
	for child in root.get_children():
		_collect_focusable(child, list)

func _find_first_focusable(root: Node) -> Control:
	if not root.visible: return null
	if root is Control and root.focus_mode != Control.FOCUS_NONE and root.is_visible_in_tree():
		return root
	for child in root.get_children():
		var found = _find_first_focusable(child)
		if found: return found
	return null
