@tool
extends ItemListDisplay
class_name SellItemListDisplay

var _item_database: Node

func _ready() -> void:
	super._ready()
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_item_database"):
			_item_database = service_locator.get_item_database()

func _ensure_db() -> bool:
	if _item_database == null:
		if Engine.has_singleton("ServiceLocator"):
			var service_locator = Engine.get_singleton("ServiceLocator")
			if service_locator and service_locator.has_method("get_item_database"):
				_item_database = service_locator.get_item_database()
	return _item_database != null

## Показывает предметы из инвентаря игрока (режим SELL).
func show_inventory_items() -> void:
	if not _ensure_db():
		return
	
	var inventory = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_inventory_manager"):
			inventory = service_locator.get_inventory_manager()
	if inventory == null:
		return
	
	var table_data: Array[Array] = []
	var item_ids: Array[String] = []
	var items: Dictionary = inventory.get_all_items()
	var non_sellable: Array[String] = ["coin", "gold", "currency"]
	
	for item_id in items.keys():
		var count: int = items[item_id]
		if count <= 0:
			continue
		if item_id.to_lower() in non_sellable:
			continue
		
		var item: Dictionary = _item_database.get_item(item_id)
		if item.is_empty():
			continue
		
		var item_name: String = _item_database.get_item_name(item_id, "en")
		var price: int = int(item.get("sell_price", 0))
		
		table_data.append([item_name, str(count), "Ʉ " + str(price)])
		item_ids.append(item_id)
	
	set_meta("item_ids", item_ids)
	set_table(table_data)

