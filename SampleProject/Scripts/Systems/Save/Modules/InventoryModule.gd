extends SaveModule
class_name InventoryModule

## 🎒 InventoryModule - Сохранение инвентаря
## Управляет: предметы, монеты, зелья, экипировка

func _ready():
	module_name = "InventoryModule"

func save() -> Dictionary:
	var data: Dictionary = ServiceLocator.get_inventory_manager().save_to_dict()
	log_info("Inventory saved: %d items, %d coins, %d potions" % [data.items.size(), data.coins, data.potions])
	return data

func load_data(data: Dictionary) -> void:
	ServiceLocator.get_inventory_manager().load_from_dict(data)
	log_info("Inventory loaded: %d items, %d coins, %d potions" % [data.items.size(), data.coins, data.potions])
