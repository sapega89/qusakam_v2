# Тестовий скрипт для перевірки всіх кнопок Xbox контролера
extends Node

@onready var label = $Label
var connected_controllers: Array = []

func _ready():
	print("🎮 Controller Test: Запущено")
	# Створюємо Label для відображення інформації
	if not has_node("Label"):
		var new_label = Label.new()
		new_label.name = "Label"
		new_label.position = Vector2(10, 10)
		new_label.size = Vector2(800, 600)
		add_child(new_label)
		label = new_label
	
	# Перевіряємо підключені контролери
	_update_controller_info()

func _process(_delta):
	_update_controller_info()
	_check_inputs()

func _update_controller_info():
	var joypads = Input.get_connected_joypads()
	if joypads.size() != connected_controllers.size():
		connected_controllers = joypads
		print("🎮 Підключені контролери: ", joypads.size())
		for i in range(joypads.size()):
			var device_id = joypads[i]
			var device_name = Input.get_joy_name(device_id)
			print("  Контролер ", i, ": ", device_name, " (ID: ", device_id, ")")

func _check_inputs():
	var text = "=== ТЕСТ XBOX КОНТРОЛЕРА ===\n\n"
	
	# Інформація про підключені контролери
	var joypads = Input.get_connected_joypads()
	if joypads.size() == 0:
		text += "❌ Контролер НЕ підключено!\n"
		text += "Підключіть Xbox контролер та перезапустіть сцену.\n\n"
	else:
		text += "✅ Підключено контролерів: " + str(joypads.size()) + "\n"
		for i in range(joypads.size()):
			var device_id = joypads[i]
			var device_name = Input.get_joy_name(device_id)
			text += "  Контролер " + str(i) + ": " + device_name + " (ID: " + str(device_id) + ")\n"
		text += "\n"
	
	# Перевірка кнопок Xbox контролера
	text += "=== КНОПКИ ===\n"
	var button_names = {
		JOY_BUTTON_A: "A (Стрибок)",
		JOY_BUTTON_B: "B",
		JOY_BUTTON_X: "X (Атака)",
		JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB (Left Shoulder)",
		JOY_BUTTON_RIGHT_SHOULDER: "RB (Right Shoulder)",
		JOY_BUTTON_LEFT_STICK: "Left Stick Press",
		JOY_BUTTON_RIGHT_STICK: "Right Stick Press",
		JOY_BUTTON_START: "Start (Menu)",
		JOY_BUTTON_BACK: "Back (View)",
		JOY_BUTTON_GUIDE: "Guide (Home)",
		JOY_BUTTON_DPAD_UP: "D-Pad Up",
		JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
		JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
		JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
	}
	
	for button_id in button_names:
		var pressed = Input.is_joy_button_pressed(0, button_id) if joypads.size() > 0 else false
		var status = "✅" if pressed else "⚪"
		text += status + " " + button_names[button_id] + "\n"
	
	# Перевірка джойстиків
	text += "\n=== ДЖОЙСТИКИ ===\n"
	var axis_names = {
		JOY_AXIS_LEFT_X: "Left Stick X (Вліво/Вправо)",
		JOY_AXIS_LEFT_Y: "Left Stick Y (Вгору/Вниз)",
		JOY_AXIS_RIGHT_X: "Right Stick X",
		JOY_AXIS_RIGHT_Y: "Right Stick Y",
		JOY_AXIS_TRIGGER_LEFT: "Left Trigger (LT)",
		JOY_AXIS_TRIGGER_RIGHT: "Right Trigger (RT)",
	}
	
	for axis_id in axis_names:
		var value = Input.get_joy_axis(0, axis_id) if joypads.size() > 0 else 0.0
		var status = "⚪"
		if abs(value) > 0.1:
			status = "✅"
		text += status + " " + axis_names[axis_id] + ": " + ("%.2f" % value) + "\n"
	
	# Перевірка дій гри
	text += "\n=== ДІЇ ГРИ ===\n"
	var action_names = {
		"move_left": "Рух вліво",
		"move_right": "Рух вправо",
		"move_up": "Рух вгору",
		"move_down": "Рух вниз",
		"jump": "Стрибок",
		"attack": "Атака",
	}
	
	for action in action_names:
		var pressed = Input.is_action_pressed(action)
		var just_pressed = Input.is_action_just_pressed(action)
		var status = "⚪"
		if just_pressed:
			status = "🟢 JUST PRESSED"
		elif pressed:
			status = "✅ PRESSED"
		text += status + " " + action_names[action] + " (" + action + ")\n"
	
	# Оновлюємо текст
	if label:
		label.text = text

func _input(event):
	# Виводимо інформацію про всі події вводу
	if event is InputEventJoypadButton:
		var button_name = ""
		match event.button_index:
			JOY_BUTTON_A: button_name = "A"
			JOY_BUTTON_B: button_name = "B"
			JOY_BUTTON_X: button_name = "X"
			JOY_BUTTON_Y: button_name = "Y"
			JOY_BUTTON_LEFT_SHOULDER: button_name = "LB"
			JOY_BUTTON_RIGHT_SHOULDER: button_name = "RB"
			JOY_BUTTON_LEFT_STICK: button_name = "Left Stick"
			JOY_BUTTON_RIGHT_STICK: button_name = "Right Stick"
			JOY_BUTTON_START: button_name = "Start"
			JOY_BUTTON_BACK: button_name = "Back"
			JOY_BUTTON_GUIDE: button_name = "Guide"
			JOY_BUTTON_DPAD_UP: button_name = "D-Pad Up"
			JOY_BUTTON_DPAD_DOWN: button_name = "D-Pad Down"
			JOY_BUTTON_DPAD_LEFT: button_name = "D-Pad Left"
			JOY_BUTTON_DPAD_RIGHT: button_name = "D-Pad Right"
			_: button_name = "Button " + str(event.button_index)
		
		if event.pressed:
			print("🎮 Кнопка натиснута: ", button_name, " (ID: ", event.button_index, ")")
		else:
			print("🎮 Кнопка відпущена: ", button_name, " (ID: ", event.button_index, ")")
	
	elif event is InputEventJoypadMotion:
		var axis_name = ""
		match event.axis:
			JOY_AXIS_LEFT_X: axis_name = "Left Stick X"
			JOY_AXIS_LEFT_Y: axis_name = "Left Stick Y"
			JOY_AXIS_RIGHT_X: axis_name = "Right Stick X"
			JOY_AXIS_RIGHT_Y: axis_name = "Right Stick Y"
			JOY_AXIS_TRIGGER_LEFT: axis_name = "Left Trigger"
			JOY_AXIS_TRIGGER_RIGHT: axis_name = "Right Trigger"
			_: axis_name = "Axis " + str(event.axis)
		
		if abs(event.axis_value) > 0.1:
			print("🎮 Джойстик: ", axis_name, " = ", ("%.2f" % event.axis_value))
