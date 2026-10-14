extends Node
class_name InventoryManager

## Инвентарь игрока. Монеты — це предмет "coin" в Inventory (один гаманець:
## раніше тут був окремий `coins`, який не зберігався й розходився з магазином і лутом).
var player_inventory: Inventory = Inventory.new()

## Сигналы
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal inventory_changed()

## Добавить предмет
func add_item(item_id: String, amount: int = 1) -> bool:
	var result = player_inventory.add_item(item_id, amount)
	if result:
		item_added.emit(item_id, amount)
		inventory_changed.emit()
		EventBus.item_added.emit(item_id, amount)
		EventBus.inventory_updated.emit()
		if item_id == "coin":
			EventBus.coins_changed.emit(get_coins())
	return result

## Удалить предмет
func remove_item(item_id: String, amount: int = 1) -> bool:
	var result = player_inventory.remove_item(item_id, amount)
	if result:
		item_removed.emit(item_id, amount)
		inventory_changed.emit()
		EventBus.item_removed.emit(item_id, amount)
		EventBus.inventory_updated.emit()
		if item_id == "coin":
			EventBus.coins_changed.emit(get_coins())
	return result

## Получить количество предмета
func get_item_count(item_id: String) -> int:
	return player_inventory.get_item_count(item_id)

## Очистить инвентарь
func clear():
	player_inventory.clear()
	inventory_changed.emit()

## Загрузить инвентарь из словаря
func load_from_dict(data: Dictionary):
	player_inventory = Inventory.from_dict(data)
	inventory_changed.emit()
	EventBus.coins_changed.emit(get_coins())

## Сохранить инвентарь в словарь
func save_to_dict() -> Dictionary:
	return player_inventory.to_dict()

## Усі предмети, включно з potion / coin / key
func get_all_items() -> Dictionary:
	return player_inventory.get_all_items()

## Лише звичайні предмети (без potion / coin / key)
func get_items_dict() -> Dictionary:
	return player_inventory.get_items_dict()

func add_coins(amount: int) -> void:
	add_item("coin", amount)

func get_coins() -> int:
	return get_item_count("coin")

func spend_coins(amount: int) -> bool:
	return remove_item("coin", amount)
