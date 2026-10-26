extends Control
class_name DQChoiceMenu

signal choice_made(choice: String)

## Kusakam, D735: W/S теж гортають відповіді, як стрілки й хрестовина (стік лишається штатній навігації Godot).
const MenuNavKeys := preload("res://SampleProject/UI/Components/menu_nav_keys.gd")

var choices: PackedStringArray = [] : set = set_choices, get = get_choices
## Kusakam, D474: варіація теми для кнопок відповідей (DialogueSystem.tscn ставить DialogueChoice).
@export var button_type_variation: StringName = &""

@onready
var _buttons_container: Container = %ButtonsContainer

func _ready() -> void:
	hide()
	# Kusakam, BACKLOG 24: вибір відповіді геймпадом / клавіатурою — фокус на першу відповідь, щойно меню видно.
	visibility_changed.connect(_focus_first)

func set_choices(value: PackedStringArray) -> void:
	choices = value
	if not _buttons_container:
		await ready
	
	for n in _buttons_container.get_children():
		_buttons_container.remove_child(n)
		n.queue_free()
	for c in choices:
		var btn = Button.new()
		btn.name = c
		btn.text = c
		btn.theme_type_variation = button_type_variation
		btn.pressed.connect(_emit_choice_made.bind(c))
		_buttons_container.add_child(btn)
	_focus_first.call_deferred()


func _focus_first() -> void:
	if is_visible_in_tree() and _buttons_container.get_child_count() > 0:
		(_buttons_container.get_child(0) as Control).grab_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var by := MenuNavKeys.step(event)
	if by != 0:
		get_viewport().set_input_as_handled()
		MenuNavKeys.move_focus(_buttons_container, by)

func get_choices() -> PackedStringArray:
	return choices


func _emit_choice_made(choice: String) -> void:
	choice_made.emit(choice)
