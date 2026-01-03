extends Control
class_name InventoryUI

@onready var item_list: ItemList = $Panel/HBoxContainer/ItemList
@onready var icon_rect: TextureRect = $Panel/HBoxContainer/VBoxContainer/TextureRect
@onready var name_label: Label = $Panel/HBoxContainer/VBoxContainer/Label
@onready var desc_label: RichTextLabel = $Panel/HBoxContainer/VBoxContainer/RichTextLabel

var items := []
var inventory_manager: InventoryManager = null
var item_database: ItemDatabase = null

func _ready() -> void:
	# Підключаємо обробку вводу
	set_process_input(true)
	
	# Знаходимо InventoryManager та ItemDatabase
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator:
			if service_locator.has_method("get_inventory_manager"):
				inventory_manager = service_locator.get_inventory_manager()
			if service_locator.has_method("get_item_database"):
				item_database = service_locator.get_item_database()
	
	# Підписуємося на події EventBus
	if Engine.has_singleton("EventBus"):
		EventBus.item_added.connect(_on_item_added)
		EventBus.item_removed.connect(_on_item_removed)
		EventBus.inventory_updated.connect(_on_inventory_updated)
	
	# Заповнюємо список предметів
	_refresh_item_list()
	
	# Вибираємо перший предмет
	if items.size() > 0:
		item_list.select(0)
		_update_info(0)
	
	# Підключаємо сигнал вибору
	if not item_list.item_selected.is_connected(_update_info):
		item_list.item_selected.connect(_update_info)

func _unhandled_input(event):
	# Перевіряємо натискання Escape для закриття інвентаря
	if event.is_action("ui_cancel") and event.pressed:  # Escape key
		close_inventory()

func _refresh_item_list() -> void:
	"""Оновлює список предметів з InventoryManager"""
	if not inventory_manager or not item_database:
		return
	
	items.clear()
	item_list.clear()
	
	# Отримуємо всі предмети з інвентаря
	var inventory = inventory_manager.get_inventory()
	if not inventory:
		return
	
	# Додаємо зілля
	var potion_count = inventory.potions
	if potion_count > 0:
		var potion_data = item_database.get_item("potion")
		if not potion_data.is_empty():
			items.append({
				"id": "potion",
				"name": item_database.get_item_name("potion", "en"),
				"desc": item_database.get_item_description("potion", "en"),
				"icon": item_database.get_item_icon("potion"),
				"count": potion_count
			})
	
	# Додаємо монети
	var coin_count = inventory.coins
	if coin_count > 0:
		var coin_data = item_database.get_item("coin")
		if not coin_data.is_empty():
			items.append({
				"id": "coin",
				"name": item_database.get_item_name("coin", "en"),
				"desc": item_database.get_item_description("coin", "en"),
				"icon": item_database.get_item_icon("coin"),
				"count": coin_count
			})
	
	# Додаємо інші предмети
	for item_id in inventory.items:
		var item_data = item_database.get_item(item_id)
		if not item_data.is_empty():
			var count = inventory.items[item_id]
			items.append({
				"id": item_id,
				"name": item_database.get_item_name(item_id, "en"),
				"desc": item_database.get_item_description(item_id, "en"),
				"icon": item_database.get_item_icon(item_id),
				"count": count
			})
	
	# Додаємо предмети до списку
	for item in items:
		item_list.add_item("%s x%d" % [item.name, item.count], item.icon)

func _update_info(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	
	var item = items[index]
	if icon_rect:
		icon_rect.texture = item.icon
	if name_label:
		name_label.text = item.name
	if desc_label:
		desc_label.text = item.desc

func _on_item_added(item_id: String, _quantity: int):
	"""Обробляє подію додавання предмета"""
	_refresh_item_list()

func _on_item_removed(item_id: String, _quantity: int):
	"""Обробляє подію видалення предмета"""
	_refresh_item_list()

func _on_inventory_updated():
	"""Обробляє подію оновлення інвентаря"""
	_refresh_item_list()

func close_inventory():
	# Закриваємо інвентар
	visible = false
	# Відновлюємо гру
	get_tree().paused = false

func _exit_tree() -> void:
	"""Відписується від всіх сигналів при видаленні вузла"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Відписується від всіх сигналів для запобігання витоків пам'яті"""
	if item_list and item_list.item_selected.is_connected(_update_info):
		item_list.item_selected.disconnect(_update_info)
	
	if Engine.has_singleton("EventBus"):
		if EventBus.item_added.is_connected(_on_item_added):
			EventBus.item_added.disconnect(_on_item_added)
		if EventBus.item_removed.is_connected(_on_item_removed):
			EventBus.item_removed.disconnect(_on_item_removed)
		if EventBus.inventory_updated.is_connected(_on_inventory_updated):
			EventBus.inventory_updated.disconnect(_on_inventory_updated)

