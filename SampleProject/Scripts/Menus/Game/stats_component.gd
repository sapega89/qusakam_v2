extends BaseMenuComponent

## 📊 StatsComponent — екран Status.
## Figma: menu-status (58:719).
##
## Формул тут немає — усе рахують наявні власники:
##   ім'я/клас       — CharacterManager (game_manager.get_active_character())
##   дані класу      — game_manager.get_class_data() → CharacterManager → JSON
##   похідні стати   — game_manager.calculate_*() → StatCalculator
##   рівень і досвід — XPManager
##
## Кадр Figma має праву колонку-портрет 640 замість панелі партії, тому на час
## показу Status панель партії ховається (див. _set_party_panel_visible).

const PLACEHOLDER := "—"

@onready var _avatar: Panel = %Avatar
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _next_level_value: Label = %NextLevelValue
@onready var _jp_value: Label = %JPValue
@onready var _primary_job: Label = %PrimaryJobName
@onready var _secondary_job: Label = %SecondaryJobName
@onready var _weapon_slots: HBoxContainer = %WeaponSlots
@onready var _hp_meter: Control = %HPMeter
@onready var _sp_meter: Control = %SPMeter
@onready var _left_attrs: VBoxContainer = %LeftAttrs
@onready var _right_attrs: VBoxContainer = %RightAttrs
@onready var _actions_row: HBoxContainer = %ActionsRow

## Рядки атрибутів з кадру: (підпис, метод GameManager, чи це частка 0..1).
const LEFT_ROWS: Array[Array] = [
	["Phys. Atk.", "calculate_physical_damage", false],
	["Phys. Def.", "calculate_physical_defense", false],
	["Accuracy", "calculate_accuracy", true],
	["Critical", "calculate_critical_chance", true],
]
const RIGHT_ROWS: Array[Array] = [
	["Elem. Atk.", "calculate_magic_damage", false],
	["Elem. Def.", "calculate_magic_defense", false],
	["Speed", "calculate_attack_speed", true],
	["Evasion", "calculate_dodge_chance", true],
]


func _initialize_component() -> void:
	_connect_live_sources()
	update_display()


## Підписка напряму на власників даних, а не на ретрансляцію через GameManager.
func _connect_live_sources() -> void:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator == null:
		return
	var character_manager: CharacterManager = service_locator.get_character_manager()
	if character_manager and not character_manager.character_changed.is_connected(_on_character_changed):
		character_manager.character_changed.connect(_on_character_changed)
	var xp_manager: XPManager = service_locator.get_xp_manager()
	if xp_manager and not xp_manager.level_up.is_connected(_on_level_up):
		xp_manager.level_up.connect(_on_level_up)


func _on_character_changed(_character_id: String) -> void:
	update_display()


func _on_level_up(_new_level: int, _old_level: int) -> void:
	update_display()


func update_display() -> void:
	if not is_node_ready() or game_manager == null:
		return
	_update_header()
	_update_jobs()
	_update_attributes()
	_update_actions()


# ── Шапка ───────────────────────────────────────────────────────────────────

func _update_header() -> void:
	var character = game_manager.get_active_character()
	_name_label.text = String(character.name) if character else PLACEHOLDER

	var avatar_box := StyleBoxFlat.new()
	avatar_box.bg_color = character.avatar_color if character else UITokens.ICON_SLOT_BG
	avatar_box.set_corner_radius_all(UITokens.RADIUS)
	avatar_box.set_border_width_all(UITokens.BORDER_WIDTH_SELECTED)
	avatar_box.border_color = UITokens.BORDER
	_avatar.add_theme_stylebox_override("panel", avatar_box)

	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	var xp_manager: XPManager = service_locator.get_xp_manager() if service_locator else null
	if xp_manager:
		_level_label.text = "Lv.%d" % xp_manager.get_level()
		_next_level_value.text = "%d EXP" % maxi(0, xp_manager.xp_for_next_level - xp_manager.current_xp)
	else:
		_level_label.text = PLACEHOLDER
		_next_level_value.text = PLACEHOLDER

	# Системи Job Points у проєкті немає — число не вигадуємо.
	_jp_value.text = PLACEHOLDER


# ── Робота / зброя ──────────────────────────────────────────────────────────

func _update_jobs() -> void:
	var character = game_manager.get_active_character()
	if character == null:
		_primary_job.text = PLACEHOLDER
		_secondary_job.text = PLACEHOLDER
		return

	var class_data: Dictionary = game_manager.get_class_data(
			String(character.class_id), String(character.subclass_id))
	_primary_job.text = String(class_data.get("name", PLACEHOLDER))
	var subclass: Dictionary = class_data.get("subclass", {})
	_secondary_job.text = String(subclass.get("name", PLACEHOLDER))

	_update_weapon_slots(character)


## Типи зброї беремо з реально екіпірованих слотів.
func _update_weapon_slots(character) -> void:
	for child in _weapon_slots.get_children():
		_weapon_slots.remove_child(child)
		child.queue_free()

	var equipped: Dictionary = character.equipment if character else {}
	var shown := 0
	for slot_id in ["sword", "polearm", "dagger", "axe", "bow", "staff"]:
		var item = equipped.get(slot_id)
		if item == null:
			continue
		_weapon_slots.add_child(_make_weapon_box(String(item.get("name", ""))))
		shown += 1
	if shown == 0:
		_weapon_slots.add_child(_make_weapon_box(""))


func _make_weapon_box(item_name: String) -> Control:
	var box := PanelContainer.new()
	box.theme_type_variation = &"BoxPanel"
	box.custom_minimum_size = Vector2(40, 40)
	var label := Label.new()
	label.theme_type_variation = &"SectionCaption"
	label.text = item_name.substr(0, 1).to_upper() if item_name != "" else PLACEHOLDER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box


# ── Атрибути ────────────────────────────────────────────────────────────────

func _update_attributes() -> void:
	_fill_meter(_hp_meter, "Max. HP", _current_hp(), game_manager.calculate_max_health())
	# SP-моделі в проєкті немає — смуга лишається порожньою.
	_fill_meter(_sp_meter, "Max. SP", -1, -1)
	_fill_rows(_left_attrs, LEFT_ROWS)
	_fill_rows(_right_attrs, RIGHT_ROWS)


func _fill_rows(container: VBoxContainer, rows: Array[Array]) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for row in rows:
		var method := String(row[1])
		var value := 0.0
		if game_manager.has_method(method):
			value = float(game_manager.call(method))
		if bool(row[2]):
			value *= 100.0
		container.add_child(_make_attr_row(String(row[0]), roundi(value)))


func _make_attr_row(label_text: String, value: int) -> Control:
	var row := PanelContainer.new()
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0, 0, 0, 0)
	line.border_width_bottom = UITokens.BORDER_WIDTH
	line.border_color = UITokens.BORDER
	line.content_margin_top = UITokens.SPACE_SM
	line.content_margin_bottom = UITokens.SPACE_SM
	row.add_theme_stylebox_override("panel", line)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(UITokens.ATTR_ICON, UITokens.ATTR_ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_box := StyleBoxFlat.new()
	icon_box.bg_color = UITokens.ICON_SLOT_BG
	icon_box.set_corner_radius_all(UITokens.RADIUS)
	icon.add_theme_stylebox_override("panel", icon_box)
	hbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.theme_type_variation = &"AttrLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.theme_type_variation = &"AttrValue"
	hbox.add_child(value_label)
	return row


## current < 0 ⇒ даних немає: "—" і порожня смуга.
func _fill_meter(meter: Control, caption: String, current: int, maximum: int) -> void:
	var caption_label: Label = meter.get_node(^"Head/Caption")
	var value_label: Label = meter.get_node(^"Head/Value")
	var max_label: Label = meter.get_node(^"Head/Max")
	var bar: ProgressBar = meter.get_node(^"Bar")

	caption_label.text = caption
	if current < 0 or maximum <= 0:
		value_label.text = PLACEHOLDER
		max_label.text = ""
		bar.max_value = 1.0
		bar.value = 0.0
		return
	value_label.text = _format_thousands(current)
	max_label.text = " / %s" % _format_thousands(maximum)
	bar.max_value = float(maximum)
	bar.value = float(current)


func _format_thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


func _current_hp() -> int:
	var player: Node = game_manager.get_current_player()
	if player:
		var health: Node = player.get_node_or_null(^"HealthComponent")
		if health and "current_health" in health:
			return int(health.current_health)
	return game_manager.calculate_max_health()


# ── Унікальні дії та таланти ────────────────────────────────────────────────

## Системи Path Action / Talent у проєкті немає. Лишаємо структуру з Figma,
## але без вигаданого контенту.
func _update_actions() -> void:
	for child in _actions_row.get_children():
		_actions_row.remove_child(child)
		child.queue_free()
	_actions_row.add_child(_make_action_card("Path Action"))
	_actions_row.add_child(_make_action_card("Talent"))


func _make_action_card(caption: String) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"ActionCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UITokens.SPACE_SM)
	card.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UITokens.SPACE_SM)

	var caption_label := Label.new()
	caption_label.text = caption.to_upper()
	caption_label.theme_type_variation = &"CardCaption"
	head.add_child(caption_label)

	var divider := Panel.new()
	divider.custom_minimum_size = Vector2(1, 12)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var divider_box := StyleBoxFlat.new()
	divider_box.bg_color = UITokens.ACCENT
	divider.add_theme_stylebox_override("panel", divider_box)
	head.add_child(divider)

	var title_label := Label.new()
	title_label.text = PLACEHOLDER
	title_label.theme_type_variation = &"CardTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	col.add_child(head)
	return card


# ── Панель партії ───────────────────────────────────────────────────────────

## Figma menu-status має праву колонку-портрет 640 замість панелі партії.
## Ховаємо її на час показу; прибереться на етапі спільного шелу.
func _set_party_panel_visible(value: bool) -> void:
	var panel: Node = get_tree().get_first_node_in_group(&"ui_party_panel")
	if panel:
		panel.visible = value


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		# game_menu ховає панель-предка, а не сам компонент, тому власний
		# visible лишається true — питаємо саме про видимість у дереві.
		var shown := is_visible_in_tree()
		_set_party_panel_visible(not shown)
		if shown:
			update_display()
