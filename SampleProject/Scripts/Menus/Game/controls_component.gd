extends Control

## Сторінка Controls (BACKLOG 28, D-28f): кожна дія гравця в порядку гри — клавіатура з мишею й геймпад.
## Відкривається з Misc → Controls, у центрі Game Menu, як список тем туторіалу. Лише показує: назви кнопок —
## InputGlyphs з InputMap, тож переназначене в Settings → Controls одразу видно тут. Рядки — шаблон %ActionRow (D117).

const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const SkillSlotInput = preload("res://SampleProject/Scripts/UI/skill_slot_input.gd")

## [назва, дія] у порядку, в якому гра їх вчить.
const ACTIONS := [
	["Move left", &"move_left"],
	["Move right", &"move_right"],
	["Jump", &"jump"],
	["Dash (twice: double dash, also in the air)", &"dodge"],
	["Climb up", &"move_up"],
	["Climb down / drop through a ledge", &"move_down"],
	["Attack (press again for a combo)", &"attack"],
	["Heavy attack", &"heavy_attack"],
	["Block (hold) / parry (tap as a yellow-glint blow lands)", &"block"],
	["Drink a potion (quick slot)", &"quick_potion"],
	["Interact, talk, pick up", &"interact"],
	["Next line of dialogue", &"dq_accept"],
	["Skip a cutscene (hold)", &"cutscene_skip"],
	["Skill slot 1", &"skill_slot_1"],
	["Skill slot 2", &"skill_slot_2"],
	["Skill slot 3", &"skill_slot_3"],
	["Skill slot 4", &"skill_slot_4"],
	["Skill slot 5", &"skill_slot_5"],
	["Skill slot 6", &"skill_slot_6"],
	["Skill slot 7", &"skill_slot_7"],
	["Skill slot 8", &"skill_slot_8"],
	["Call a companion", &"assist"],
	["Game menu", &"game_menu"],
	["Previous / next menu tab", &"menu_prev_tab"],
	["Skills screen: accept the picks", &"skills_accept"],
	["Skills screen: undo a pick", &"skills_unpick"],
]

@onready var _list: VBoxContainer = %ActionList
@onready var _row: Button = %ActionRow


## Рядок [param i]: [назва, клавіатура, геймпад] — те, що бачить гравець.
func row_texts(i: int) -> Array[String]:
	var row: Control = _list.get_child(i)
	return [row.get_node(^"Cells/Action").text, row.get_node(^"Cells/Keyboard/Badge/Key").text,
			row.get_node(^"Cells/Pad/Badge/Key").text]


func _fill() -> void:
	var rows := RowFill.fill(_list, _row, ACTIONS.size())
	for i in rows.size():
		var action: StringName = ACTIONS[i][1]
		var row: Control = rows[i]
		row.get_node(^"Cells/Action").text = ACTIONS[i][0]
		row.get_node(^"Cells/Keyboard/Badge/Key").text = _names(action, false)
		row.get_node(^"Cells/Pad/Badge/Key").text = _names(action, true)
	# Попередня й наступна вкладка — одним рядком
	var tabs: Control = rows[ACTIONS.size() - 1]
	tabs.get_node(^"Cells/Keyboard/Badge/Key").text = "%s / %s" % [_names(&"menu_prev_tab", false), _names(&"menu_next_tab", false)]
	tabs.get_node(^"Cells/Pad/Badge/Key").text = "%s / %s" % [_names(&"menu_prev_tab", true), _names(&"menu_next_tab", true)]


static func _names(action: StringName, pad: bool) -> String:
	var names := InputGlyphs.names_for(action, pad)
	if names.is_empty():
		return "—"
	# Слоти 5–8 на геймпаді — ті самі кнопки, що 1–4, з затиснутим LT (D549).
	var slot := String(action).trim_prefix("skill_slot_").to_int() - 1
	if pad and String(action).begins_with("skill_slot_") and SkillSlotInput.is_shifted(slot):
		return "%s + %s" % [InputGlyphs.names_for(SkillSlotInput.SHIFT_ACTION, true)[0], names[0]]
	return " / ".join(names.slice(0, 2))


func _notification(what: int) -> void:
	# Показали — список заново (переназначення), фокус на перший рядок: стік / стрілки гортають список.
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and is_visible_in_tree():
		_fill()
		(_list.get_child(0) as Button).grab_focus.call_deferred()
		var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
		bar.set_context_hint("Every action with its keyboard and gamepad button.")
