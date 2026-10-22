extends Control
class_name DQChoiceMenu

signal choice_made(choice: String)

var choices: PackedStringArray = [] : set = set_choices, get = get_choices

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
		btn.pressed.connect(_emit_choice_made.bind(c))
		_buttons_container.add_child(btn)
	_focus_first.call_deferred()


func _focus_first() -> void:
	if is_visible_in_tree() and _buttons_container.get_child_count() > 0:
		(_buttons_container.get_child(0) as Control).grab_focus()

func get_choices() -> PackedStringArray:
	return choices


func _emit_choice_made(choice: String) -> void:
	choice_made.emit(choice)
