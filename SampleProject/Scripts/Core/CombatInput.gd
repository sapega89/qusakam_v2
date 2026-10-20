extends RefCounted

## Дії бою souls-lite (D270): важкий удар і блок / парирування — клавіатура, миша й геймпад (паритет, BACKLOG 24).
## Реєструються в коді під час старту, бо project.godot несе локальні правки Sapega й не комітиться;
## коли його закомітять — перенести ці дії туди й видалити цей файл.
## Подвійний ривок — та сама дія dodge, діставання зброї — автоматичне.

static func register() -> void:
	_add(&"heavy_attack", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_R), _pad(JOY_BUTTON_B)])
	_add(&"block", [_key(KEY_CTRL), _mouse(MOUSE_BUTTON_MIDDLE), _pad(JOY_BUTTON_LEFT_SHOULDER)])


static func _add(action: StringName, events: Array[InputEvent]) -> void:
	assert(not InputMap.has_action(action), "CombatInput: %s вже є в InputMap — перенесено в project.godot? Приберіть звідси." % action)
	InputMap.add_action(action, 0.5)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEvent:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _mouse(button: MouseButton) -> InputEvent:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


static func _pad(button: JoyButton) -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
