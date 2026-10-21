extends RefCounted

## Дії екрана Skills (D330, D331): прийняти позначене й зняти позначку — клавіатура, миша (кнопки на екрані) і
## геймпад (паритет, BACKLOG 24). Реєструються в коді, як CombatInput: project.godot не комітиться.
## Позначити — ui_accept (Enter / A), скасувати все — ui_cancel (Esc / B), слот хотбара — skill_slot_1..4.

static func register() -> void:
	_add(&"skills_accept", [_key(KEY_F), _pad(JOY_BUTTON_Y)])
	_add(&"skills_unpick", [_key(KEY_BACKSPACE), _pad(JOY_BUTTON_X)])


static func _add(action: StringName, events: Array[InputEvent]) -> void:
	assert(not InputMap.has_action(action), "SkillScreenInput: %s вже є в InputMap — перенесено в project.godot? Приберіть звідси." % action)
	InputMap.add_action(action, 0.5)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEvent:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _pad(button: JoyButton) -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
