extends BaseMenuComponent

## ⚔️ EquipmentComponent — екран Equipment.
## Figma: UI/Equipment Panel (258:5110) + UI/Attributes Panel (258:5111).
## (Сам кадр menu-equipment 58:4 порожній — дизайн живе в цих двох компонентах.)
##
## Запис екіпіровки йде ЛИШЕ через EquipmentManager → EventBus → CharacterManager,
## тож player_state оновлюється і зберігається штатно. Компонент нічого не пише
## напряму. Формули стат лишаються в StatCalculator.
## Повний розбір потоку даних: design/equipment_data_flow.md

const PLACEHOLDER := "(empty)"

## 11 слотів із player_state.equipment — це і є реальна модель.
## Figma показує 8 (без polearm/axe/staff); вигадувати слоти не можна,
## ховати справжні — теж, тому виводимо всі 11.
const SLOTS: Array[Array] = [
	["sword", "SWORDS"],
	["polearm", "POLEARMS"],
	["dagger", "DAGGERS"],
	["axe", "AXES"],
	["bow", "BOWS"],
	["staff", "STAVES"],
	["shield", "SHIELDS"],
	["head", "HEAD"],
	["body", "BODY"],
	["accessory_1", "ACCESSORIES"],
	["accessory_2", "ACCESSORIES"],
]

## Підпис → метод GameManager → чи це частка 0..1.
const ATTR_ROWS: Array[Array] = [
	["Max. HP", "calculate_max_health", false],
	["Phys. Atk.", "calculate_physical_damage", false],
	["Phys. Def.", "calculate_physical_defense", false],
	["Accuracy", "calculate_accuracy", true],
	["Critical", "calculate_critical_chance", true],
	["Max. SP", "", false],
	["Elem. Atk.", "calculate_magic_damage", false],
	["Elem. Def.", "calculate_magic_defense", false],
	["Speed", "calculate_attack_speed", true],
	["Evasion", "calculate_dodge_chance", true],
]

@onready var _char_name: Label = %CharName
@onready var _avatar: Panel = %Avatar
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _optimize_button: Button = %OptimizeButton
@onready var _unequip_button: Button = %UnequipAllButton
@onready var _left_attrs: VBoxContainer = %LeftAttrs
@onready var _right_attrs: VBoxContainer = %RightAttrs

var _slot_rows: Dictionary = {}  # slot_id -> Button


func _initialize_component() -> void:
	_optimize_button.pressed.connect(_on_optimize_pressed)
	_unequip_button.pressed.connect(_on_unequip_all_pressed)
	_connect_live_sources()
	_build_slot_rows()
	update_display()


## Оновлюємось із сигналів власників — без ручної синхронізації.
func _connect_live_sources() -> void:
	if not EventBus.equipment_equipped.is_connected(_on_equipment_event):
		EventBus.equipment_equipped.connect(_on_equipment_event)
	if not EventBus.equipment_unequipped.is_connected(_on_equipment_unequipped):
		EventBus.equipment_unequipped.connect(_on_equipment_unequipped)


func _on_equipment_event(_character_id: String, _slot_id: String, _item_id: String) -> void:
	update_display()


func _on_equipment_unequipped(_character_id: String, _slot_id: String) -> void:
	update_display()


# ── Рядки слотів ────────────────────────────────────────────────────────────

func _build_slot_rows() -> void:
	for child in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	_slot_rows.clear()

	for entry in SLOTS:
		var slot_id := String(entry[0])
		var row := _make_slot_row(slot_id, String(entry[1]))
		_slot_list.add_child(row)
		_slot_rows[slot_id] = row


func _make_slot_row(slot_id: String, caption: String) -> Button:
	var row := Button.new()
	row.name = slot_id
	row.theme_type_variation = &"ListRow"
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(0, 63)
	row.pressed.connect(_on_slot_pressed.bind(slot_id))
	row.focus_entered.connect(_on_slot_focused.bind(slot_id))

	var hbox := HBoxContainer.new()
	hbox.name = "Row"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = UITokens.PANEL_PADDING
	hbox.offset_right = -UITokens.PANEL_PADDING
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", UITokens.SPACE_LG)
	row.add_child(hbox)

	var icon := Panel.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_box := StyleBoxFlat.new()
	icon_box.bg_color = UITokens.ICON_SLOT_BG
	icon_box.set_corner_radius_all(UITokens.RADIUS)
	icon.add_theme_stylebox_override("panel", icon_box)
	hbox.add_child(icon)

	var caption_label := Label.new()
	caption_label.name = "Caption"
	caption_label.text = caption
	caption_label.theme_type_variation = &"SlotCaption"
	caption_label.custom_minimum_size = Vector2(150, 0)
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(caption_label)

	var item_label := Label.new()
	item_label.name = "ItemName"
	item_label.theme_type_variation = &"SlotItemName"
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(item_label)

	var dot := Panel.new()
	dot.name = "Dot"
	dot.custom_minimum_size = Vector2(6, 6)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_box := StyleBoxFlat.new()
	dot_box.bg_color = UITokens.ACCENT
	dot_box.set_corner_radius_all(3)
	dot.add_theme_stylebox_override("panel", dot_box)
	hbox.add_child(dot)

	return row


## Клік/Enter по слоту — відкрити інвентар у режимі вибору для цього слота.
## Це наявна поведінка: InventoryComponent.set_equipment_selection_mode().
func _on_slot_pressed(slot_id: String) -> void:
	request_tab.emit("inventory")
	await get_tree().process_frame

	var game_menu := get_tree().get_first_node_in_group(&"game_menu")
	if game_menu == null:
		return
	var inventory := game_menu.find_child("InventoryComponent", true, false)
	if inventory and inventory.has_method("set_equipment_selection_mode"):
		inventory.set_equipment_selection_mode(true, slot_id, self)


## Підказка в нижній панелі — щоб опис працював і з клавіатури.
func _on_slot_focused(slot_id: String) -> void:
	var bar := get_tree().get_first_node_in_group(&"ui_bottom_bar")
	if bar == null or not bar.has_method("set_context_hint"):
		return
	var item := _equipped(slot_id)
	if item.is_empty():
		bar.set_context_hint("%s — empty. Press A to choose an item." % _slot_caption(slot_id))
	else:
		bar.set_context_hint("%s — %s" % [_slot_caption(slot_id), String(item.get("name", ""))])


func _slot_caption(slot_id: String) -> String:
	for entry in SLOTS:
		if String(entry[0]) == slot_id:
			return String(entry[1]).capitalize()
	return slot_id


func _equipped(slot_id: String) -> Dictionary:
	var character = game_manager.get_active_character() if game_manager else null
	if character == null:
		return {}
	var item = character.equipment.get(slot_id)
	return item if item is Dictionary else {}


# ── Оновлення ───────────────────────────────────────────────────────────────

func update_display() -> void:
	if not is_node_ready() or game_manager == null:
		return
	_update_header()
	_update_slots()
	_update_attributes()


func _update_header() -> void:
	var character = game_manager.get_active_character()
	_char_name.text = String(character.name) if character else "—"

	var box := StyleBoxFlat.new()
	box.bg_color = character.avatar_color if character else UITokens.ICON_SLOT_BG
	box.set_corner_radius_all(UITokens.RADIUS)
	box.set_border_width_all(UITokens.BORDER_WIDTH)
	box.border_color = UITokens.BORDER
	_avatar.add_theme_stylebox_override("panel", box)


func _update_slots() -> void:
	for entry in SLOTS:
		var slot_id := String(entry[0])
		var row: Button = _slot_rows.get(slot_id)
		if row == null:
			continue
		var item := _equipped(slot_id)
		var item_label: Label = row.get_node(^"Row/ItemName")
		var dot: Panel = row.get_node(^"Row/Dot")
		if item.is_empty():
			item_label.text = PLACEHOLDER
			item_label.theme_type_variation = &"SlotItemEmpty"
			dot.visible = false
		else:
			item_label.text = String(item.get("name", ""))
			item_label.theme_type_variation = &"SlotItemName"
			dot.visible = true


## Значення беремо з GameManager (делегати до StatCalculator), а дельту — як
## різницю "зі спорядженням" мінус "без спорядження". Нічого не дублюємо.
func _update_attributes() -> void:
	for container in [_left_attrs, _right_attrs]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()

	var character = game_manager.get_active_character()
	var attributes: CharacterAttributes = character.attributes if character else null
	var equipment_stats: Dictionary = character.get_equipment_stats() if character else {}

	for i in ATTR_ROWS.size():
		var row: Array = ATTR_ROWS[i]
		var container: VBoxContainer = _left_attrs if i < 5 else _right_attrs
		container.add_child(_make_attr_row(row, attributes, equipment_stats))


func _make_attr_row(spec: Array, attributes: CharacterAttributes, equipment_stats: Dictionary) -> Control:
	var label_text := String(spec[0])
	var method := String(spec[1])
	var is_ratio := bool(spec[2])

	var row := PanelContainer.new()
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0, 0, 0, 0)
	line.border_width_bottom = UITokens.BORDER_WIDTH
	line.border_color = UITokens.BORDER
	line.content_margin_top = UITokens.SPACE_SM
	line.content_margin_bottom = UITokens.SPACE_SM
	row.add_theme_stylebox_override("panel", line)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UITokens.SPACE_SM)
	row.add_child(hbox)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.theme_type_variation = &"MetaLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	# Max. SP не має моделі в проєкті — показуємо прочерк, а не вигадане число.
	if method == "":
		var dash := Label.new()
		dash.text = "—"
		dash.theme_type_variation = &"AttrValue"
		hbox.add_child(dash)
		return row

	var current := _stat_value(method, is_ratio)
	var value_label := Label.new()
	value_label.text = str(current)
	value_label.theme_type_variation = &"AttrValue"
	hbox.add_child(value_label)

	var delta := current - _stat_without_equipment(method, is_ratio, attributes)
	if delta != 0 and not equipment_stats.is_empty():
		var delta_label := Label.new()
		delta_label.text = "(%s%d)" % ["+" if delta > 0 else "", delta]
		delta_label.theme_type_variation = &"StatDelta"
		hbox.add_child(delta_label)
	return row


func _stat_value(method: String, is_ratio: bool) -> int:
	if not game_manager.has_method(method):
		return 0
	var value := float(game_manager.call(method))
	return roundi(value * 100.0 if is_ratio else value)


## Те саме значення, але з порожньою екіпіровкою — щоб отримати внесок речей.
func _stat_without_equipment(method: String, is_ratio: bool, attributes: CharacterAttributes) -> int:
	if attributes == null:
		return 0
	var bare := {}
	var value := 0.0
	match method:
		"calculate_max_health":
			value = StatCalculator.calculate_max_health(attributes, bare)
		"calculate_physical_damage":
			value = StatCalculator.calculate_physical_damage(attributes, bare)
		"calculate_magic_damage":
			value = StatCalculator.calculate_magic_damage(attributes, bare)
		"calculate_physical_defense":
			value = StatCalculator.calculate_physical_defense(bare)
		"calculate_magic_defense":
			value = StatCalculator.calculate_magic_defense(bare)
		"calculate_attack_speed":
			value = StatCalculator.calculate_attack_speed(attributes)
		"calculate_dodge_chance":
			value = StatCalculator.calculate_dodge_chance(attributes)
		"calculate_accuracy":
			value = StatCalculator.calculate_accuracy(attributes)
		"calculate_critical_chance":
			value = StatCalculator.calculate_critical_chance(attributes)
	return roundi(value * 100.0 if is_ratio else value)


# ── Дії ─────────────────────────────────────────────────────────────────────

## Підбирає найкращий предмет у кожен слот за сумою stats. Запис — через API.
func _on_optimize_pressed() -> void:
	if game_manager == null or item_database == null:
		return
	var character = game_manager.get_active_character()
	if character == null:
		return

	var candidates := _equippable_inventory_items()
	var used: Array[String] = []
	for entry in SLOTS:
		var slot_id := String(entry[0])
		var best := _best_item_for_slot(slot_id, candidates, used)
		if best.is_empty():
			continue
		used.append(String(best.get("id", "")))
		_equip(slot_id, String(best.get("id", "")), best.get("data", {}))


func _on_unequip_all_pressed() -> void:
	var character = game_manager.get_active_character() if game_manager else null
	if character == null:
		return
	var equipment_manager := _get_equipment_manager()
	if equipment_manager == null:
		return
	for entry in SLOTS:
		var slot_id := String(entry[0])
		if not _equipped(slot_id).is_empty():
			equipment_manager.unequip_item(String(character.character_id), slot_id)


func _equip(slot_id: String, item_id: String, item_data: Dictionary) -> void:
	# Конвеєр CharacterManager -> EventBus нічого не валідує і вдягне що завгодно
	# у будь-який слот, тому сумісність перевіряємо тут, перед запитом.
	if not InventorySlotRules.fits(item_data, slot_id):
		return
	var character = game_manager.get_active_character()
	var equipment_manager := _get_equipment_manager()
	if character == null or equipment_manager == null:
		return
	equipment_manager.equip_item(String(character.character_id), slot_id, item_id, item_data)


func _get_equipment_manager() -> Node:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator and service_locator.has_method("get_equipment_manager"):
		return service_locator.get_equipment_manager()
	return null


## Предмети з сумки, які взагалі можна вдягнути.
func _equippable_inventory_items() -> Array:
	var result: Array = []
	if game_manager == null or item_database == null:
		return result
	var inventory_manager = game_manager.inventory_manager if "inventory_manager" in game_manager else null
	if inventory_manager == null:
		return result
	for item_id in inventory_manager.get_items_dict():
		var data: Dictionary = item_database.get_item(item_id)
		if data.is_empty():
			continue
		var item_type := String(data.get("type", ""))
		if item_type == "weapon" or item_type == "armor":
			result.append({"id": item_id, "data": data})
	return result


func _best_item_for_slot(slot_id: String, candidates: Array, used: Array[String]) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	for candidate in candidates:
		var item_id := String(candidate.get("id", ""))
		if item_id in used:
			continue
		var data: Dictionary = candidate.get("data", {})
		if not InventorySlotRules.fits(data, slot_id):
			continue
		var stats: Dictionary = data.get("stats", {})
		var score: int = int(stats.get("attack", 0)) + int(stats.get("defense", 0)) + int(stats.get("magic", 0))
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree() and is_visible_in_tree():
		update_display()
