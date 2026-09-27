extends BaseMenuComponent

## 🎒 InventoryComponent — екран інвентарю.
## Figma: menu-inventory (46:193), UI/Inventory Center Panel (355:6423).
##
## Дані: InventoryManager (що є в сумці) + ItemDatabase (описи, іконки, індекси).
## Фільтрація спирається на готовий індекс ItemDatabase.items_by_type —
## власного індексу компонент не будує.

const ITEM_ROW_SCENE := preload("res://SampleProject/UI/Components/item_row.tscn")

## Категорії з Figma. `types` порожній ⇒ показуємо все.
## Порожня категорія (напр. KEY ITEMS) лишається доступною й показує порожній стан (D9).
const CATEGORIES: Array[Dictionary] = [
	{"id": &"all", "label": "ALL", "types": []},
	{"id": &"consumables", "label": "CONSUMABLES", "types": ["consumable"]},
	{"id": &"materials", "label": "MATERIALS", "types": ["material"]},
	{"id": &"equipment", "label": "EQUIPMENT", "types": ["weapon", "armor"]},
	{"id": &"key_items", "label": "KEY ITEMS", "types": ["key_item"]},
]

@onready var _tabs: HBoxContainer = %Tabs
@onready var _filter_button: Button = %FilterButton
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _item_list: VBoxContainer = %ItemList
@onready var _empty_label: Label = %EmptyLabel

var items: Array = []       # відфільтровані, у порядку показу
var all_items: Array = []   # усе, що є в інвентарі

var _current_category: StringName = &"all"
var _tab_buttons: Dictionary = {}       # StringName -> Button
var _tab_group := ButtonGroup.new()
var _row_group := ButtonGroup.new()
var _selected_index: int = -1

# ── Режим вибору предмета для слота екіпіровки (поведінка збережена) ────────
var equipment_selection_mode: bool = false
var equipment_slot_id: String = ""
var equipment_component: Node = null


func _initialize_component() -> void:
	_build_tabs()
	_filter_button.pressed.connect(_on_filter_pressed)

	var inventory_manager := _get_inventory_manager()
	if inventory_manager and inventory_manager.has_signal("inventory_changed"):
		if not inventory_manager.inventory_changed.is_connected(_on_inventory_changed):
			inventory_manager.inventory_changed.connect(_on_inventory_changed)

	_load_inventory_items()
	_select_category(&"all")


func _get_inventory_manager() -> Node:
	if game_manager and "inventory_manager" in game_manager:
		return game_manager.inventory_manager
	return null


# ── Вкладки ─────────────────────────────────────────────────────────────────

func _build_tabs() -> void:
	for child in _tabs.get_children():
		child.queue_free()
	_tab_buttons.clear()

	for category in CATEGORIES:
		var id: StringName = category["id"]
		var button := Button.new()
		button.name = String(id)
		button.text = String(category["label"])
		button.theme_type_variation = &"TabButton"
		button.toggle_mode = true
		button.button_group = _tab_group
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_category.bind(id))
		_tabs.add_child(button)
		_tab_buttons[id] = button


## D9 (замінює #4a): жодна вкладка не вимикається — порожня категорія, як-от KEY ITEMS,
## лишається в циклі FILTER і показує порожній стан замість того, щоб її пропускали.
func _refresh_tab_availability() -> void:
	for id in _tab_buttons:
		(_tab_buttons[id] as Button).disabled = false


func _select_category(id: StringName) -> void:
	var button: Button = _tab_buttons.get(id)
	if button and button.disabled:
		return
	_current_category = id
	# ButtonGroup сам не завжди знімає попередній toggle при програмній зміні,
	# через що старий таб лишався підсвіченим акцентом. Знімаємо явно.
	for tab_id in _tab_buttons:
		var tab: Button = _tab_buttons[tab_id]
		tab.set_pressed_no_signal(tab_id == id)
	_apply_filter()


func _category_types(id: StringName) -> Array:
	for category in CATEGORIES:
		if category["id"] == id:
			return category["types"]
	return []


# ── Завантаження та фільтрація ──────────────────────────────────────────────

## Читає вміст сумки. Джерело правди — InventoryManager, його не чіпаємо.
func _load_inventory_items() -> void:
	all_items.clear()
	if not game_manager or not item_database:
		return
	var inventory_manager := _get_inventory_manager()
	if not inventory_manager:
		return

	var items_dict: Dictionary = inventory_manager.get_items_dict()
	for item_id in items_dict:
		var count: int = items_dict[item_id]
		if count <= 0:
			continue
		var item_data: Dictionary = item_database.get_item(item_id)
		if item_data.is_empty():
			continue
		all_items.append(_make_entry(item_id, count, item_data))

	# Зілля показуємо завжди, навіть за нульової кількості — так було раніше.
	if not items_dict.has("potion"):
		var potion: Dictionary = item_database.get_item("potion")
		if not potion.is_empty():
			all_items.append(_make_entry("potion", inventory_manager.get_item_count("potion"), potion))


func _make_entry(item_id: String, count: int, item_data: Dictionary) -> Dictionary:
	return {
		"id": item_id,
		"name": item_database.get_item_name(item_id, "en"),
		"desc": item_database.get_item_description(item_id, "en"),
		"icon": item_database.get_item_icon(item_id),
		"count": count,
		"item_data": item_data,
	}


## Фільтр за типом через індекс ItemDatabase (items_by_type).
func _apply_filter() -> void:
	items.clear()
	var types := _category_types(_current_category)

	if types.is_empty():
		items = all_items.duplicate()
	else:
		var allowed := {}
		for type_name in types:
			for item_id in item_database.get_items_by_type(String(type_name)):
				allowed[item_id] = true
		for item in all_items:
			if allowed.has(item.get("id", "")):
				items.append(item)

	# У режимі вибору для слота лишаємо тільки те, що влізе в цей слот.
	if equipment_selection_mode and equipment_slot_id != "":
		_filter_by_equipment_slot(equipment_slot_id)

	_refresh_display()


# ── Відображення ────────────────────────────────────────────────────────────

func _refresh_display() -> void:
	# queue_free() звільняє вузол лише в кінці кадру, тому спершу від'єднуємо —
	# інакше get_child(0) нижче віддав би старий рядок.
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()
	_selected_index = -1

	var has_items := not items.is_empty()
	_list_scroll.visible = has_items
	_empty_label.visible = not has_items
	if not has_items:
		_empty_label.text = ("No items available for this slot."
				if equipment_selection_mode else "No items in this category.")
		# Порожня категорія не повинна показувати опис предмета з попередньої.
		if is_inside_tree():
			_clear_description()
		return

	for i in items.size():
		var row: UIItemRow = ITEM_ROW_SCENE.instantiate()
		_item_list.add_child(row)
		row.button_group = _row_group
		row.set_item(items[i], i)
		row.tooltip_text = _tooltip_for(items[i])
		row.row_selected.connect(_on_row_selected)
		row.row_activated.connect(_on_row_activated)

	# Перший рядок виділений за замовчуванням, як у Figma.
	var first := _item_list.get_child(0) as UIItemRow
	if first:
		first.set_pressed_no_signal(true)
		_selected_index = 0
		_publish_description(0)


## Опис предмета показуємо тултипом: у кадрі Figma окремої панелі деталей немає,
## але поведінку «побачити опис» втрачати не можна.
func _tooltip_for(item: Dictionary) -> String:
	var text := String(item.get("desc", ""))
	if equipment_selection_mode:
		text += "\n\nDouble-click or press Enter to equip"
	else:
		var slot_id := _get_slot_for_item(item)
		if slot_id != "":
			text += "\n\nDouble-click to equip in %s slot" % _get_slot_display_name(slot_id)
	return text


func update_display() -> void:
	# NOTIFICATION_VISIBILITY_CHANGED приходить ще до резолву @onready-вузлів,
	# тому без цієї перевірки _item_list тут може бути null.
	if not is_node_ready():
		return
	_load_inventory_items()
	_refresh_tab_availability()
	_apply_filter()


func _on_inventory_changed() -> void:
	if is_inside_tree() and visible:
		update_display()


## D9: кожне натискання FILTER перемикає на наступну категорію по колу:
## ALL → CONSUMABLES → MATERIALS → EQUIPMENT → KEY ITEMS → ALL. Без меню й спливаючих списків.
func _on_filter_pressed() -> void:
	var index := 0
	for i in CATEGORIES.size():
		if CATEGORIES[i]["id"] == _current_category:
			index = i
			break
	_select_category(CATEGORIES[(index + 1) % CATEGORIES.size()]["id"])


func _on_row_selected(index: int) -> void:
	_selected_index = index
	_publish_description(index)


## Опис вибраного предмета в нижню панель.
## Тултип працює лише під мишею, тому опис дублюється сюди — так він доступний
## і з клавіатури/геймпада (рядки отримують сигнал і з focus_entered).
func _publish_description(index: int) -> void:
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
	if bar == null or not bar.has_method("set_context_hint"):
		return
	if index < 0 or index >= items.size():
		bar.set_context_hint("")
		return
	var item: Dictionary = items[index]
	var text := String(item.get("desc", ""))
	bar.set_context_hint("%s — %s" % [String(item.get("name", "")), text] if text != "" else String(item.get("name", "")))


func _clear_description() -> void:
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
	if bar and bar.has_method("set_context_hint"):
		bar.set_context_hint("")


func _on_row_activated(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var item: Dictionary = items[index]
	if equipment_selection_mode:
		_equip_item(String(item.get("id", "")))
	else:
		_try_auto_equip(item)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		if visible:
			update_display()
		else:
			_clear_description()


# ── Режим вибору для екіпіровки (поведінка збережена без змін) ──────────────

func set_equipment_selection_mode(enabled: bool, slot_id: String = "", equipment_comp: Node = null) -> void:
	equipment_selection_mode = enabled
	equipment_slot_id = slot_id
	equipment_component = equipment_comp
	_select_category(&"all")


func _filter_by_equipment_slot(slot_id: String) -> void:
	var filtered: Array = []
	for item in items:
		if InventorySlotRules.fits(item.get("item_data", {}), slot_id):
			filtered.append(item)
	items = filtered


func _equip_item(item_id: String) -> void:
	if not equipment_selection_mode or equipment_slot_id == "":
		return
	if not game_manager or not item_database:
		return

	var item_data: Dictionary = item_database.get_item(item_id)
	if item_data.is_empty() or not InventorySlotRules.fits(item_data, equipment_slot_id):
		return

	# Пишемо через штатний API: EquipmentManager -> EventBus -> CharacterManager.
	# Той шлях сам оновлює бонуси й синхронізує player_state для збереження.
	var character = game_manager.get_active_character()
	var equipment_manager := _get_equipment_manager()
	if character == null or equipment_manager == null:
		return
	equipment_manager.equip_item(String(character.character_id), equipment_slot_id, item_id, item_data)

	emit_item_equipped(item_id, equipment_slot_id)

	var player: Node = game_manager.get_current_player()
	if player and player.has_method("apply_stats_from_game_manager"):
		player.apply_stats_from_game_manager()

	set_equipment_selection_mode(false)
	request_tab.emit("equipment")


func _get_equipment_manager() -> Node:
	var service_locator: Node = ServiceLocatorHelper.get_service_locator()
	if service_locator and service_locator.has_method("get_equipment_manager"):
		return service_locator.get_equipment_manager()
	return null


func _get_slot_for_item(item: Dictionary) -> String:
	var taken := false
	if game_manager and game_manager.player_state.get("equipment", {}).get("accessory_1") != null:
		taken = true
	return InventorySlotRules.default_slot(item.get("item_data", {}), taken)


func _get_slot_display_name(slot_id: String) -> String:
	match slot_id:
		"accessory_1", "accessory_2":
			return "Accessory"
		_:
			return slot_id.capitalize()


## Автоекіпірування подвійним кліком, коли відкрита вкладка Equipment.
func _try_auto_equip(item: Dictionary) -> void:
	if not game_manager or not item_database:
		return
	if not _is_equipment_tab_open():
		return
	var slot_id := _get_slot_for_item(item)
	var item_id := String(item.get("id", ""))
	if slot_id == "" or item_id == "":
		return

	var previous_mode := equipment_selection_mode
	var previous_slot := equipment_slot_id
	equipment_selection_mode = true
	equipment_slot_id = slot_id
	_equip_item(item_id)
	equipment_selection_mode = previous_mode
	equipment_slot_id = previous_slot


func _is_equipment_tab_open() -> bool:
	var game_menu := get_tree().get_first_node_in_group(&"game_menu")
	if not game_menu:
		return false
	var equipment := game_menu.find_child("EquipmentComponent", true, false)
	return equipment != null and equipment.visible
