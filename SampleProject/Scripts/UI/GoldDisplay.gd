extends Control
class_name GoldDisplay

@onready var gold_label: Label = $HBoxContainer/GoldLabel

var current_gold: int = 0
var inventory_manager: InventoryManager = null

func _ready():
	# Знаходимо InventoryManager
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_inventory_manager"):
			inventory_manager = service_locator.get_inventory_manager()
	
	# Синхронізуємо з інвентарем
	if inventory_manager:
		current_gold = inventory_manager.get_item_count("coin")
		# Підключаємося до сигналів змін інвентаря
		if not inventory_manager.inventory_changed.is_connected(_on_inventory_changed):
			inventory_manager.inventory_changed.connect(_on_inventory_changed)
	
	# Підписуємося на події EventBus для автоматичного оновлення
	if Engine.has_singleton("EventBus"):
		EventBus.item_added.connect(_on_item_added)
		EventBus.item_removed.connect(_on_item_removed)
		EventBus.inventory_updated.connect(_on_inventory_updated)
	
	# Встановлюємо початкову кількість золота
	update_display()

func _on_inventory_changed():
	"""Оновлює відображення при зміні інвентаря"""
	if inventory_manager:
		current_gold = inventory_manager.get_item_count("coin")
		update_display()

func _on_item_added(item_id: String, _quantity: int):
	"""Обробляє подію додавання предмета через EventBus"""
	if item_id == "coin":
		update_display()

func _on_item_removed(item_id: String, _quantity: int):
	"""Обробляє подію видалення предмета через EventBus"""
	if item_id == "coin":
		update_display()

func _on_inventory_updated():
	"""Обробляє подію оновлення інвентаря через EventBus"""
	if inventory_manager:
		current_gold = inventory_manager.get_item_count("coin")
		update_display()

func set_gold(amount: int):
	"""Встановлює кількість золота"""
	current_gold = amount
	update_display()

func add_gold(amount: int):
	"""Додає золото"""
	current_gold += amount
	update_display()

func remove_gold(amount: int):
	"""Віднімає золото"""
	current_gold = max(0, current_gold - amount)
	update_display()

func get_gold() -> int:
	"""Повертає поточну кількість золота"""
	return current_gold

func update_display():
	"""Оновлює відображення кількості золота"""
	if gold_label:
		gold_label.text = str(current_gold)

func _exit_tree() -> void:
	"""Відписується від всіх сигналів при видаленні вузла"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Відписується від всіх сигналів для запобігання витоків пам'яті"""
	if inventory_manager and inventory_manager.inventory_changed.is_connected(_on_inventory_changed):
		inventory_manager.inventory_changed.disconnect(_on_inventory_changed)
	
	if Engine.has_singleton("EventBus"):
		if EventBus.item_added.is_connected(_on_item_added):
			EventBus.item_added.disconnect(_on_item_added)
		if EventBus.item_removed.is_connected(_on_item_removed):
			EventBus.item_removed.disconnect(_on_item_removed)
		if EventBus.inventory_updated.is_connected(_on_inventory_updated):
			EventBus.inventory_updated.disconnect(_on_inventory_updated)

