extends Node
class_name FocusRouter

@export var tabs_container_path: NodePath = NodePath("PanelManager/HBoxContainer/TabButtons")
@export var panels_container_path: NodePath = NodePath("PanelManager/HBoxContainer")

var last_focused_by_tab: Dictionary = {}
var active_tab_name: String = ""
var focus_mode: String = "Tabs"

## Шляхи в експортах задані від кореня меню, а роутер — його дитина,
## тому резолвимо від батька, інакше всі пошуки повертали null.
func _menu_node(path: NodePath) -> Node:
	var menu := get_parent()
	if menu == null:
		return null
	return menu.get_node_or_null(path)


func _ready() -> void:
	_cache_tabs()
	_cache_focusables()
	set_process_unhandled_input(true)

func _cache_tabs() -> void:
	var tabs_container = _menu_node(tabs_container_path)
	if not tabs_container:
		return
	for child in tabs_container.get_children():
		if child is Button:
			if not child.pressed.is_connected(_on_tab_pressed):
				child.pressed.connect(_on_tab_pressed.bind(child.name))

func _on_tab_pressed(tab_name: String) -> void:
	set_active_tab(tab_name)
	focus_tabs()

func set_active_tab(tab_name: String) -> void:
	active_tab_name = tab_name

func focus_tabs() -> void:
	focus_mode = "Tabs"
	var tabs_container = _menu_node(tabs_container_path)
	if not tabs_container:
		return
	# Тільки кнопки: у контейнері є ще спейсери, на них фокус ставити не можна.
	var first_button: Button = null
	for child in tabs_container.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_ALL
			if first_button == null:
				first_button = child
	if first_button == null:
		return
	# grab_focus() на невидимому вузлі нічого не робить — чекаємо, поки меню покажуть.
	while not first_button.is_visible_in_tree():
		await first_button.visibility_changed
		if not is_instance_valid(first_button):
			return
	first_button.grab_focus()

func focus_content() -> void:
	focus_mode = "Content"
	var panels_container = _menu_node(panels_container_path)
	if not panels_container:
		return
	var target = last_focused_by_tab.get(active_tab_name, null)
	if target and is_instance_valid(target):
		target.grab_focus()
		return
	var focusable = _find_first_focusable(panels_container)
	if focusable:
		focusable.grab_focus()

func remember_focus(tab_name: String, node: Control) -> void:
	if node and is_instance_valid(node):
		last_focused_by_tab[tab_name] = node

func _cache_focusables() -> void:
	var panels_container = _menu_node(panels_container_path)
	if not panels_container:
		return
	_connect_focusables(panels_container)

func _connect_focusables(node: Node) -> void:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		if not node.has_meta("_focus_router_connected"):
			node.focus_entered.connect(_on_focus_entered.bind(node))
			node.set_meta("_focus_router_connected", true)
	for child in node.get_children():
		_connect_focusables(child)

func _on_focus_entered(node: Control) -> void:
	if active_tab_name.is_empty():
		return
	remember_focus(active_tab_name, node)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if focus_mode == "Tabs":
			if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
				focus_content()
				get_viewport().set_input_as_handled()
		elif focus_mode == "Content":
			if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_cancel"):
				focus_tabs()
				get_viewport().set_input_as_handled()

func _find_first_focusable(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		return node
	for child in node.get_children():
		var result = _find_first_focusable(child)
		if result:
			return result
	return null
