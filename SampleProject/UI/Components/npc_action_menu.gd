extends VBoxContainer
class_name NpcActionMenu

## Меню дій NPC. Figma: npc-interaction-menu у npc-menu-merchant 164:1302 /
## npc-menu-blacksmith 176:1357; рядки — UI/Menu Item 248:62 (активний: SemiBold + шеврон).
## Працює під паузою; ui_cancel закриває.

signal chosen(id: StringName)
signal cancelled

const THEME_PATH := "res://SampleProject/UI/Themes/GameUITheme.tres"
const POINTER := preload("res://SampleProject/Assets/UI/Icons/chevron.svg")


func _ready() -> void:
	if theme == null:
		theme = load(THEME_PATH)
	theme_type_variation = &"NpcMenuList"
	custom_minimum_size.x = UITokens.NPC_MENU_WIDTH
	process_mode = Node.PROCESS_MODE_ALWAYS


## [param entries] — масив {id, label}. Показуються лише передані пункти.
func setup(entries: Array) -> void:
	for child in get_children():
		child.queue_free()
	for entry in entries:
		var b := Button.new()
		b.name = String(entry.id)
		b.text = entry.label
		b.icon = POINTER
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.theme_type_variation = &"NpcMenuItem"
		b.focus_entered.connect(func(): b.theme_type_variation = &"NpcMenuItemOn")
		b.focus_exited.connect(func(): b.theme_type_variation = &"NpcMenuItem")
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(func(): chosen.emit(entry.id))
		add_child(b)


func open() -> void:
	visible = true
	for child in get_children():
		if child is Button:
			child.grab_focus.call_deferred()
			return


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
