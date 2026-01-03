@tool
extends ItemListDisplay
class_name BuyItemListDisplay

var _item_database: Node = null

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

func _get_item_count(item_id: String) -> int:
	var inv = null
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_inventory_manager"):
			inv = service_locator.get_inventory_manager()
	return inv.get_item_count(item_id) if inv else 0

## Показывает товары магазина (режим BUY).
## shop_items — массив строковых id предметов.
func show_shop_items(shop_items: Array) -> void:
	if not _ensure_db():
		return
	
	var table_data: Array[Array] = []
	var item_ids: Array[String] = []
	
	for item_id in shop_items:
		var item: Dictionary = _item_database.get_item(item_id)
		if item.is_empty():
			continue
		
		var item_name: String = _item_database.get_item_name(item_id, "en")
		var price: int = int(item.get("buy_price", 0))
		var count: int = _get_item_count(item_id)
		
		table_data.append([item_name, str(count), "Ʉ " + str(price)])
		item_ids.append(item_id)
	
	set_meta("item_ids", item_ids)
	set_table(table_data)

