extends RefCounted
class_name ShopService

## Логіка магазину без UI: списки товарів, категорії, купівля, продаж.
## Джерела даних — лише ItemDatabase (ціни, назви, описи) та InventoryManager.
## Золото = кількість предмета "coin" в інвентарі (так само рахує GOLD у меню).
##
## Раніше shop_ui.gd шукав ці менеджери через Engine.has_singleton("ServiceLocator") —
## для autoload це завжди false, тож купівля й продаж ніколи не працювали.

enum Result { OK, NOT_ENOUGH_GOLD, UNAVAILABLE, NOT_OWNED }

const GOLD_ITEM := "coin"

## Figma shop-buy: колонка категорій (ALL, меч, щит, шолом, дзвоник, сувій).
## Відповідність даним ItemDatabase — типове рішення Q16.
const CATEGORIES := [
	{"id": &"all", "label": "ALL", "icon": "", "buy_title": "All Wares", "sell_title": "All Possessions"},
	{"id": &"weapons", "label": "", "icon": "sword", "buy_title": "Weapons", "sell_title": "Weapons"},
	{"id": &"shields", "label": "", "icon": "shield", "buy_title": "Shields", "sell_title": "Shields"},
	{"id": &"armor", "label": "", "icon": "armor", "buy_title": "Armor", "sell_title": "Armor"},
	{"id": &"accessories", "label": "", "icon": "accessory", "buy_title": "Accessories", "sell_title": "Accessories"},
	{"id": &"items", "label": "", "icon": "scroll", "buy_title": "Items", "sell_title": "Items"},
]


static func matches_category(item: Dictionary, category: StringName) -> bool:
	var type := str(item.get("type", ""))
	var cat := str(item.get("category", ""))
	match category:
		&"all":
			return true
		&"weapons":
			return type == "weapon"
		&"shields":
			return cat == "shield"
		&"armor":
			return type == "armor" and cat != "shield"
		&"accessories":
			return type == "accessory"
		&"items":
			return type in ["consumable", "heal", "mana", "material"]
	return false


func _db() -> Node:
	return ServiceLocatorHelper.get_manager("get_item_database")


func _inventory() -> Node:
	return ServiceLocatorHelper.get_manager("get_inventory_manager")


func is_ready() -> bool:
	return _db() != null and _inventory() != null


func gold() -> int:
	var inv := _inventory()
	return inv.get_item_count(GOLD_ITEM) if inv else 0


func owned(item_id: String) -> int:
	var inv := _inventory()
	return inv.get_item_count(item_id) if inv else 0


## Рядки для режиму BUY: товари торговця з цінами buy_price.
func wares(item_ids: Array, category: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var db := _db()
	if db == null:
		return out
	for id in item_ids:
		var item: Dictionary = db.get_item(str(id))
		if item.is_empty() or int(item.get("buy_price", 0)) <= 0:
			continue
		if matches_category(item, category):
			out.append(_row(str(id), item, int(item.buy_price)))
	return out


## Рядки для режиму SELL: предмети гравця (крім золота) з цінами sell_price.
func possessions(category: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var db := _db()
	var inv := _inventory()
	if db == null or inv == null:
		return out
	for id in _owned_ids(inv):
		if id == GOLD_ITEM:
			continue
		var item: Dictionary = db.get_item(id)
		if item.is_empty() or not matches_category(item, category):
			continue
		out.append(_row(id, item, int(item.get("sell_price", 0))))
	return out


func buy(item_id: String, quantity: int = 1) -> Result:
	var db := _db()
	var inv := _inventory()
	if db == null or inv == null or quantity < 1:
		return Result.UNAVAILABLE
	var item: Dictionary = db.get_item(item_id)
	var price := int(item.get("buy_price", 0))
	if item.is_empty() or price <= 0:
		return Result.UNAVAILABLE
	var total := price * quantity
	if gold() < total:
		return Result.NOT_ENOUGH_GOLD
	if not inv.remove_item(GOLD_ITEM, total):
		return Result.NOT_ENOUGH_GOLD
	if not inv.add_item(item_id, quantity):
		inv.add_item(GOLD_ITEM, total)  # повертаємо золото, якщо предмет не влазить
		return Result.UNAVAILABLE
	return Result.OK


func sell(item_id: String, quantity: int = 1) -> Result:
	var db := _db()
	var inv := _inventory()
	if db == null or inv == null or quantity < 1:
		return Result.UNAVAILABLE
	var price := int(db.get_item(item_id).get("sell_price", 0))
	if price <= 0:
		return Result.UNAVAILABLE
	if inv.get_item_count(item_id) < quantity:
		return Result.NOT_OWNED
	if not inv.remove_item(item_id, quantity):
		return Result.NOT_OWNED
	inv.add_item(GOLD_ITEM, price * quantity)
	return Result.OK


static func format_price(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += ","
		grouped += digits[i]
	return "%s %s" % [UITokens.CURRENCY_SYMBOL, grouped]


func _row(id: String, item: Dictionary, price: int) -> Dictionary:
	var db := _db()
	return {
		"id": id,
		"name": db.get_item_name(id),
		"description": db.get_item_description(id),
		"icon": db.get_item_icon(id),
		"count": owned(id),
		"price": price,
	}


## InventoryManager.get_all_items() — словник {item_id: кількість}.
func _owned_ids(inv: Node) -> Array[String]:
	var ids: Array[String] = []
	for id in inv.get_all_items().keys():
		if inv.get_item_count(str(id)) > 0:
			ids.append(str(id))
	return ids
