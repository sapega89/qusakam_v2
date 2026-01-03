extends Resource
class_name Inventory

## Максимальный размер инвентаря (0 = без ограничений)
@export var max_size: int = 0

## Специальные предметы
@export var potions: int = 0
@export var coins: int = 0
@export var keys: int = 0

## Обычные предметы (item_id -> count)
var items: Dictionary = {}

## Сигналы (будут эмититься через InventoryManager)
# signal item_added(item_id: String, amount: int)
# signal item_removed(item_id: String, amount: int)
# signal inventory_changed()

## Добавить предмет
func add_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	
	# Специальные предметы
	match item_id:
		"potion":
			potions += amount
			return true
		"coin":
			coins += amount
			return true
		"key":
			keys += amount
			return true
	
	# Обычные предметы
	if not items.has(item_id):
		items[item_id] = 0
	
	items[item_id] += amount
	return true

## Удалить предмет
func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	
	# Специальные предметы
	match item_id:
		"potion":
			if potions < amount:
				return false
			potions -= amount
			return true
		"coin":
			if coins < amount:
				return false
			coins -= amount
			return true
		"key":
			if keys < amount:
				return false
			keys -= amount
			return true
	
	# Обычные предметы
	if not items.has(item_id) or items[item_id] < amount:
		return false
	
	items[item_id] -= amount
	if items[item_id] <= 0:
		items.erase(item_id)
	
	return true

## Получить количество предмета
func get_item_count(item_id: String) -> int:
	match item_id:
		"potion":
			return potions
		"coin":
			return coins
		"key":
			return keys
		_:
			return items.get(item_id, 0)

## Проверить наличие предмета
func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

## Получить все предметы как словарь (для совместимости)
func get_all_items() -> Dictionary:
	var result = {}
	if potions > 0:
		result["potion"] = potions
	if coins > 0:
		result["coin"] = coins
	if keys > 0:
		result["key"] = keys
	result.merge(items)
	return result

## Получить только обычные предметы (для совместимости с существующим кодом)
func get_items_dict() -> Dictionary:
	return items.duplicate()

## Очистить инвентарь
func clear():
	potions = 0
	coins = 0
	keys = 0
	items.clear()

## Установить количество предмета (для загрузки)
func set_item_count(item_id: String, count: int):
	if count < 0:
		count = 0
	
	match item_id:
		"potion":
			potions = count
		"coin":
			coins = count
		"key":
			keys = count
		_:
			if count > 0:
				items[item_id] = count
			else:
				items.erase(item_id)

## Создать инвентарь из словаря (для загрузки)
static func from_dict(data: Dictionary) -> Inventory:
	var inventory = Inventory.new()
	
	# Специальные предметы
	inventory.potions = data.get("potions", 0)
	inventory.coins = data.get("coins", 0)
	inventory.keys = data.get("keys", 0)
	
	# Обычные предметы
	if data.has("items") and data["items"] is Dictionary:
		inventory.items = data["items"].duplicate()
	
	return inventory

## Преобразовать в словарь (для сохранения)
func to_dict() -> Dictionary:
	return {
		"potions": potions,
		"coins": coins,
		"keys": keys,
		"items": items.duplicate()
	}

## Валидация инвентаря
func validate() -> bool:
	return potions >= 0 and coins >= 0 and keys >= 0

