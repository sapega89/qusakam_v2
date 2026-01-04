extends Node
class_name InventoryManager

## Инвентарь игрока
var player_inventory: Inventory

## Монеты игрока
var coins: int = 0

## Сигналы
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal inventory_changed()

func _ready():
	# Инициализация инвентаря
	if not player_inventory:
		player_inventory = Inventory.new()

## Добавить предмет
func add_item(item_id: String, amount: int = 1) -> bool:
	if not player_inventory:
		return false
	
	var result = player_inventory.add_item(item_id, amount)
	if result:
		item_added.emit(item_id, amount)
		inventory_changed.emit()
		
		# Емітуємо подію через EventBus
		if Engine.has_singleton("EventBus"):
			EventBus.item_added.emit(item_id, amount)
			EventBus.inventory_updated.emit()
	
	return result

## Удалить предмет
func remove_item(item_id: String, amount: int = 1) -> bool:
	if not player_inventory:
		return false
	
	var result = player_inventory.remove_item(item_id, amount)
	if result:
		item_removed.emit(item_id, amount)
		inventory_changed.emit()
		
		# Емітуємо подію через EventBus (quantity = amount для сумісності)
		if Engine.has_singleton("EventBus"):
			EventBus.item_removed.emit(item_id, amount)  # quantity = amount
			EventBus.inventory_updated.emit()
	
	return result

## Получить количество предмета
func get_item_count(item_id: String) -> int:
	if not player_inventory:
		return 0
	return player_inventory.get_item_count(item_id)

## Проверить наличие предмета
func has_item(item_id: String, amount: int = 1) -> bool:
	if not player_inventory:
		return false
	return player_inventory.has_item(item_id, amount)

## Получить инвентарь
func get_inventory() -> Inventory:
	return player_inventory

## Установить инвентарь
func set_inventory(inventory: Inventory):
	player_inventory = inventory
	inventory_changed.emit()

## Очистить инвентарь
func clear():
	if player_inventory:
		player_inventory.clear()
		inventory_changed.emit()

## Загрузить инвентарь из словаря
func load_from_dict(data: Dictionary):
	player_inventory = Inventory.from_dict(data)
	inventory_changed.emit()

## Сохранить инвентарь в словарь
func save_to_dict() -> Dictionary:
	if not player_inventory:
		return {}
	return player_inventory.to_dict()

## Получить все предметы (для совместимости)
func get_all_items() -> Dictionary:
	if not player_inventory:
		return {}
	return player_inventory.get_all_items()

## Получить словарь обычных предметов (для совместимости)
func get_items_dict() -> Dictionary:
	if not player_inventory:
		return {}
	return player_inventory.get_items_dict()

## Добавить монеты
func add_coins(amount: int) -> void:
	if amount < 0:
		amount = 0
	coins += amount
	EventBus.coins_changed.emit(coins)
	DebugLogger.info("InventoryManager: Added %d coins, total: %d" % [amount, coins], "Inventory")

## Получить количество монет
func get_coins() -> int:
	return coins

## Потратить монеты
func spend_coins(amount: int) -> bool:
	if amount < 0:
		return false # Cannot spend negative amount
	if coins >= amount:
		coins -= amount
		EventBus.coins_changed.emit(coins)
		DebugLogger.info("InventoryManager: Spent %d coins, remaining: %d" % [amount, coins], "Inventory")
		return true
	return false

