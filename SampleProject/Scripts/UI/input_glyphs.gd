extends RefCounted

## Назви кнопок для підказок (BACKLOG 12 + 24, D289): клавіатура / миша або геймпад —
## за останнім пристроєм вводу. Беруться з InputMap, тож переназначена клавіша теж правильна.
##   const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
##   InputGlyphs.resolve("Press {jump} to jump")  →  "Press Space / W to jump" або "Press A to jump"
## Хто бачить ввід, повідомляє: InputGlyphs.note_event(event) (підказка в грі, вікно туторіалу, InteractionPrompt).

const PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const PAD_AXES := {
	JOY_AXIS_LEFT_X: "Left stick", JOY_AXIS_LEFT_Y: "Left stick",
	JOY_AXIS_RIGHT_X: "Right stick", JOY_AXIS_RIGHT_Y: "Right stick",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}
const MOUSE_BUTTONS := {
	MOUSE_BUTTON_LEFT: "Left Mouse", MOUSE_BUTTON_RIGHT: "Right Mouse", MOUSE_BUTTON_MIDDLE: "Middle Mouse",
}

static var using_gamepad := false
## Геймпад, з якого прийшов останній ввід — його вібрація (VFXHooks.rumble).
static var pad_device := 0


## Останній пристрій: кнопка / стік геймпада → геймпад; клавіша / клік → клавіатура.
## Повертає true, якщо пристрій змінився.
static func note_event(event: InputEvent) -> bool:
	var pad := using_gamepad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		pad_device = event.device
	var changed := pad != using_gamepad
	using_gamepad = pad
	return changed


## Кнопка дії на поточному пристрої: "Space / W", "Left click", "A", "Left stick".
static func label(action: StringName) -> String:
	return " / ".join(_names(action).slice(0, 2))


static func _names(action: StringName) -> Array[String]:
	var names := names_for(action, using_gamepad)
	assert(not names.is_empty(), "InputGlyphs: %s has no %s binding" % [action, "gamepad" if using_gamepad else "keyboard"])
	return names


## Усі назви кнопок дії на пристрої [param pad] (геймпад / клавіатура з мишею), незалежно від останнього вводу —
## сторінка Controls показує обидва стовпці (D-28f). Порожньо — дії на цьому пристрої немає.
static func names_for(action: StringName, pad: bool) -> Array[String]:
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		var name := _event_name(event, pad)
		if name != "" and not name in names:
			names.append(name)
	return names


## Підставляє {дія} у тексті; {move} — рух уліво-вправо однією назвою.
static func resolve(text: String) -> String:
	var out := text.replace("{move}", "Left stick" if using_gamepad else "%s / %s" % [_names(&"move_left")[0], _names(&"move_right")[0]])
	var at := out.find("{")
	while at >= 0:
		var end := out.find("}", at)
		var action := out.substr(at + 1, end - at - 1)
		out = out.substr(0, at) + label(StringName(action)) + out.substr(end + 1)
		at = out.find("{")
	return out


static func _event_name(event: InputEvent, pad: bool) -> String:
	if pad:
		if event is InputEventJoypadButton:
			return PAD_BUTTONS.get(event.button_index, "")
		if event is InputEventJoypadMotion:
			return PAD_AXES.get(event.axis, "")
		return ""
	if event is InputEventKey:
		var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return MOUSE_BUTTONS.get(event.button_index, "")
	return ""
