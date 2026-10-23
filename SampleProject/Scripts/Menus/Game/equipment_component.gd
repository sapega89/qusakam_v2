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
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")
const EQUIP_PICKER := preload("res://SampleProject/UI/Components/equip_picker.tscn")
## Рядки — шаблони зі сцени (D117): %SlotRow, %AttrRow (обидві колонки). Стилі — з теми
## (AvatarChip, ListRow, IconSlot, AccentDot, AttrRow).
const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")

## 12 слотів із player_state.equipment (mace — D147) — це і є реальна модель.
## Figma показує 8 (без polearm/axe/staff); вигадувати слоти не можна,
## ховати справжні — теж, тому виводимо всі 12.
const SLOTS: Array[Array] = [
	["sword", "SWORDS"],
	["polearm", "POLEARMS"],
	["dagger", "DAGGERS"],
	["axe", "AXES"],
	["mace", "MACES"],
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
	["Max. SP", "", false],  # SkillManager.get_max_sp() (D146), без дельти
	["Elem. Atk.", "calculate_magic_damage", false],
	["Elem. Def.", "calculate_magic_defense", false],
	["Speed", "calculate_attack_speed", true],
	["Evasion", "calculate_dodge_chance", true],
]

@onready var _char_name: Label = %CharName
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _slot_row: Button = %SlotRow
@onready var _optimize_button: Button = %OptimizeButton
@onready var _unequip_button: Button = %UnequipAllButton
@onready var _left_attrs: VBoxContainer = %LeftAttrs
@onready var _right_attrs: VBoxContainer = %RightAttrs
## Один шаблон на обидві колонки: права заповнюється його копіями.
@onready var _attr_row: PanelContainer = %AttrRow

var _slot_rows: Dictionary = {}  # slot_id -> Button


## Слот під фокусом — для підказки після зміни пристрою.
var _focused_slot: String = ""


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
	if not EventBus.input_device_changed.is_connected(_on_input_device_changed):
		EventBus.input_device_changed.connect(_on_input_device_changed)


## Пристрій змінився — підказка слота під фокусом називає кнопку нового (BACKLOG 24).
func _on_input_device_changed(_pad: bool) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if is_visible_in_tree() and _focused_slot != "" and focused and is_ancestor_of(focused):
		_on_slot_focused(_focused_slot)


func _on_equipment_event(_character_id: String, _slot_id: String, _item_id: String) -> void:
	update_display()


func _on_equipment_unequipped(_character_id: String, _slot_id: String) -> void:
	update_display()


# ── Рядки слотів ────────────────────────────────────────────────────────────

func _build_slot_rows() -> void:
	var rows := RowFill.fill(_slot_list, _slot_row, SLOTS.size())
	for i in rows.size():
		var slot_id := String(SLOTS[i][0])
		var row: Button = rows[i]
		row.name = slot_id
		row.get_node(^"Row/Caption").text = String(SLOTS[i][1])
		row.pressed.connect(_on_slot_pressed.bind(slot_id))
		row.focus_entered.connect(_on_slot_focused.bind(slot_id))
		_slot_rows[slot_id] = row


## Клік / Enter / A по слоту — вікно з предметами із сумки, що влазять у цей слот (D288).
func _on_slot_pressed(slot_id: String) -> void:
	var layer: ModalLayer = ServiceLocator.get_ui_manager().get_modal_layer()
	layer.show_custom_modal(EQUIP_PICKER)
	layer.active_modal.show_slot(_slot_caption(slot_id), _fitting_items(slot_id), not _equipped(slot_id).is_empty())
	layer.modal_closed.connect(_on_slot_picked.bind(slot_id), CONNECT_ONE_SHOT)


func _on_slot_picked(result: String, slot_id: String) -> void:
	match result:
		"cancel":
			pass
		"unequip":
			_get_equipment_manager().unequip_item(String(game_manager.get_active_character().character_id), slot_id)
		_:
			_equip(slot_id, result, item_database.get_item(result))
	(_slot_rows[slot_id] as Control).grab_focus.call_deferred()


## Предмети із сумки для слота; вдягнутий зараз позначено.
func _fitting_items(slot_id: String) -> Array:
	var worn := String(_equipped(slot_id).get("id", ""))
	var out: Array = []
	var bag: Dictionary = game_manager.inventory_manager.get_items_dict()
	for item_id in bag:
		var data: Dictionary = item_database.get_item(item_id)
		if int(bag[item_id]) <= 0 or not InventorySlotRules.fits(data, slot_id):
			continue
		out.append({"id": item_id, "name": item_database.get_item_name(item_id),
			"icon": item_database.get_item_icon(item_id), "count": bag[item_id],
			"subtitle": "Equipped" if item_id == worn else ""})
	return out


## Підказка в нижній панелі — щоб опис працював і з клавіатури.
func _on_slot_focused(slot_id: String) -> void:
	_focused_slot = slot_id
	var bar := get_tree().get_first_node_in_group(&"ui_bottom_bar")
	var item := _equipped(slot_id)
	if item.is_empty():
		bar.set_context_hint(InputGlyphs.resolve(tr("%s — empty. Press {ui_accept} to choose an item.") % _slot_caption(slot_id)))
	else:
		bar.set_context_hint("%s — %s" % [_slot_caption(slot_id), item_database.get_item_name(String(item.id))])


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
			item_label.text = item_database.get_item_name(String(item.id))
			item_label.theme_type_variation = &"SlotItemName"
			dot.visible = true


## Значення беремо з GameManager (делегати до StatCalculator), а дельту — як
## різницю "зі спорядженням" мінус "без спорядження". Нічого не дублюємо.
func _update_attributes() -> void:
	var character = game_manager.get_active_character()
	var attributes: CharacterAttributes = character.attributes if character else null
	var equipment_stats: Dictionary = character.get_equipment_stats() if character else {}

	var left := RowFill.fill(_left_attrs, _attr_row, 5)
	var right := RowFill.fill(_right_attrs, _attr_row, ATTR_ROWS.size() - 5)
	var rows: Array = left + right
	for i in ATTR_ROWS.size():
		_fill_attr_row(rows[i], ATTR_ROWS[i], attributes, equipment_stats)


func _fill_attr_row(row: Control, spec: Array, attributes: CharacterAttributes, equipment_stats: Dictionary) -> void:
	var method := String(spec[1])
	var is_ratio := bool(spec[2])
	var value_label: Label = row.get_node(^"Row/Value")
	var delta_label: Label = row.get_node(^"Row/Delta")
	row.get_node(^"Row/Name").text = String(spec[0])

	# Max. SP — пул SkillManager (D146); жодна екіпіровка SP не змінює, тож без дельти.
	if method == "":
		value_label.text = str(ServiceLocator.get_skill_manager().get_max_sp())
		delta_label.visible = false
		return

	var current := _stat_value(method, is_ratio)
	value_label.text = str(current)
	var delta := current - _stat_without_equipment(method, is_ratio, attributes)
	delta_label.visible = delta != 0 and not equipment_stats.is_empty()
	delta_label.text = "(%s%d)" % ["+" if delta > 0 else "", delta]


func _stat_value(method: String, is_ratio: bool) -> int:
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
			# Рівень і пасивки — як у GameManager.calculate_max_health(), інакше рахувались би внеском речей
			value = StatCalculator.calculate_max_health(attributes, bare) + game_manager.level_and_passive_health()
		"calculate_physical_damage":
			# Рівень, пасивки, Strength — як у GameManager.calculate_physical_damage(), інакше рахувались би внеском речей
			value = StatCalculator.calculate_physical_damage(attributes, bare) + game_manager.level_and_passive_attack()
		"calculate_magic_damage":
			value = StatCalculator.calculate_magic_damage(attributes, bare)
		"calculate_physical_defense":
			value = StatCalculator.calculate_physical_defense(bare)
		"calculate_magic_defense":
			value = StatCalculator.calculate_magic_defense(bare)
		"calculate_attack_speed":
			value = game_manager.with_attribute_ratio("attack_speed", StatCalculator.calculate_attack_speed(attributes))
		"calculate_dodge_chance":
			value = game_manager.with_attribute_ratio("dodge_chance", StatCalculator.calculate_dodge_chance(attributes))
		"calculate_accuracy":
			value = StatCalculator.calculate_accuracy(attributes)
		"calculate_critical_chance":
			value = game_manager.with_attribute_ratio("crit_chance", StatCalculator.calculate_critical_chance(attributes))
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
	return ServiceLocator.get_equipment_manager()


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
