@tool
extends "res://addons/maaacks_menus_template/base/nodes/menus/options_menu/input/input_options_menu.gd"

## Settings → Controls (D193, B19): дві вкладки над списком maaacks — Keyboard & Mouse і Gamepad.
## Кожна показує всі дії лише зі своїм пристроєм; вікно призначення слухає той самий пристрій;
## Reset повертає типові прив'язки лише відкритої вкладки.

const TABS: Array[String] = ["Keyboard & Mouse", "Gamepad"]

@onready var _cells: Array[Button] = [%KeyboardTab, %GamepadTab]


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	for i in _cells.size():
		_cells[i].custom_minimum_size.x = UITokens.SETTINGS_SEGMENT_MIN_WIDTH
		_cells[i].pressed.connect(show_device.bind(i == 1))
	_mark(false)


## Вкладка пристрою: [param pad] true — Gamepad.
func show_device(pad: bool) -> void:
	%InputActionsList.set_pad(pad)
	$KeyAssignmentWindow.pad = pad
	_mark(pad)


func is_pad() -> bool:
	return %InputActionsList.pad


func _mark(pad: bool) -> void:
	for i in _cells.size():
		var active: bool = (i == 1) == pad
		_cells[i].text = ("✓ " if active else "") + tr(TABS[i])
		_cells[i].theme_type_variation = &"SettingsSegmentOn" if active else &"SettingsSegment"


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and not Engine.is_editor_hint():
		_mark(is_pad())
