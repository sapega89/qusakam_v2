extends RefCounted

## Дії бою souls-lite (D270): важкий удар і блок / парирування — клавіатура, миша й геймпад (паритет, BACKLOG 24).
## Реєструються в коді під час старту, бо project.godot несе локальні правки Sapega й не комітиться;
## коли його закомітять — перенести ці дії туди й видалити цей файл.
## Подвійний ривок — та сама дія dodge, діставання зброї — автоматичне.
## Слоти навичок 1–4 (D271): клавіші 1–4 у project.godot, геймпад — тут: RT, R3, L3, Back (вільні кнопки).
## Пропуск кат-сцени (D308): утримання Tab / геймпад Y (Y — ще й interact, але в кат-сцені взаємодії немає).
## Попередня зброя (BACKLOG 28, D-28i): у project.godot лише D-pad ←, клавіатура — Z (наступна — Q).

static func register() -> void:
	_add(&"heavy_attack", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_R), _pad(JOY_BUTTON_B)])
	_add(&"block", [_key(KEY_CTRL), _mouse(MOUSE_BUTTON_MIDDLE), _pad(JOY_BUTTON_LEFT_SHOULDER)])
	_add(&"cutscene_skip", [_key(KEY_TAB), _pad(JOY_BUTTON_Y)])
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	var pads: Array[InputEvent] = [trigger, _pad(JOY_BUTTON_RIGHT_STICK), _pad(JOY_BUTTON_LEFT_STICK), _pad(JOY_BUTTON_BACK)]
	for i in pads.size():
		_add_pad(StringName("skill_slot_%d" % (i + 1)), pads[i])
	_add_key(&"weapon_prev", _key(KEY_Z))


static func _add(action: StringName, events: Array[InputEvent]) -> void:
	assert(not InputMap.has_action(action), "CombatInput: %s вже є в InputMap — перенесено в project.godot? Приберіть звідси." % action)
	InputMap.add_action(action, 0.5)
	for event in events:
		InputMap.action_add_event(action, event)


## Дія вже є в project.godot (клавіші) — додати геймпад, якщо його там ще немає.
static func _add_pad(action: StringName, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		assert(not (existing is InputEventJoypadButton or existing is InputEventJoypadMotion), "CombatInput: %s вже має геймпад у project.godot — приберіть звідси." % action)
	InputMap.action_add_event(action, event)


## Дія вже є в project.godot (геймпад) — додати клавішу, якщо клавіатури там ще немає.
static func _add_key(action: StringName, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		assert(not (existing is InputEventKey or existing is InputEventMouseButton), "CombatInput: %s вже має клавішу в project.godot — приберіть звідси." % action)
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
