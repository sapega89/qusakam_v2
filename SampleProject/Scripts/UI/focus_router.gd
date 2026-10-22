extends Node
class_name FocusRouter

@export var tabs_container_path: NodePath = NodePath("PanelManager/HBoxContainer/TabButtons")
@export var panels_container_path: NodePath = NodePath("PanelManager/HBoxContainer")

var last_focused_by_tab: Dictionary = {}
var active_tab_name: String = ""
var focus_mode: String = "Tabs"
## Останній ввід — клік миші: фокус, що прийшов кліком, не переводить роутер у вміст (Esc після кліку закриває меню, як раніше).
var _last_input_mouse: bool = false

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
	# D-pad / стрілки заходять у вміст і геометрією GUI, повз focus_content() (BACKLOG 24) — стежимо за самим фокусом.
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_last_input_mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_input_mouse = false


func _on_gui_focus_changed(node: Control) -> void:
	var panels := _menu_node(panels_container_path)
	if panels and panels.is_ancestor_of(node) and not _last_input_mouse:
		focus_mode = "Content"
	elif node.get_parent() == _menu_node(tabs_container_path):
		focus_mode = "Tabs"

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
	# Фокус — на активну вкладку, інакше вона й перша світяться разом (B7).
	var first_button: Button = null
	for child in tabs_container.get_children():
		if child is Button:
			# Закрита сюжетом вкладка (GameMenu._lock_tabs) фокус не бере.
			child.focus_mode = Control.FOCUS_NONE if child.disabled else Control.FOCUS_ALL
			if child.disabled:
				continue
			if first_button == null or child.button_pressed:
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
	# Рядки списку перебудовуються (інвентар після «Use») — запам'ятований міг уже вийти з дерева.
	if target and is_instance_valid(target) and target.is_inside_tree():
		target.grab_focus()
		return
	var focusable = _find_first_focusable(panels_container)
	if focusable:
		focusable.grab_focus()
	else:
		focus_mode = "Tabs"  # вкладка лише показує (Status) — фокус лишається на вкладці, а не губиться

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
	# Клавіша або кнопка геймпада (BACKLOG 24): B у вмісті повертає до вкладок, як Esc, а не закриває меню.
	# Стік сюди не йде — його нахил повторюється й перескакував би вкладки.
	if not ((event is InputEventKey or event is InputEventJoypadButton) and event.pressed):
		return
	if focus_mode == "Content":
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_cancel"):
			focus_tabs()
			get_viewport().set_input_as_handled()
		return
	# A / Enter на іншій вкладці — її кнопка натиснеться на відпусканні й перемкне вкладку; у вміст — лише з активної.
	var owner: Control = get_viewport().gui_get_focus_owner()
	var other_tab: bool = owner is Button and owner.get_parent() == _menu_node(tabs_container_path) and not owner.button_pressed
	if event.is_action_pressed("ui_right") or (event.is_action_pressed("ui_accept") and not other_tab):
		focus_content()
		get_viewport().set_input_as_handled()

func _find_first_focusable(node: Node) -> Control:
	if node is CanvasItem and not node.visible:
		return null  # сховані панелі інших вкладок: фокус на невидимому вузлі губиться (BACKLOG 24)
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		return node
	for child in node.get_children():
		var result = _find_first_focusable(child)
		if result:
			return result
	return null
