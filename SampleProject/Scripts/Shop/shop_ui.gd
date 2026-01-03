extends Control

# 🛒 ShopUI - Merchant shop interface

# Сигнал закриття магазину
signal shop_closed

# Nodes References (Hardcoded paths from tscn)
@onready var base_menu: BaseMenu = $BaseMenu
@onready var item_info_tooltip: PanelContainer = $PanelContainer

# Content Containers
@onready var buy_content: VBoxContainer = $BaseMenu/HBoxContainer/CentralPanel/Panel/ContentContainer/BuyContent
@onready var sell_content: VBoxContainer = $BaseMenu/HBoxContainer/CentralPanel/Panel/ContentContainer/SellContent

# Tables (Table instances – специализированные списки)
@onready var buy_item_list: BuyItemListDisplay = $BaseMenu/HBoxContainer/CentralPanel/Panel/ContentContainer/BuyContent/ItemListDisplay
@onready var sell_item_list: SellItemListDisplay = $BaseMenu/HBoxContainer/CentralPanel/Panel/ContentContainer/SellContent/ItemListDisplay

# Buttons
@onready var buy_button: Button = $BaseMenu/HBoxContainer/CentralPanel/Panel/ContentContainer/VBoxContainer/Buy
@onready var sell_button: Button = $BaseMenu/HBoxContainer/CentralPanel/Panel/ContentContainer/VBoxContainer/Sell
@onready var equipment_button: Button = $BaseMenu/HBoxContainer/CentralPanel/Panel/ContentContainer/VBoxContainer/Blacksmith
@onready var exit_button: Button = $BaseMenu/HBoxContainer/CentralPanel/Panel/ContentContainer/VBoxContainer/Exit

# Logic Variables
var current_menu_mode: String = "" # Initialize empty to force switch on setup
var shop_items: Array = []
var current_transition_tween: Tween = null

# Dependencies
var item_database: Node
var game_manager: Node

# Hover Logic
var _tree_node: Tree = null
var _last_hovered_item_index: int = -1

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Dependencies
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator:
			if service_locator.has_method("get_item_database"):
				item_database = service_locator.get_item_database()
			if service_locator.has_method("get_game_manager"):
				game_manager = service_locator.get_game_manager()
	
	# Base Menu Setup
	if base_menu:
		if base_menu.has_method("set_menu_title"):
			base_menu.set_menu_title("Shop")
		if base_menu.has_method("set_menu_description"):
			base_menu.set_menu_description("Buy and sell items")
	
	# Force input pass-through for tooltip and overlays
	if item_info_tooltip:
		item_info_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Switch to default	
	# Подписываемся на двойной клик по строке таблицы (покупка / детали)
	if buy_item_list and not buy_item_list.row_double_clicked.is_connected(_on_buy_row_double_clicked):
		buy_item_list.row_double_clicked.connect(_on_buy_row_double_clicked)
	if sell_item_list and not sell_item_list.row_double_clicked.is_connected(_on_sell_row_double_clicked):
		sell_item_list.row_double_clicked.connect(_on_sell_row_double_clicked)
	
	# Test Mode check: If shop is empty, load default items
	if shop_items.is_empty():
		var test_items = _load_test_items()
		if not test_items.is_empty():
			setup_shop(test_items)

func _input(event):
	# FIX: Обрабатываем только нужные события (ui_cancel)
	if event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()

# --- Table Hover Logic (удалена из _input) ---
# Этот код больше не нужен, так как hover обрабатывается через signals

func _on_mouse_exit_table():
	if _last_hovered_item_index != -1:
		_last_hovered_item_index = -1
		if item_info_tooltip:
			item_info_tooltip.toggle(false)


func _switch_mode(new_mode: String):
	if current_menu_mode == new_mode: return
	
	var _old_mode = current_menu_mode
	current_menu_mode = new_mode
	
	# Наполняем соответствующую таблицу данными
	match new_mode:
		"buy":
			if buy_item_list:
				buy_item_list.show_shop_items(shop_items)
		"sell":
			if sell_item_list:
				sell_item_list.show_inventory_items()
		"equipment":
			# TODO: отдельный список экипировки, если понадобится
			pass
	
	_animate_transition()
	_update_menu_buttons()

func _animate_transition():
	# Анимация перехода между режимами временно отключена
	if current_transition_tween:
		current_transition_tween.kill()

func _on_buy_pressed(): _switch_mode("buy")
func _on_sell_pressed(): _switch_mode("sell")
func _on_blacksmith_pressed(): _switch_mode("equipment")
func _on_exit_pressed(): _animate_exit()

func close_shop():
	visible = false
	shop_closed.emit()
	if get_tree().current_scene == self: queue_free()

func setup_shop(items: Array):
	shop_items = items
	visible = true
	if base_menu: base_menu.visible = true
	_switch_mode("buy")
	if base_menu and base_menu.has_method("update_gold_display"):
		base_menu.update_gold_display()

func _update_menu_buttons():
	var active = Color.WHITE
	var inactive = Color(0.7, 0.7, 0.7)
	
	if buy_button: buy_button.modulate = active if current_menu_mode == "buy" else inactive
	if sell_button: sell_button.modulate = active if current_menu_mode == "sell" else inactive
	if equipment_button: equipment_button.modulate = active if current_menu_mode == "equipment" else inactive

func _animate_exit():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		close_shop()
		var parent = get_parent()
		if parent and parent is CanvasLayer: parent.queue_free()
	)

func _load_test_items() -> Array:
	# Load items from JSON
	var f = FileAccess.open("res://SampleProject/Resources/Data/merchants.json", FileAccess.READ)
	if not f: return []
	
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK: return []
	
	var d = j.data
	if not d or not d.has("merchants"): return []
	
	return d.merchants.default.items if d.merchants.has("default") else []

func _get_item_count(id):
	var inv = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_inventory_manager"):
			inv = service_locator.get_inventory_manager()
	return inv.get_item_count(id) if inv else 0

func _on_item_list_display_row_double_clicked(index: int) -> void:
	# Двойной клик по строке таблицы покупок (Buy)
	if current_menu_mode != "buy":
		return
	if not buy_item_list:
		return
	
	var item_ids: Array[String] = buy_item_list.get_meta("item_ids", [])
	if index < 0 or index >= item_ids.size():
		return
	
	var item_id := item_ids[index]
	if item_id == "" or item_id == null:
		return
	
	_buy_item_confirm(item_id)


func _buy_item_confirm(_item_id: String) -> void:
	_buy_item(_item_id)

func _on_buy_row_double_clicked(index: int) -> void:
	if current_menu_mode != "buy":
		return
	var item_ids: Array[String] = buy_item_list.get_meta("item_ids", [])
	if index < 0 or index >= item_ids.size():
		return
	var item_id := item_ids[index]
	if item_id == "" or item_id == null:
		return
	_buy_item(item_id)

func _on_sell_row_double_clicked(index: int) -> void:
	if current_menu_mode != "sell":
		return
	var item_ids: Array[String] = sell_item_list.get_meta("item_ids", [])
	if index < 0 or index >= item_ids.size():
		return
	var item_id := item_ids[index]
	if item_id == "" or item_id == null:
		return
	_sell_item(item_id)

func _buy_item(item_id: String) -> void:
	if item_database == null:
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_item_database"):
				item_database = service_locator.get_item_database()
	var inv = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_inventory_manager"):
			inv = service_locator.get_inventory_manager()
	if not inv or not item_database:
		return
	var item: Dictionary = item_database.get_item(item_id)
	if item.is_empty():
		return
	var price: int = int(item.get("buy_price", 0))
	if price <= 0:
		return
	if inv.get_item_count("coin") < price:
		print("🛒 ShopUI: Not enough coins to buy ", item_id, " price=", price)
		return
	if not inv.remove_item("coin", price):
		return
	inv.add_item(item_id, 1)
	print("🛒 ShopUI: Bought ", item_id, " for ", price, " coins")
	# Refresh UI
	if buy_item_list:
		buy_item_list.show_shop_items(shop_items)
	if sell_item_list:
		sell_item_list.show_inventory_items()
	if base_menu and base_menu.has_method("update_gold_display"):
		base_menu.update_gold_display()

func _sell_item(item_id: String) -> void:
	if item_database == null:
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_item_database"):
				item_database = service_locator.get_item_database()
	var inv = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_inventory_manager"):
			inv = service_locator.get_inventory_manager()
	if not inv or not item_database:
		return
	if inv.get_item_count(item_id) <= 0:
		return
	var item: Dictionary = item_database.get_item(item_id)
	if item.is_empty():
		return
	var price: int = int(item.get("sell_price", 0))
	if price <= 0:
		return
	if not inv.remove_item(item_id, 1):
		return
	inv.add_item("coin", price)
	print("🛒 ShopUI: Sold ", item_id, " for ", price, " coins")
	# Refresh UI
	if sell_item_list:
		sell_item_list.show_inventory_items()
	if buy_item_list:
		buy_item_list.show_shop_items(shop_items)
	if base_menu and base_menu.has_method("update_gold_display"):
		base_menu.update_gold_display()

