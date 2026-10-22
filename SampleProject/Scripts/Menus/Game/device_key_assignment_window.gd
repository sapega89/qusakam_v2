@tool
extends "res://addons/maaacks_menus_template/base/nodes/menus/options_menu/input/key_assignment_window.gd"

## Вікно «Assign Key» для Settings → Controls (D193): слухає лише пристрій відкритої вкладки.
## Keyboard & Mouse бере клавіші й кнопки миші, Gamepad — кнопки й осі геймпада.

const DeviceList = preload("res://SampleProject/Scripts/Menus/Game/device_actions_list.gd")

## true — вкладка Gamepad.
var pad: bool = false


func _is_recordable_input(event: InputEvent) -> bool:
	return super(event) and DeviceList.is_pad_event(event) == pad
