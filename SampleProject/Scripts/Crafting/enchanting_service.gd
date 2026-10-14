extends RefCounted
class_name EnchantingService

## Логіка зачарування без UI (як CraftingService). D94: два однакові предмети → один на рівень
## вище; D163: кап +20; D164: ціна росте з рівнем. Рівень живе в id ("iron_dagger+2") —
## див. ItemDatabase._enchanted_item(). Золото — предмет "coin".

enum Result { OK, NOT_ENCHANTABLE, MAX_LEVEL, NOT_ENOUGH_ITEMS, NOT_ENOUGH_GOLD }

## Скільки однакових предметів іде на одне зачарування (D94).
const ITEMS_PER_ENCHANT := 2
## ponytail: тимчасова ціна (D164 — "росте з рівнем"), як gold_cost крафту (D97); баланс пізніше.
const COST_SHARE_PER_LEVEL := 0.1
## Підписи стату — ті самі, що в панелі рецепта (CraftingService.result_stats).
const STAT_LABELS := {"attack": "Phys. Atk", "defense": "Phys. Def"}


func _db() -> Node:
	return ServiceLocatorHelper.get_service_locator().get_item_database()


func _inventory() -> Node:
	return ServiceLocatorHelper.get_service_locator().get_inventory_manager()


func gold() -> int:
	return _inventory().get_item_count(ShopService.GOLD_ITEM)


## Що вийде з двох item_id.
func result_id(item_id: String) -> String:
	return _db().enchanted_id(item_id, _db().enchant_level(item_id) + 1)


## Ціна зачарування item_id у наступний рівень: частка buy_price базового предмета × новий рівень.
func cost(item_id: String) -> int:
	var base: Dictionary = _db().get_item(_db().base_id(item_id))
	var next_level: int = _db().enchant_level(item_id) + 1
	return int(int(base.get("buy_price", 0)) * COST_SHARE_PER_LEVEL * next_level)


## Предмети, які зараз можна зачарувати: зачаровувані, нижче капу, і їх щонайменше два.
## Недоступні в список не потрапляють (Sapega, 2026-10-15); брак золота лишаємо видимим — модалка пояснить.
func candidates() -> Array[String]:
	var out: Array[String] = []
	for item_id in _inventory().get_items_dict():
		if _db().is_enchantable(item_id) and _db().enchant_level(item_id) < _db().ENCHANT_MAX_LEVEL 				and _inventory().get_item_count(item_id) >= ITEMS_PER_ENCHANT:
			out.append(item_id)
	return out


## Рядки екрана: усе, що показують рядок, опис і модалки, для одного предмета.
func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_id in candidates():
		out.append(row(item_id))
	return out


func row(item_id: String) -> Dictionary:
	var db := _db()
	var made := result_id(item_id)
	var stat: String = db.ENCHANT_STAT[db.get_item(item_id).type]
	return {
		"id": item_id,
		"result_id": made,
		"name": db.get_item_name(item_id),
		"result_name": db.get_item_name(made),
		"detail": "%s ×%d → %s  (%s %d → %d)" % [db.get_item_name(item_id), ITEMS_PER_ENCHANT,
				db.get_item_name(made), STAT_LABELS[stat], int(db.get_item(item_id).stats[stat]),
				int(db.get_item(made).stats[stat])],
		"description": db.get_item_description(db.base_id(item_id)),
		"icon": db.get_item_icon(item_id),
		"count": _inventory().get_item_count(item_id),
		"price": cost(item_id),
	}


func check(item_id: String) -> Result:
	if not _db().is_enchantable(item_id) or _db().get_item(item_id).is_empty():
		return Result.NOT_ENCHANTABLE
	if _db().enchant_level(item_id) >= _db().ENCHANT_MAX_LEVEL:
		return Result.MAX_LEVEL
	if _inventory().get_item_count(item_id) < ITEMS_PER_ENCHANT:
		return Result.NOT_ENOUGH_ITEMS
	if gold() < cost(item_id):
		return Result.NOT_ENOUGH_GOLD
	return Result.OK


## Спершу перевірка всього, потім списання — інвентар ніколи не лишається наполовину списаним.
func enchant(item_id: String) -> Result:
	var verdict := check(item_id)
	if verdict != Result.OK:
		return verdict
	var inv := _inventory()
	var price := cost(item_id)
	var made := result_id(item_id)
	inv.remove_item(item_id, ITEMS_PER_ENCHANT)
	inv.remove_item(ShopService.GOLD_ITEM, price)
	inv.add_item(made, 1)
	return Result.OK
