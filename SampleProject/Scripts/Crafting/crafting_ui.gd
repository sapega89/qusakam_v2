extends Control

# ⚒ CraftingUI — екран крафту коваля. Figma: crafting-list 160:1291, рецепт 164:2326,
# підтвердження 164:2545, помилка 164:2764. Мапінг: design/crafting_mapping.md.
# Логіка — CraftingService; стилі — GameUITheme; каркас — той самий, що в магазині.
#
# [CRAFT + таби станцій (D108)] [категорії результату | рецепти · опис] [панель партії (D101)]
# Рядок → панель рецепта → "Craft X?" → крафт, або "Cannot Craft". Q/E, LB/RB — станції.

signal closed

const ROW_SCENE := preload("res://SampleProject/UI/Components/shop_row.tscn")
const RECIPE_PANEL := preload("res://SampleProject/UI/Components/recipe_panel.tscn")
const MODAL_TEMPLATES := preload("res://SampleProject/Scripts/UI/modal_templates.gd")
const CHEVRON := preload("res://SampleProject/Assets/UI/Icons/chevron.svg")
const ICON_DIR := "res://SampleProject/Assets/UI/Icons/shop_cat_%s.svg"

@onready var base_menu: Control = $BaseMenu
@onready var _sidebar: Container = $BaseMenu/HBoxContainer/CentralPanel/Center/Sidebar
@onready var _categories: VBoxContainer = %Categories
@onready var _rows: VBoxContainer = %Rows
@onready var _empty: Label = %EmptyLabel
@onready var _desc_box: PanelContainer = %DescBox
@onready var _desc_name: Label = %DescName
@onready var _desc_text: Label = %DescText

var service := CraftingService.new()
var station_index: int = 0
var category_index: int = 0
var _station_tabs: Array[Button] = []
var _category_buttons: Array[Button] = []
var _focused_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	base_menu.set_menu_title("CRAFT")
	%CountHeader.custom_minimum_size.x = UITokens.SHOP_COL_COUNT
	%PriceHeader.custom_minimum_size.x = UITokens.SHOP_COL_PRICE
	_build_stations()
	_build_categories()
	var bar = base_menu.get_node("BottomBar")
	bar.set_default_hint(tr("Select a recipe."))
	bar.set_actions([
		{"key": "L/R", "label": tr("Switch Station")},
		{"key": "A", "label": tr("Confirm")},
		{"key": "B", "label": tr("Back")},
	])
	refresh()


func _build_stations() -> void:
	var group := ButtonGroup.new()
	for i in CraftingService.STATIONS.size():
		var tab := Button.new()
		tab.text = tr(CraftingService.STATIONS[i].label)
		tab.theme_type_variation = &"SidebarTab"
		tab.toggle_mode = true
		tab.button_group = group
		tab.icon = CHEVRON
		tab.expand_icon = true
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size.y = UITokens.SIDEBAR_TAB_HEIGHT
		tab.focus_mode = Control.FOCUS_NONE  # перемикання — Q/E, LB/RB або мишею
		tab.pressed.connect(_set_station.bind(i))
		_sidebar.add_child(tab)
		_station_tabs.append(tab)


func _build_categories() -> void:
	for i in ShopService.CATEGORIES.size():
		var cat: Dictionary = ShopService.CATEGORIES[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(UITokens.SHOP_CATEGORY_SIZE, UITokens.SHOP_CATEGORY_SIZE)
		b.text = cat.label
		b.tooltip_text = cat.buy_title
		if cat.icon != "":
			b.icon = load(ICON_DIR % cat.icon)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_category.bind(i))
		_categories.add_child(b)
		_category_buttons.append(b)


func _input(event: InputEvent) -> void:
	if _modal_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed(&"menu_prev_tab"):
		get_viewport().set_input_as_handled()
		_set_station(wrapi(station_index - 1, 0, CraftingService.STATIONS.size()))
	elif event.is_action_pressed(&"menu_next_tab"):
		get_viewport().set_input_as_handled()
		_set_station(wrapi(station_index + 1, 0, CraftingService.STATIONS.size()))


func _set_station(index: int) -> void:
	station_index = index
	refresh()


func _set_category(index: int) -> void:
	category_index = index
	refresh()


## Перебудовує рядки з поточних даних (після крафту теж: кількості й «на руках» змінились).
func refresh() -> void:
	for i in _station_tabs.size():
		_station_tabs[i].set_pressed_no_signal(i == station_index)
	for i in _category_buttons.size():
		_category_buttons[i].theme_type_variation = &"ShopCategoryOn" if i == category_index else &"ShopCategory"
	var rows: Array[Dictionary] = service.recipes(CraftingService.STATIONS[station_index].id, ShopService.CATEGORIES[category_index].id)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var focus_target: ShopRow = null
	for data in rows:
		var row: ShopRow = ROW_SCENE.instantiate()
		_rows.add_child(row)
		row.setup(data)
		row.row_focused.connect(_show_description)
		row.row_activated.connect(_open_recipe)
		if focus_target == null or data.id == _focused_id:
			focus_target = row
	_empty.visible = rows.is_empty()
	_desc_box.visible = not rows.is_empty()
	if focus_target:
		_focus_row.call_deferred(focus_target)


func _focus_row(row: ShopRow) -> void:
	if is_instance_valid(row) and row.is_inside_tree() and not row.is_queued_for_deletion():
		row.grab_focus()


func get_rows() -> Array[ShopRow]:
	var out: Array[ShopRow] = []
	for child in _rows.get_children():
		if child is ShopRow and not child.is_queued_for_deletion():
			out.append(child)
	return out


func _show_description(data: Dictionary) -> void:
	_focused_id = str(data.id)
	_desc_name.text = str(data.name)
	_desc_text.text = str(data.description)


## Рядок → панель рецепта (164:2326). Підтвердження в ній веде далі, Esc — назад до списку.
func _open_recipe(data: Dictionary) -> void:
	_focused_id = str(data.id)
	var layer = _modal_layer()
	layer.show_custom_modal(RECIPE_PANEL)
	layer.active_modal.show_recipe(data)
	layer.modal_closed.connect(func(result: String):
		if result == "confirm":
			_confirm_craft(service.row(data.id))
		else:
			refresh(), CONNECT_ONE_SHOT)


func _confirm_craft(data: Dictionary) -> void:
	match service.check(data.id):
		CraftingService.Result.NOT_ENOUGH_MATERIALS:
			var lacking: PackedStringArray = []
			for m in service.missing(data.id):
				lacking.append("%s ×%d" % [m.name, m.missing])
			_show_modal(MODAL_TEMPLATES.cannot_craft(
					tr("Not enough materials.") + "\n" + tr("You are missing: %s") % ", ".join(lacking)))
		CraftingService.Result.NOT_ENOUGH_GOLD:
			_show_modal(MODAL_TEMPLATES.cannot_craft(
					tr("Not enough gold.") + "\n" + tr("You need %s.") % ShopService.format_price(data.price)))
		CraftingService.Result.OK:
			var parts: PackedStringArray = []
			for m in data.materials:
				parts.append("%s ×%d" % [m.name, m.need])
			_show_modal(MODAL_TEMPLATES.craft_confirm(str(data.name), parts, ShopService.format_price(data.price)),
					func(result: String):
						if result == "confirm":
							service.craft(data.id))


func _show_modal(data: Dictionary, on_closed: Callable = Callable()) -> void:
	var ui = ServiceLocator.get_ui_manager()
	ui.show_modal(data)
	ui.get_modal_layer().modal_closed.connect(func(result: String):
		if on_closed.is_valid():
			on_closed.call(result)
		refresh(), CONNECT_ONE_SHOT)


func _modal_layer() -> Node:
	return ServiceLocator.get_ui_manager().get_modal_layer()


func _modal_open() -> bool:
	return _modal_layer().active_modal != null
