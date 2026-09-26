extends BaseMenuComponent

## 🎓 SkillsComponent — екран Skills.
## Figma: menu-skills (58:453). Розбір і виміри: design/skills_ui_mapping.md
##
## Повністю data-driven: у сцені немає жодного рядка навички. Колонки, секції
## та стани будуються з SkillDatabase + класу активного персонажа + SkillManager.
## Нова навичка в skills.json з'явиться тут без правок .tscn.
##
## UI НЕ редагує player_state і НЕ дублює правила: чому навичка недоступна —
## завжди питаємо в SkillManager.can_unlock().
##
## SP тут свідомо НЕ показується (рішення D27): це бойовий ресурс, його місце —
## бойовий HUD, а не екран прогресії.

const PLACEHOLDER := "—"
const UNKNOWN_NAME := "???"

@onready var _char_name: Label = %CharName
@onready var _char_class: Label = %CharClass
@onready var _avatar: Panel = %Avatar
@onready var _jp_value: Label = %JPValue
@onready var _primary_column: VBoxContainer = %PrimaryColumn
@onready var _secondary_column: VBoxContainer = %SecondaryColumn
@onready var _empty_label: Label = %EmptyLabel
@onready var _columns: HBoxContainer = %Columns

var _selected_id: String = ""
var _row_group := ButtonGroup.new()
var _rows: Dictionary = {}  # skill_id -> Button

var _skill_manager: Node = null
var _skill_database: Node = null


func _initialize_component() -> void:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator:
		_skill_manager = service_locator.get_skill_manager()
	_skill_database = _resolve_database()
	_connect_live_sources()
	update_display()


func _resolve_database() -> Node:
	var tree := get_tree()
	return tree.root.get_node_or_null(^"SkillDatabase") if tree else null


## Підписка на реальні події, а не опитування в _process.
func _connect_live_sources() -> void:
	for pair in [
		[EventBus.job_points_changed, _on_job_points_changed],
		[EventBus.skill_unlocked, _on_skill_unlocked],
	]:
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])


func _on_job_points_changed(_current: int, _previous: int) -> void:
	_refresh_header()
	_refresh_rows()


func _on_skill_unlocked(_skill_id: String) -> void:
	update_display()


# ── Побудова ────────────────────────────────────────────────────────────────

func update_display() -> void:
	if not is_node_ready() or _skill_manager == null:
		return
	_refresh_header()
	_rebuild_columns()


func _refresh_header() -> void:
	var character = game_manager.get_active_character() if game_manager else null
	_char_name.text = String(character.name) if character else PLACEHOLDER

	var box := StyleBoxFlat.new()
	box.bg_color = character.avatar_color if character else UITokens.ICON_SLOT_BG
	box.set_corner_radius_all(UITokens.RADIUS)
	box.set_border_width_all(UITokens.BORDER_WIDTH)
	box.border_color = UITokens.BORDER
	_avatar.add_theme_stylebox_override("panel", box)

	_char_class.text = _class_name(character)
	_jp_value.text = "%d JP" % _skill_manager.get_job_points()


## Назви класів у pathfinder_classes.json поки порожні — показуємо прочерк,
## а не внутрішній id. Та сама домовленість, що й на екрані Status.
func _class_name(character) -> String:
	if character == null or game_manager == null:
		return PLACEHOLDER
	var data: Dictionary = game_manager.get_class_data(
			String(character.class_id), String(character.subclass_id))
	var value := String(data.get("name", "")).strip_edges()
	return value if not value.is_empty() else PLACEHOLDER


func _rebuild_columns() -> void:
	for column in [_primary_column, _secondary_column]:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
	_rows.clear()

	var character = game_manager.get_active_character() if game_manager else null
	var primary_id := String(character.class_id) if character else ""
	var secondary_id := String(character.subclass_id) if character else ""

	var primary := _skills_for(primary_id)
	var secondary := _skills_for(secondary_id)

	# Чесний порожній стан: продакшн skills.json навмисно порожній.
	var has_any := not primary.is_empty() or not secondary.is_empty()
	_columns.visible = has_any
	_empty_label.visible = not has_any
	if not has_any:
		_empty_label.text = "No skills available yet."
		return

	_build_column(_primary_column, primary_id, "Primary Class Tree", primary)
	_build_column(_secondary_column, secondary_id, "Secondary Class Tree", secondary)


## Навички колонки: прив'язані до цього class_id/subclass_id плюс загальні.
func _skills_for(owner_id: String) -> Array:
	if _skill_database == null or owner_id.is_empty():
		return []
	var result: Array = []
	for definition in _skill_database.get_all_skills():
		if definition.class_id == owner_id or definition.subclass_id == owner_id:
			result.append(definition)
	return result


func _build_column(column: VBoxContainer, owner_id: String, subtitle: String, definitions: Array) -> void:
	column.add_child(_make_column_header(owner_id, subtitle, definitions))

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


func _make_column_header(owner_id: String, subtitle: String, definitions: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITokens.SPACE_2XS)

	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = _column_title(owner_id)
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
	return box


func _column_title(owner_id: String) -> String:
	if game_manager == null or owner_id.is_empty():
		return PLACEHOLDER
	var data: Dictionary = game_manager.get_class_data(owner_id, owner_id)
	var value := String(data.get("name", "")).strip_edges()
	if value.is_empty():
		var subclass: Dictionary = data.get("subclass", {})
		value = String(subclass.get("name", "")).strip_edges()
	return value if not value.is_empty() else PLACEHOLDER


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

	var hbox := HBoxContainer.new()
	hbox.name = "Row"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = UITokens.PANEL_PADDING
	hbox.offset_right = -UITokens.PANEL_PADDING
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", UITokens.SPACE_MD)
	row.add_child(hbox)

	var marker := Panel.new()
	marker.name = "Marker"
	marker.custom_minimum_size = Vector2(14, 14)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var marker: Panel = row.get_node(^"Row/Marker")

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

	# Вартість показуємо лише у виділеного і ще не вивченого рядка — як у Figma.
	cost_label.visible = selected and not unlocked
	cost_label.text = "%d JP" % definition.jp_cost
	# Figma малює акцентний текст на акцентній заливці — нечитабельно.
	# Свідомо беремо контрастний колір (див. design/ui_visual_qa.md, D26).
	cost_label.add_theme_color_override("font_color", UITokens.ON_ACCENT)

	var marker_box := StyleBoxFlat.new()
	marker_box.set_corner_radius_all(UITokens.RADIUS)
	if unlocked:
		marker_box.bg_color = UITokens.ACCENT
	else:
		marker_box.bg_color = Color(0, 0, 0, 0)
		marker_box.set_border_width_all(UITokens.BORDER_WIDTH)
		marker_box.border_color = UITokens.TEXT_MUTED if hidden else UITokens.BORDER
	marker.add_theme_stylebox_override("panel", marker_box)

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
	if bar == null or not bar.has_method("set_context_hint"):
		return
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
	if not definition.prerequisites.is_empty():
		parts.append("Requires: %s" % ", ".join(definition.prerequisites))
	parts.append(_reason_text(definition.id))
	return "  ·  ".join(parts)


## Пояснення бере вердикт SkillManager — правила тут не дублюються.
func _reason_text(skill_id: String) -> String:
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
		_:
			return ""


## Спроба вивчити виділену навичку. Валідація — на боці SkillManager.
func try_unlock_selected() -> int:
	if _selected_id.is_empty() or _skill_manager == null:
		return SkillManager.Result.UNKNOWN_SKILL
	var verdict: int = _skill_manager.unlock_skill(_selected_id)
	if verdict == SkillManager.Result.OK:
		update_display()
	else:
		_publish_details(_selected_id)
	return verdict


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _selected_id.is_empty():
		try_unlock_selected()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		var shown := is_visible_in_tree()
		var party := get_tree().get_first_node_in_group(&"ui_party_panel")
		if party:
			party.visible = not shown
		if shown:
			update_display()
