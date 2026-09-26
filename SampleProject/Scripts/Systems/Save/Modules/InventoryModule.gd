extends SaveModule
class_name InventoryModule

## 🎒 InventoryModule - Сохранение инвентаря
## Управляет: предметы, монеты, зелья, экипировка

func _ready():
	module_name = "InventoryModule"

## Сохраняет данные инвентаря
func save() -> Dictionary:
	var data = {
		"potions": 0,
		"coins": 0,
		"keys": 0,
		"items": []
	}

	# Получаем GameManager через ServiceLocator
	var game_manager = _get_game_manager()
	if not game_manager:
		log_error("GameManager not found, cannot save inventory")
		return data

	# Сохраняем инвентарь через InventoryManager
	if "inventory_manager" in game_manager and game_manager.inventory_manager:
		data = game_manager.inventory_manager.save_to_dict()
		log_info("Inventory saved: %d items, %d coins, %d potions" % [data.get("items", []).size(), data.get("coins", 0), data.get("potions", 0)])
	else:
		log_warning("InventoryManager not found, saving empty inventory")

	return data

## Загружает данные инвентаря
func load_data(data: Dictionary) -> void:
	if not validate_data(data):
		log_error("Invalid inventory data")
		return

	# Получаем GameManager через ServiceLocator
	var game_manager = _get_game_manager()
	if not game_manager:
		log_error("GameManager not found, cannot load inventory")
		return

	# Загружаем инвентарь через InventoryManager
	if "inventory_manager" in game_manager and game_manager.inventory_manager:
		game_manager.inventory_manager.load_from_dict(data)

		# Для обратной совместимости с старым кодом
		if game_manager.has_method("_sync_inventory_dict"):
			game_manager._sync_inventory_dict()

		log_info("Inventory loaded: %d items, %d coins, %d potions" % [data.get("items", []).size(), data.get("coins", 0), data.get("potions", 0)])
	else:
		log_warning("InventoryManager not found, cannot load inventory")

## Возвращает данные без сохранения
func get_data() -> Dictionary:
	return save()

## Устанавливает данные без загрузки из файла
func set_data(data: Dictionary) -> void:
	load_data(data)

## Получает GameManager через ServiceLocator
func _get_game_manager():
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_game_manager"):
			return service_locator.get_game_manager()
	return null

## Валидация данных
func validate_data(data: Dictionary) -> bool:
	if not super.validate_data(data):
		return false

	# Инвентарь может быть пустым - это нормально
	# Просто проверяем что это Dictionary
	return true
