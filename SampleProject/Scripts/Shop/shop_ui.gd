extends Control

# 🛒 ShopUI — екран магазину. Figma: shop-buy 153:1289, shop-sell 153:1523,
# shop-buy-confirm 153:1760. Логіка — ShopService; стилі — лише GameUITheme.
#
# [SHOP + таби Buy/Sell] [категорії 64px | заголовок · шапка колонок · рядки · опис]
# [панель партії] · нижня панель підказок.
#
# BUY: рядок → "Buy X?" (Quantity · Total Cost) → купівля. SELL: рядок → продаж одразу
# (у Figma немає підтвердження продажу). Q/E або LB/RB — перемикання категорій.

signal shop_closed

const ROW_SCENE := preload("res://SampleProject/UI/Components/shop_row.tscn")
const MODAL_TEMPLATES := preload("res://SampleProject/Scripts/UI/modal_templates.gd")
const ICON_DIR := "res://SampleProject/Assets/UI/Icons/shop_cat_%s.svg"

@onready var base_menu: Control = $BaseMenu
@onready var _buy_tab: Button = %BuyTab
@onready var _sell_tab: Button = %SellTab
@onready var _categories: VBoxContainer = %Categories
@onready var _title: Label = %Title
@onready var _price_header: Label = %PriceHeader
@onready var _rows: VBoxContainer = %Rows
@onready var _empty: Label = %EmptyLabel
@onready var _desc_box: PanelContainer = %DescBox
@onready var _desc_name: Label = %DescName
@onready var _desc_text: Label = %DescText

var service := ShopService.new()
var shop_items: Array = []
var current_menu_mode: String = "buy"
var category_index: int = 0
var _category_buttons: Array[Button] = []
var _focused_id: String = ""


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if base_menu.has_method("set_menu_title"):
		base_menu.set_menu_title("SHOP")
	%TopSpacer.custom_minimum_size.y = UITokens.SIDEBAR_TOP_PAD
	%Tabs.custom_minimum_size.x = UITokens.SIDEBAR_TAB_WIDTH
	for tab in [_buy_tab, _sell_tab]:
		tab.custom_minimum_size.y = UITokens.SIDEBAR_TAB_HEIGHT
	%CountHeader.custom_minimum_size.x = UITokens.SHOP_COL_COUNT
	_price_header.custom_minimum_size.x = UITokens.SHOP_COL_PRICE
	%HeaderEnd.custom_minimum_size.x = UITokens.SHOP_ROW_PAD_H
	_buy_tab.pressed.connect(_switch_mode.bind("buy"))
	_sell_tab.pressed.connect(_switch_mode.bind("sell"))
	_build_categories()
	_setup_bottom_bar()
	_apply_mode()


func setup_shop(items: Array):
	shop_items = items
	visible = true
	if base_menu:
		base_menu.visible = true
	_switch_mode("buy")


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
		b.focus_mode = Control.FOCUS_NONE  # перемикання — Q/E, LB/RB або мишею
		b.pressed.connect(_set_category.bind(i))
		_categories.add_child(b)
		_category_buttons.append(b)


func _setup_bottom_bar() -> void:
	var bar = base_menu.get_node_or_null("BottomBar")
	if bar and bar.has_method("set_actions"):
		bar.set_default_hint(tr("Select an item."))
		bar.set_actions([
			{"key": "L/R", "label": tr("Switch Category")},
			{"key": "A", "label": tr("Confirm")},
			{"key": "B", "label": tr("Back")},
		])


func _input(event):
	if _modal_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_animate_exit()
	elif event.is_action_pressed(&"menu_prev_tab"):
		get_viewport().set_input_as_handled()
		_set_category(wrapi(category_index - 1, 0, ShopService.CATEGORIES.size()))
	elif event.is_action_pressed(&"menu_next_tab"):
		get_viewport().set_input_as_handled()
		_set_category(wrapi(category_index + 1, 0, ShopService.CATEGORIES.size()))


func _switch_mode(new_mode: String):
	current_menu_mode = new_mode
	_apply_mode()


func _set_category(index: int) -> void:
	category_index = index
	_apply_mode()


func _apply_mode() -> void:
	var buying := current_menu_mode == "buy"
	_buy_tab.set_pressed_no_signal(buying)
	_sell_tab.set_pressed_no_signal(not buying)
	var cat: Dictionary = ShopService.CATEGORIES[category_index]
	_title.text = tr(cat.buy_title if buying else cat.sell_title)
	# Figma: у BUY колонка — ціна торговця, у SELL — ціна викупу.
	_price_header.text = tr("Selling Price") if buying else tr("Buying Price")
	for i in _category_buttons.size():
		_category_buttons[i].theme_type_variation = &"ShopCategoryOn" if i == category_index else &"ShopCategory"
	refresh()


## Перебудовує рядки з поточних даних (після купівлі/продажу теж).
func refresh() -> void:
	var cat: StringName = ShopService.CATEGORIES[category_index].id
	var rows: Array[Dictionary] = service.wares(shop_items, cat) if current_menu_mode == "buy" \
			else service.possessions(cat)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var focus_target: ShopRow = null
	for data in rows:
		var row: ShopRow = ROW_SCENE.instantiate()
		_rows.add_child(row)
		row.setup(data, int(data.price) > 0)
		row.row_focused.connect(_show_description)
		row.row_activated.connect(_on_row_activated)
		if focus_target == null and row.focus_mode != Control.FOCUS_NONE:
			focus_target = row
		if data.id == _focused_id and row.focus_mode != Control.FOCUS_NONE:
			focus_target = row
	_empty.visible = rows.is_empty()
	_empty.text = tr("No wares in this category.") if current_menu_mode == "buy" \
			else tr("You have nothing to sell here.")
	_desc_box.visible = not rows.is_empty()
	if focus_target:
		_focus_row.call_deferred(focus_target)
	elif not rows.is_empty():
		_show_description(rows[0])


## Відкладений фокус: рядок міг зникнути, якщо refresh() спрацював двічі за кадр.
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
	_focused_id = str(data.get("id", ""))
	_desc_name.text = str(data.get("name", ""))
	_desc_text.text = str(data.get("description", ""))


func _on_row_activated(data: Dictionary) -> void:
	_focused_id = str(data.id)
	if current_menu_mode == "sell":
		service.sell(data.id)
		refresh()
		return
	var price := int(data.price)
	if service.gold() < price:
		_show_modal(MODAL_TEMPLATES.misc_popup(tr("Not Enough Gold"),
				tr("You need %s to buy %s.") % [ShopService.format_price(price), data.name]),
				func(_r): refresh())
		return
	_show_modal(MODAL_TEMPLATES.buy_confirm(str(data.name), 1, ShopService.format_price(price)),
			func(result: String):
				if result == "confirm":
					service.buy(data.id, 1)
				refresh())


func _show_modal(data: Dictionary, on_closed: Callable) -> void:
	var ui = ServiceLocatorHelper.get_manager("get_ui_manager")
	var layer = ui.get_modal_layer() if ui and ui.has_method("get_modal_layer") else null
	if ui == null or layer == null:
		on_closed.call("confirm")
		return
	ui.show_modal(data)
	layer.modal_closed.connect(on_closed, CONNECT_ONE_SHOT)


func _modal_open() -> bool:
	var ui = ServiceLocatorHelper.get_manager("get_ui_manager")
	var layer = ui.get_modal_layer() if ui and ui.has_method("get_modal_layer") else null
	return layer != null and layer.get("active_modal") != null


func close_shop():
	visible = false
	shop_closed.emit()
	if get_tree().current_scene == self:
		queue_free()


func _animate_exit():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		close_shop()
		var parent = get_parent()
		if parent and parent is CanvasLayer: parent.queue_free()
	)
