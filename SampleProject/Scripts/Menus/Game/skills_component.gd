extends BaseMenuComponent

## 🎓 SkillsComponent — екран Skills.
## Figma: menu-skills (58:453). Розбір і виміри: design/skills_ui_mapping.md
##
## Повністю data-driven: у сцені немає жодного рядка навички. Колонки, секції
## та стани будуються з SkillDatabase + класу активного персонажа + SkillManager.
## Дерева (D283): ліва колонка — стовбур Holy Warrior, права — дерево клятви під трьома вкладками.
## Нова навичка в skills.json з'явиться тут без правок .tscn.
##
## UI НЕ редагує player_state і НЕ дублює правила: чому навичка недоступна —
## завжди питаємо в SkillManager.can_unlock().
##
## SP тут свідомо НЕ показується (рішення D27): це бойовий ресурс, його місце —
## бойовий HUD, а не екран прогресії.

const PLACEHOLDER := "—"
const ICON_CHECK := preload("res://SampleProject/Assets/UI/Icons/check_circle.svg")
const ICON_LOCK := preload("res://SampleProject/Assets/UI/Icons/lock.svg")
const UNKNOWN_NAME := "???"

@onready var _char_name: Label = %CharName
@onready var _char_class: Label = %CharClass
@onready var _avatar: Panel = %Avatar
@onready var _jp_value: Label = %JPValue
@onready var _primary_column: VBoxContainer = %PrimaryColumn
@onready var _secondary_column: VBoxContainer = %SecondaryColumn
@onready var _empty_label: Label = %EmptyLabel
@onready var _columns: HBoxContainer = %Columns
@onready var _tree_tabs: HBoxContainer = %TreeTabs

var _selected_id: String = ""
var _row_group := ButtonGroup.new()
var _rows: Dictionary = {}  # skill_id -> Button
var _tab_group := ButtonGroup.new()
## Яке дерево клятви показане праворуч (D283); "" — ще не вибрано: присягнуте або перше.
var _shown_oath: String = ""

var _skill_manager: Node = null
var _skill_database: Node = null


func _initialize_component() -> void:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	_skill_manager = service_locator.get_skill_manager()
	_skill_database = _resolve_database()
	_connect_live_sources()
	_build_tabs()
	update_display()


func _resolve_database() -> Node:
	return get_tree().root.get_node(^"SkillDatabase")


## Підписка на реальні події, а не опитування в _process.
func _connect_live_sources() -> void:
	for pair in [
		[EventBus.job_points_changed, _on_job_points_changed],
		[EventBus.skill_unlocked, _on_skill_unlocked],
		[EventBus.skill_upgraded, _on_skill_upgraded],
		[EventBus.oath_sworn, _on_oath_sworn],
		[EventBus.skills_reset, _on_skills_reset],
	]:
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])


func _on_job_points_changed(_current: int, _previous: int) -> void:
	_refresh_header()
	_refresh_rows()


func _on_skill_unlocked(_skill_id: String) -> void:
	update_display()


func _on_skill_upgraded(_skill_id: String, _rank: int) -> void:
	update_display()


func _on_oath_sworn(oath_id: String) -> void:
	_shown_oath = oath_id
	update_display()


func _on_skills_reset(_refunded: int) -> void:
	update_display()


## Вкладки дерев клятв — з даних (skills.json → oaths), у порядку файлу.
func _build_tabs() -> void:
	for oath_id in _skill_database.oaths:
		var tab := Button.new()
		tab.name = oath_id
		tab.text = String(_skill_database.get_oath(oath_id).name)
		tab.theme_type_variation = &"TabButton"
		tab.toggle_mode = true
		tab.button_group = _tab_group
		tab.focus_mode = Control.FOCUS_ALL
		tab.pressed.connect(show_tree.bind(oath_id))
		_tree_tabs.add_child(tab)


## Показати дерево клятви праворуч (вкладка: клавіатура, геймпад, миша).
func show_tree(oath_id: String) -> void:
	_shown_oath = oath_id
	update_display()


# ── Побудова ────────────────────────────────────────────────────────────────

func update_display() -> void:
	if not is_node_ready() or _skill_manager == null:
		return
	if _shown_oath.is_empty():
		_shown_oath = _skill_manager.get_oath() if _skill_manager.get_oath() != "" else String(_skill_database.oaths.keys()[0])
	for tab in _tree_tabs.get_children():
		tab.set_pressed_no_signal(tab.name == _shown_oath)
	# Перебудова звільняє рядки — фокус клавіатури/геймпада повертаємо на вибраний рядок.
	var focused := get_viewport().gui_get_focus_owner()
	var had_row_focus := focused != null and focused in _rows.values()
	_refresh_header()
	_rebuild_columns()
	if had_row_focus and _rows.has(_selected_id):
		_rows[_selected_id].grab_focus()


func _refresh_header() -> void:
	var character = game_manager.get_active_character() if game_manager else null
	_char_name.text = String(character.name) if character else PLACEHOLDER

	var box := StyleBoxFlat.new()
	box.bg_color = character.avatar_color if character else UITokens.ICON_SLOT_BG
	box.set_corner_radius_all(UITokens.RADIUS)
	box.set_border_width_all(UITokens.BORDER_WIDTH)
	box.border_color = UITokens.BORDER
	_avatar.add_theme_stylebox_override("panel", box)

	_char_class.text = _skill_manager.class_title()  # D280: Holy Warrior → назва клятви
	_jp_value.text = "%d JP" % _skill_manager.get_job_points()


func _rebuild_columns() -> void:
	for column in [_primary_column, _secondary_column]:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
	_rows.clear()

	var character = game_manager.get_active_character() if game_manager else null
	var class_id := String(character.class_id) if character else ""
	var trunk: Array = _skill_database.get_all_skills().filter(
			func(d): return d.oath == "" and (d.class_id == "" or d.class_id == class_id))
	var tree: Array = _skill_database.get_all_skills().filter(func(d): return d.oath == _shown_oath)

	# Чесний порожній стан: немає жодної навички для цього героя.
	var has_any := not trunk.is_empty() or not tree.is_empty()
	_columns.visible = has_any
	_empty_label.visible = not has_any
	if not has_any:
		_empty_label.text = "No skills available yet."
		return

	_build_column(_primary_column, _skill_database.class_name_trunk, "Primary Class Tree", trunk)
	var oath: Dictionary = _skill_database.get_oath(_shown_oath)
	_build_column(_secondary_column, String(oath.name),
			"Secondary Class Tree · %s" % String(oath.tree), tree, _tree_status())


## Стан правого дерева (D280): клятви ще немає / це клятва героя / чужа клятва.
func _tree_status() -> String:
	var sworn: String = _skill_manager.get_oath()
	if sworn.is_empty():
		return "Swear an oath in the City (level %d)" % int(_skill_database.get_oath(_shown_oath).level)
	return "Your oath" if sworn == _shown_oath else "Sworn to another oath"


func _build_column(column: VBoxContainer, title: String, subtitle: String, definitions: Array, status: String = "") -> void:
	column.add_child(_make_column_header(title, subtitle, definitions, status))

	# Секції з Figma: Job Skills = активні, Support Skills = пасивні.
	var active: Array = definitions.filter(func(d): return d.is_active())
	var passive: Array = definitions.filter(func(d): return not d.is_active())
	if not active.is_empty():
		column.add_child(_make_section_label("Job Skills"))
		for definition in active:
			column.add_child(_make_skill_row(definition))
	if not passive.is_empty():
		column.add_child(_make_section_label("Support Skills"))
		for definition in passive:
			column.add_child(_make_skill_row(definition))


func _make_column_header(title_text: String, subtitle: String, definitions: Array, status: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITokens.SPACE_2XS)

	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = title_text if not title_text.is_empty() else PLACEHOLDER
	title.theme_type_variation = &"TreeTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var cost_box := VBoxContainer.new()
	cost_box.alignment = BoxContainer.ALIGNMENT_END
	var cost_caption := Label.new()
	cost_caption.text = "NEXT SKILL COST"
	cost_caption.theme_type_variation = &"MicroLabel"
	cost_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var cost_value := Label.new()
	cost_value.text = _next_cost(definitions)
	cost_value.theme_type_variation = &"MetaValue"
	cost_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_box.add_child(cost_caption)
	cost_box.add_child(cost_value)
	row.add_child(cost_box)
	box.add_child(row)

	var sub := Label.new()
	sub.text = subtitle
	sub.theme_type_variation = &"SmallLabel"
	box.add_child(sub)
	if not status.is_empty():
		var note := Label.new()
		note.name = "TreeStatus"
		note.text = status
		note.theme_type_variation = &"MutedLabel"
		box.add_child(note)
	return box


## Найдешевша ще не вивчена навичка колонки.
func _next_cost(definitions: Array) -> String:
	var cheapest := -1
	for definition in definitions:
		if _skill_manager.is_unlocked(definition.id):
			continue
		if cheapest < 0 or definition.jp_cost < cheapest:
			cheapest = definition.jp_cost
	return "%d JP" % cheapest if cheapest >= 0 else PLACEHOLDER


func _make_section_label(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SectionLabel"
	return label


func _make_skill_row(definition: SkillDefinition) -> Button:
	var row := Button.new()
	row.name = definition.id
	row.theme_type_variation = &"SkillRow"
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_ALL
	row.pressed.connect(_on_row_selected.bind(definition.id))
	row.focus_entered.connect(_on_row_selected.bind(definition.id))
	# Сигнал gui_input приходить раніше, ніж Button сам «з'їдає» ui_accept, — інакше вивчити навичку
	# з виділеного рядка було неможливо (фокус завжди на рядку, а не на компоненті).
	row.gui_input.connect(_on_row_input.bind(definition.id))

	var hbox := HBoxContainer.new()
	hbox.name = "Row"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = UITokens.PANEL_PADDING
	hbox.offset_right = -UITokens.PANEL_PADDING
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", UITokens.SPACE_MD)
	row.add_child(hbox)

	var marker := TextureRect.new()
	marker.name = "Marker"
	marker.custom_minimum_size = Vector2(14, 14)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(marker)

	var name_label := Label.new()
	name_label.name = "SkillName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)

	var cost_label := Label.new()
	cost_label.name = "Cost"
	cost_label.theme_type_variation = &"SkillCost"
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(cost_label)

	_rows[definition.id] = row
	_apply_row_state(definition, row)
	return row


## Стан рядка визначає SkillManager — UI лише малює його вердикт.
func _apply_row_state(definition: SkillDefinition, row: Button) -> void:
	var unlocked: bool = _skill_manager.is_unlocked(definition.id)
	var verdict: int = _skill_manager.can_unlock(definition.id)
	var hidden := verdict == SkillManager.Result.MISSING_PREREQUISITE

	var name_label: Label = row.get_node(^"Row/SkillName")
	var cost_label: Label = row.get_node(^"Row/Cost")
	var marker: TextureRect = row.get_node(^"Row/Marker")

	if hidden:
		name_label.text = UNKNOWN_NAME
	else:
		name_label.text = definition.name if not definition.name.is_empty() else definition.id

	var selected := definition.id == _selected_id
	if selected:
		name_label.theme_type_variation = &"SkillNameSelected"
	elif unlocked:
		name_label.theme_type_variation = &"SkillName"
	else:
		name_label.theme_type_variation = &"SkillNameLocked"

	# Вартість — лише у виділеного рядка: вивчення (jp_cost) або покращення до 20 (D150).
	var upgradable: bool = unlocked and _skill_manager.get_rank(definition.id) < SkillManager.MAX_RANK
	cost_label.visible = selected and (not unlocked or upgradable)
	cost_label.text = "%d JP" % (SkillManager.UPGRADE_COST if unlocked else definition.jp_cost)
	# Figma малює акцентний текст на акцентній заливці — нечитабельно.
	# Свідомо беремо контрастний колір (див. design/ui_visual_qa.md, D26).
	cost_label.add_theme_color_override("font_color", UITokens.ON_ACCENT)

	# Гліфи з Figma: вивчене — check-circle, приховане — замок.
	if unlocked:
		marker.texture = ICON_CHECK
		marker.modulate = UITokens.ACCENT
		marker.visible = true
	elif hidden:
		marker.texture = ICON_LOCK
		marker.modulate = UITokens.TEXT_MUTED
		marker.visible = true
	else:
		marker.texture = ICON_LOCK
		marker.modulate = UITokens.BORDER
		marker.visible = true

	row.set_pressed_no_signal(selected)


func _refresh_rows() -> void:
	if _skill_database == null:
		return
	for skill_id in _rows:
		var definition: SkillDefinition = _skill_database.get_skill(skill_id)
		if definition:
			_apply_row_state(definition, _rows[skill_id])


# ── Вибір і розблокування ───────────────────────────────────────────────────

func _on_row_selected(skill_id: String) -> void:
	_selected_id = skill_id
	_refresh_rows()
	_publish_details(skill_id)


## Деталі йдуть у нижню панель, тож клавіатура/геймпад бачать те саме, що й миша.
func _publish_details(skill_id: String) -> void:
	var bar := get_tree().get_first_node_in_group(&"ui_bottom_bar")
	var definition: SkillDefinition = _skill_database.get_skill(skill_id) if _skill_database else null
	if definition == null:
		bar.set_context_hint("")
		return
	bar.set_context_hint(_describe(definition))


## Тільки реальні поля визначення — відсутнє не вигадуємо.
func _describe(definition: SkillDefinition) -> String:
	var parts: Array[String] = []
	parts.append(definition.name if not definition.name.is_empty() else definition.id)
	if not definition.description.is_empty():
		parts.append(definition.description)
	parts.append("Active" if definition.is_active() else "Passive")
	if definition.jp_cost > 0:
		parts.append("%d JP" % definition.jp_cost)
	if definition.sp_cost > 0:
		parts.append("%d SP" % definition.sp_cost)
	if definition.required_level > 1:
		parts.append("Lv.%d" % definition.required_level)
	if definition.oath != "":
		parts.append("Oath: %s" % String(_skill_database.get_oath(definition.oath).name))
	if not definition.prerequisites.is_empty():
		parts.append("Requires: %s" % ", ".join(definition.prerequisites))
	if _skill_manager.is_unlocked(definition.id):
		parts.append("Rank %d/%d" % [_skill_manager.get_rank(definition.id), SkillManager.MAX_RANK])
	parts.append(_reason_text(definition.id))
	return "  ·  ".join(parts)


## Пояснення бере вердикт SkillManager — правила тут не дублюються.
func _reason_text(skill_id: String) -> String:
	if _skill_manager.is_unlocked(skill_id):
		match _skill_manager.can_upgrade(skill_id):
			SkillManager.Result.OK:
				return "Press A to upgrade (+10%%, %d JP)" % SkillManager.UPGRADE_COST
			SkillManager.Result.MAX_RANK:
				return "Max rank"
			_:
				return "Not enough JP to upgrade"
	match _skill_manager.can_unlock(skill_id):
		SkillManager.Result.OK:
			return "Press A to unlock"
		SkillManager.Result.ALREADY_UNLOCKED:
			return "Learned"
		SkillManager.Result.NOT_ENOUGH_JP:
			return "Not enough JP"
		SkillManager.Result.LEVEL_TOO_LOW:
			return "Level too low"
		SkillManager.Result.MISSING_PREREQUISITE:
			return "Prerequisite not learned"
		SkillManager.Result.NO_OATH:
			var oath_id: String = _skill_database.get_skill(skill_id).oath
			return "Swear an oath in the City (level %d)" % int(_skill_database.get_oath(oath_id).level)
		SkillManager.Result.OTHER_OATH:
			return "Sworn to another oath"
		_:
			return ""


## Спроба вивчити виділену навичку. Валідація — на боці SkillManager.
func try_unlock_selected() -> int:
	if _selected_id.is_empty() or _skill_manager == null:
		return SkillManager.Result.UNKNOWN_SKILL
	# Вивчена навичка — покращення (D150), інакше — вивчення.
	var verdict: int = _skill_manager.upgrade_skill(_selected_id) if _skill_manager.is_unlocked(_selected_id) 			else _skill_manager.unlock_skill(_selected_id)
	if verdict == SkillManager.Result.OK:
		update_display()
	else:
		_publish_details(_selected_id)
	return verdict


## Enter / геймпад A на рядку — вивчити або покращити; подвійний клік мишею — те саме (B77, D283).
func _on_row_input(event: InputEvent, skill_id: String) -> void:
	var mouse := event as InputEventMouseButton
	var double_click := mouse != null and mouse.double_click and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if double_click or (event.is_action_pressed("ui_accept") and not _selected_id.is_empty()):
		if double_click:
			_on_row_selected(skill_id)
		try_unlock_selected()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		var shown := is_visible_in_tree()
		var party := get_tree().get_first_node_in_group(&"ui_party_column")
		if party:
			party.visible = not shown
		if shown:
			update_display()
