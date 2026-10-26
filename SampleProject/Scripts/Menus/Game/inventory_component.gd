extends BaseMenuComponent

## 🎒 InventoryComponent — екран інвентарю.
## Figma: menu-inventory (46:193), UI/Inventory Center Panel (355:6423).
##
## Дані: InventoryManager (що є в сумці) + ItemDatabase (описи, іконки, індекси).
## Фільтрація спирається на готовий індекс ItemDatabase.items_by_type —
## власного індексу компонент не будує.
## Вкладки й рядки — копії шаблонів %Tab і %ItemRow зі сцени через RowFill (D117), стилі — з теми.

const RowFill = preload("res://SampleProject/UI/Components/ui_rows.gd")
const MODAL_TEMPLATES = preload("res://SampleProject/Scripts/UI/modal_templates.gd")
const InputGlyphs = preload("res://SampleProject/Scripts/UI/input_glyphs.gd")

## Категорії з Figma. `types` порожній ⇒ показуємо все.
## Порожня категорія (напр. KEY ITEMS) лишається доступною й показує порожній стан (D9).
const CATEGORIES: Array[Dictionary] = [
	{"id": &"all", "label": "ALL", "types": []},
	{"id": &"consumables", "label": "CONSUMABLES", "types": ["consumable"]},
	{"id": &"materials", "label": "MATERIALS", "types": ["material"]},
	{"id": &"equipment", "label": "WEAPONS", "types": ["weapon", "armor"]},  # D493: підпис з Figma
	{"id": &"key_items", "label": "KEY ITEMS", "types": ["key_item"]},
]

@onready var _tabs: HBoxContainer = %Tabs
@onready var _filter_button: Button = %FilterButton
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _item_list: VBoxContainer = %ItemList
@onready var _item_row: UIItemRow = %ItemRow
@onready var _tab: Button = %Tab
@onready var _empty_label: Label = %EmptyLabel

var items: Array = []       # відфільтровані, у порядку показу
var all_items: Array = []   # усе, що є в інвентарі

var _current_category: StringName = &"all"
var _tab_buttons: Dictionary = {}       # StringName -> Button
var _tab_group := ButtonGroup.new()
var _row_group := ButtonGroup.new()
var _selected_index: int = -1
## Рядки, вже під'єднані (duplicate() копіює meta, тож не за meta-прапорцем).
var _wired: Dictionary = {}


func _initialize_component() -> void:
	_build_tabs()
	_filter_button.pressed.connect(_on_filter_pressed)

	var inventory_manager := _get_inventory_manager()
	if not inventory_manager.inventory_changed.is_connected(_on_inventory_changed):
		inventory_manager.inventory_changed.connect(_on_inventory_changed)
	# Вдягнули / зняли — знак «Equipped» на рядку міняється одразу (D720).
	if not EventBus.equipment_equipped.is_connected(_on_equipment_changed):
		EventBus.equipment_equipped.connect(_on_equipment_changed)
		EventBus.equipment_unequipped.connect(_on_equipment_changed)

	_load_inventory_items()
	_select_category(&"all")


func _get_inventory_manager() -> Node:
	return game_manager.inventory_manager


# ── Вкладки ─────────────────────────────────────────────────────────────────

func _build_tabs() -> void:
	_tab_buttons.clear()
	var buttons := RowFill.fill(_tabs, _tab, CATEGORIES.size())
	for i in buttons.size():
		var id: StringName = CATEGORIES[i]["id"]
		var button: Button = buttons[i]
		button.name = String(id)
		button.text = String(CATEGORIES[i]["label"])
		button.button_group = _tab_group
		button.pressed.connect(_select_category.bind(id))
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

	# Зілля лежать в Inventory.potions, а не в items_dict — додаємо окремо,
	# і лише поки вони є: випите останнє зникає зі списку.
	var potion_count: int = inventory_manager.get_item_count("potion")
	if not items_dict.has("potion") and potion_count > 0:
		var potion: Dictionary = item_database.get_item("potion")
		if not potion.is_empty():
			all_items.append(_make_entry("potion", potion_count, potion))


func _make_entry(item_id: String, count: int, item_data: Dictionary) -> Dictionary:
	return {
		"id": item_id,
		"name": item_database.get_item_name(item_id),
		"desc": item_database.get_item_description(item_id),
		"icon": item_database.get_item_icon(item_id),
		"count": count,
		"item_data": item_data,
		"equipped_slot": _equipped_slot(item_id),
	}


## Слот, у якому цей предмет зараз на герої, або "" (D720). Предмет лишається в сумці й вдягнений.
func _equipped_slot(item_id: String) -> String:
	var equipment: Dictionary = game_manager.player_state.get("equipment", {})
	for slot_id in equipment:
		var worn = equipment[slot_id]
		if worn is Dictionary and String(worn.get("id", "")) == item_id:
			return String(slot_id)
	return ""


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
			# Індекс знає лише базові id; "iron_dagger+2" фільтрується як iron_dagger (D163).
			if allowed.has(item_database.base_id(item.get("id", ""))):
				items.append(item)

	_refresh_display()


# ── Відображення ────────────────────────────────────────────────────────────

func _refresh_display() -> void:
	# RowFill від'єднує зайві рядки одразу (не лише queue_free) — get_child(i) віддає живий рядок.
	var rows := RowFill.fill(_item_list, _item_row, items.size())
	_selected_index = -1

	var has_items := not items.is_empty()
	_list_scroll.visible = has_items
	_empty_label.visible = not has_items
	if not has_items:
		_empty_label.text = "No items in this category."
		# Порожня категорія не повинна показувати опис предмета з попередньої.
		if is_inside_tree():
			_clear_description()
		return

	for i in rows.size():
		var row: UIItemRow = rows[i]
		row.button_group = _row_group
		row.set_item(items[i], i)
		row.tooltip_text = _tooltip_for(items[i])
		if not _wired.has(row):
			_wired[row] = true
			row.row_selected.connect(_on_row_selected)
			row.row_activated.connect(_on_row_activated)

	# Перший рядок виділений за замовчуванням, як у Figma.
	_select_row(0)


func _select_row(index: int) -> void:
	_selected_index = clampi(index, 0, items.size() - 1)
	# set_pressed_no_signal повз ButtonGroup — інші рядки знімаємо самі.
	for i in items.size():
		(_item_list.get_child(i) as UIItemRow).set_pressed_no_signal(i == _selected_index)
	_publish_description(_selected_index)


## Опис предмета показуємо тултипом: у кадрі Figma окремої панелі деталей немає,
## але поведінку «побачити опис» втрачати не можна.
func _tooltip_for(item: Dictionary) -> String:
	return String(item.get("desc", "")) + "

" + _use_hint(item)


## Що зробить подвійний клік / Enter на предметі (D286). Зілля HP п'ють лише в грі, зі швидкого слота (D504).
func _use_hint(item: Dictionary) -> String:
	if _is_potion(item):
		return tr("Drink it in play with the quick slot (%s)") % InputGlyphs.label(&"quick_potion")
	if _heal_amount(item) > 0:
		return "Double-click or Enter to use"
	if String(item.get("equipped_slot", "")) != "":
		return tr("Equipped — double-click or Enter to unequip (%s)") % _get_slot_display_name(item.equipped_slot)
	var slot_id := _get_slot_for_item(item)
	if slot_id != "":
		return tr("Double-click or Enter to equip (%s)") % _get_slot_display_name(slot_id)
	return "Cannot be used"


func update_display() -> void:
	# NOTIFICATION_VISIBILITY_CHANGED приходить ще до резолву @onready-вузлів,
	# тому без цієї перевірки _item_list тут може бути null.
	if not is_node_ready():
		return
	_load_inventory_items()
	_refresh_tab_availability()
	_apply_filter()


func _on_equipment_changed(_character_id: String, _slot_id: String, _item_id: String = "") -> void:
	_on_inventory_changed()


## Зміна сумки (випите зілля) — виділення лишається на тому ж місці, а не стрибає на перший рядок.
func _on_inventory_changed() -> void:
	if is_inside_tree() and visible:
		var keep := _selected_index
		update_display()
		if not items.is_empty():
			_select_row(keep)


## D9: кожне натискання FILTER перемикає на наступну категорію по колу:
## ALL → CONSUMABLES → MATERIALS → WEAPONS → KEY ITEMS → ALL. Без меню й спливаючих списків.
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
	if index < 0 or index >= items.size():
		bar.set_context_hint("")
		return
	var item: Dictionary = items[index]
	var text := String(item.get("desc", ""))
	bar.set_context_hint("%s — %s" % [String(item.get("name", "")), text] if text != "" else String(item.get("name", "")))


func _clear_description() -> void:
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
	bar.set_context_hint("")


## Double click / Enter / pad A on a row — use the item (D286, replaces D127's target choice).
func _on_row_activated(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var item: Dictionary = items[index]
	if _is_potion(item):
		_set_bar_hint(_use_hint(item))
	elif _heal_amount(item) > 0:
		_drink(item)
	elif String(item.get("equipped_slot", "")) != "":
		_unequip(item)  # D720: вдягнений — зняти, а не вдягати вдруге
	elif _get_slot_for_item(item) != "":
		_equip(item)
	else:
		ServiceLocator.get_ui_manager().show_modal(MODAL_TEMPLATES.cannot_use(String(item.get("name", ""))))
		ServiceLocator.get_ui_manager().get_modal_layer().modal_closed.connect(
				func(_r: String) -> void: _focus_selected_row(), CONNECT_ONE_SHOT)


func _effect(item: Dictionary) -> Dictionary:
	return item.get("item_data", {}).get("effect", {})


## Зілля HP (effect heal) — не в меню на паузі, а в реальному часі (D504, Player.drink_potion).
func _is_potion(item: Dictionary) -> bool:
	return _effect(item).get("type", "") == "heal"


func _heal_amount(item: Dictionary) -> int:
	return int(_effect(item).get("value", 0)) if _effect(item).get("type", "") in ["heal", "mana"] else 0


## Ефір (SP) діє на героя одразу — без вибору, кому, і без підтвердження (D286); зілля HP сюди не доходить (D504).
func _drink(item: Dictionary) -> void:
	var hero_name := String(game_manager.get_active_character().name)
	var sm: SkillManager = ServiceLocator.get_skill_manager()
	if sm.get_current_sp() >= sm.get_max_sp():
		_set_bar_hint(tr("%s's SP is already full.") % hero_name)
		return
	sm.restore_sp(_heal_amount(item))
	_get_inventory_manager().remove_item(String(item.get("id", "")), 1)
	_focus_selected_row()
	# Після фокуса: рядок у фокусі публікує свій опис, підсумок має лягти поверх.
	_set_bar_hint.call_deferred("%s — %s %d / %d." % [String(item.get("name", "")), "SP", sm.get_current_sp(), sm.get_max_sp()])


## Зброя, броня, прикраса — у свій слот через штатний API (EquipmentManager → EventBus → CharacterManager).
func _equip(item: Dictionary) -> void:
	var slot_id := _get_slot_for_item(item)
	var character = game_manager.get_active_character()
	_get_equipment_manager().equip_item(String(character.character_id), slot_id,
			String(item.get("id", "")), item.get("item_data", {}))
	emit_item_equipped(String(item.get("id", "")), slot_id)
	_focus_selected_row()
	_set_bar_hint.call_deferred(tr("%s equipped — %s.") % [String(item.get("name", "")), _get_slot_display_name(slot_id)])


## Вдягнений предмет — знімаємо тим самим штатним API (EquipmentManager → EventBus → CharacterManager), D720.
func _unequip(item: Dictionary) -> void:
	var slot_id := String(item.equipped_slot)
	var character = game_manager.get_active_character()
	_get_equipment_manager().unequip_item(String(character.character_id), slot_id)
	_focus_selected_row()
	_set_bar_hint.call_deferred(tr("%s unequipped — %s.") % [String(item.get("name", "")), _get_slot_display_name(slot_id)])


func _focus_selected_row() -> void:
	var index := maxi(_selected_index, 0)
	if index < items.size():
		(_item_list.get_child(index) as Control).grab_focus.call_deferred()


func _set_bar_hint(text: String) -> void:
	var bar: Node = get_tree().get_first_node_in_group(&"ui_bottom_bar")
	bar.set_context_hint(text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		if visible:
			update_display()
		else:
			_clear_description()


func _get_equipment_manager() -> Node:
	return ServiceLocator.get_equipment_manager()


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
