extends RefCounted

## Швидкий слот зілля (D504): одна кнопка (quick_potion) — герой п'є зілля в реальному часі, не в меню на паузі.
## Слот бере те зілля з сумки, що найменше перекриває нестачу HP; якщо жодне не покриває — найсильніше.
## Зілля — предмети consumable з effect.type "heal" (items.json).


## [id зілля, скільки лікує] за зростанням сили — з ItemDatabase.
static func kinds() -> Array:
	var out: Array = []
	for id: String in ItemDatabase.get_items_by_type("consumable"):
		var effect: Dictionary = ItemDatabase.get_item(id).get("effect", {})
		if effect.get("type", "") == "heal":
			out.append([id, int(effect.value)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	return out


## Скільки всього зілля в сумці.
static func count() -> int:
	var inventory := ServiceLocator.get_inventory_manager()
	var total := 0
	for kind: Array in kinds():
		total += inventory.get_item_count(kind[0])
	return total


## Зілля, яке вип'є слот при нестачі [param missing] HP: [id, лікує], або [] — зілля немає.
static func pick(missing: int) -> Array:
	var inventory := ServiceLocator.get_inventory_manager()
	var best: Array = []
	for kind: Array in kinds():
		if inventory.get_item_count(kind[0]) <= 0:
			continue
		best = kind
		if kind[1] >= missing:
			break
	return best
