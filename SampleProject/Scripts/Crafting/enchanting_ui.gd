extends Control

# ✦ EnchantingUI — екран зачарування коваля (D94, D115, D163, D164). Каркас — як у крафту
# (design/enchanting_plan.md slice 2); Figma enchant-list не звірено — MCP був недоступний.
# Логіка — EnchantingService; стилі — GameUITheme.
#
# Рядок — лише те, що можна зачарувати зараз (≥2 однакових, нижче капу) → "Enchant X?" →
# зачарування; бракує золота → "Cannot Enchant".

signal closed

const ROW_SCENE := preload("res://SampleProject/UI/Components/shop_row.tscn")
const MODAL_TEMPLATES := preload("res://SampleProject/Scripts/UI/modal_templates.gd")
const SERVICE := preload("res://SampleProject/Scripts/Crafting/enchanting_service.gd")

const MenuNavKeys := preload("res://SampleProject/UI/Components/menu_nav_keys.gd")

@onready var base_menu: Control = $BaseMenu
@onready var _rows: VBoxContainer = %Rows
@onready var _empty: Label = %EmptyLabel
@onready var _desc_box: PanelContainer = %DescBox
@onready var _desc_name: Label = %DescName
@onready var _desc_text: Label = %DescText

var service = SERVICE.new()
var _focused_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	base_menu.set_menu_title("ENCHANT")
	%CountHeader.custom_minimum_size.x = UITokens.SHOP_COL_COUNT
	%PriceHeader.custom_minimum_size.x = UITokens.SHOP_COL_PRICE
	var bar = base_menu.get_node("BottomBar")
	bar.set_default_hint(tr("Two identical items make one a level higher."))
	bar.set_actions([
		{"action": &"ui_accept", "label": tr("Confirm")},
		{"action": &"ui_cancel", "label": tr("Back")},
	])
	refresh()


func _input(event: InputEvent) -> void:
	if _modal_open():
		return
	var by := MenuNavKeys.letter_step(event)
	if by != 0 and MenuNavKeys.has_focus_in(_rows):  # D721: W/S гортають рядки, як стрілки
		get_viewport().set_input_as_handled()
		MenuNavKeys.move_focus(_rows, by)
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


## Перебудовує рядки з інвентаря (після зачарування теж: кількості змінились).
func refresh() -> void:
	var rows: Array[Dictionary] = service.rows()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var focus_target: ShopRow = null
	for data in rows:
		var row: ShopRow = ROW_SCENE.instantiate()
		_rows.add_child(row)
		row.setup(data)
		row.row_focused.connect(_show_description)
		row.row_activated.connect(_try_enchant)
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


func _try_enchant(data: Dictionary) -> void:
	_focused_id = str(data.id)
	var R = SERVICE.Result
	match service.check(data.id):
		R.NOT_ENOUGH_GOLD:
			_show_modal(MODAL_TEMPLATES.cannot_enchant(
					tr("Not enough gold.") + "\n" + tr("You need %s.") % ShopService.format_price(data.price)))
		R.OK:
			_show_modal(MODAL_TEMPLATES.enchant_confirm(str(data.name), str(data.result_name),
					ShopService.format_price(data.price)), func(result: String):
						if result == "confirm":
							service.enchant(data.id)
							_focused_id = str(data.result_id))


func _show_modal(data: Dictionary, on_closed: Callable = Callable()) -> void:
	var ui = ServiceLocator.get_ui_manager()
	ui.show_modal(data)
	ui.get_modal_layer().modal_closed.connect(func(result: String):
		if on_closed.is_valid():
			on_closed.call(result)
		refresh(), CONNECT_ONE_SHOT)


func _modal_open() -> bool:
	return ServiceLocator.get_ui_manager().get_modal_layer().active_modal != null
