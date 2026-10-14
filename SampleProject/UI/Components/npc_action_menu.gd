extends VBoxContainer
class_name NpcActionMenu

## Меню дій NPC. Figma: npc-interaction-menu у npc-menu-merchant 164:1302 /
## npc-menu-blacksmith 176:1357; рядки — UI/Menu Item 248:62 (активний: SemiBold + шеврон).
## Працює й під паузою; ui_cancel закриває. Лише клавіатура/геймпад (D155): вгору/вниз — пункти,
## interact (E / геймпад A) — вибір; WASD, стіки та вліво/вправо — рух гравця, фокус лишається в меню;
## миша ігнорується.

signal chosen(id: StringName)
signal cancelled

const THEME_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"
const POINTER := preload("res://SampleProject/Assets/UI/Icons/chevron.svg")
const WORLD_UI := preload("res://SampleProject/UI/Components/world_ui.gd")


func _ready() -> void:
	if theme == null:
		theme = load(THEME_PATH)
	theme_type_variation = &"NpcMenuList"
	custom_minimum_size.x = UITokens.NPC_MENU_WIDTH
	process_mode = Node.PROCESS_MODE_ALWAYS


## [param entries] — масив {id, label}. Показуються лише передані пункти.
func setup(entries: Array) -> void:
	for child in get_children():
		# remove_child одразу: інакше open() віддасть фокус старій кнопці, що ось-ось зникне.
		remove_child(child)
		child.queue_free()
	for entry in entries:
		var b := Button.new()
		b.name = String(entry.id)
		b.text = entry.label
		b.icon = POINTER
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.theme_type_variation = &"NpcMenuItem"
		b.focus_neighbor_left = ^"."
		b.focus_neighbor_right = ^"."
		b.focus_entered.connect(func(): b.theme_type_variation = &"NpcMenuItemOn")
		b.focus_exited.connect(func(): b.theme_type_variation = &"NpcMenuItem")
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): chosen.emit(entry.id))
		add_child(b)


func open() -> void:
	scale = WORLD_UI.screen_scale(self)  # екранний розмір під збільшеною камерою (D170)
	visible = true
	for child in get_children():
		if child is Button:
			child.grab_focus.call_deferred()
			return


## Стік у Godot теж веде ui_up/ui_down; тут він лише для руху героя (D155).
## Input-опитування (PlayerMover) бачить подію й після set_input_as_handled.
func _input(event: InputEvent) -> void:
	if visible and event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
	elif event.is_action_pressed(&"interact"):
		# ui_accept не має кнопки геймпада; вибираємо тією ж дією, що відкрила меню.
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and focused.get_parent() == self:
			get_viewport().set_input_as_handled()
			(focused as Button).pressed.emit()
