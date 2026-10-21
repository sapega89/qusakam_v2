extends RefCounted
class_name CraftingService

## Логіка крафту без UI (як ShopService): рецепти станції, що є / чого бракує, сам крафт.
## Крафт коштує матеріали І золото (D85); ціни — тимчасові gold_cost у рецептах (D97).
## Дані — ItemDatabase (рецепти, предмети) та InventoryManager; золото — предмет "coin".

enum Result { OK, NOT_ENOUGH_MATERIALS, NOT_ENOUGH_GOLD }

## Таби коваля (D108). id — required_station у crafting_recipes.json.
const STATIONS := [
	{"id": "furnace", "label": "Furnace"},
	{"id": "workbench", "label": "Workbench"},
	{"id": "anvil", "label": "Anvil"},
	{"id": "alchemy_table", "label": "Alchemy"},
]


func _db() -> Node:
	return ServiceLocatorHelper.get_service_locator().get_item_database()


func _inventory() -> Node:
	return ServiceLocatorHelper.get_service_locator().get_inventory_manager()


func gold() -> int:
	return _inventory().get_item_count(ShopService.GOLD_ITEM)


## Рядки списку для станції й категорії результату (фільтр ShopService.CATEGORIES).
func recipes(station: String, category: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var db := _db()
	for recipe_id in db.get_all_recipes():
		var recipe: Dictionary = db.get_recipe(recipe_id)
		if recipe.required_station != station:
			continue
		var result_id: String = recipe.result.item_id
		if not ShopService.matches_category(db.get_item(result_id), category):
			continue
		out.append(row(recipe.id))
	return out


## Усе, що показують рядок, панель рецепта й модалки, для одного рецепта.
func row(recipe_id: String) -> Dictionary:
	var db := _db()
	var recipe: Dictionary = db.get_recipe(recipe_id)
	var result_id: String = recipe.result.item_id
	var materials: Array[Dictionary] = []
	var parts: PackedStringArray = []
	for ing in recipe.ingredients:
		var id: String = ing.item_id
		var need := int(ing.quantity)
		materials.append({"id": id, "name": db.get_item_name(id), "need": need,
				"have": _inventory().get_item_count(id)})
		parts.append("%d %s" % [need, db.get_item_name(id)])
	var made := int(recipe.result.quantity)
	var name: String = db.get_item_name(result_id)
	return {
		"id": recipe_id,
		"result_id": result_id,
		"name": name if made == 1 else "%s ×%d" % [name, made],
		"detail": tr("Requires: %s") % ", ".join(parts),
		"description": db.get_item_description(result_id),
		"icon": db.get_item_icon(result_id),
		"count": _inventory().get_item_count(result_id),
		"price": int(recipe.gold_cost),
		"materials": materials,
		"stats": result_stats(result_id),
	}


## Характеристики результату для панелі рецепта: ненульові stats або ефект зілля.
func result_stats(item_id: String) -> Array[Dictionary]:
	var item: Dictionary = _db().get_item(item_id)
	var out: Array[Dictionary] = []
	var labels := {"attack": "Phys. Atk", "defense": "Phys. Def", "magic": "Magic"}
	for key in labels:
		var value := int(item.get("stats", {}).get(key, 0))
		if value != 0:
			out.append({"label": labels[key], "value": "+%d" % value})
	var effect: Dictionary = item.get("effect", {})
	if effect.get("type", "") == "heal":
		out.append({"label": "Restores HP", "value": "+%d" % int(effect.value)})
	return out


## Чого бракує: [{name, missing}] — для "You are missing: …".
func missing(recipe_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in row(recipe_id).materials:
		if m.have < m.need:
			out.append({"name": m.name, "missing": m.need - m.have})
	return out


func check(recipe_id: String) -> Result:
	if not missing(recipe_id).is_empty():
		return Result.NOT_ENOUGH_MATERIALS
	if gold() < int(_db().get_recipe(recipe_id).gold_cost):
		return Result.NOT_ENOUGH_GOLD
	return Result.OK


## Спершу перевірка всього, потім списання — інвентар ніколи не лишається наполовину списаним.
func craft(recipe_id: String) -> Result:
	var verdict := check(recipe_id)
	if verdict != Result.OK:
		return verdict
	var recipe: Dictionary = _db().get_recipe(recipe_id)
	var inv := _inventory()
	for ing in recipe.ingredients:
		inv.remove_item(ing.item_id, int(ing.quantity))
	inv.remove_item(ShopService.GOLD_ITEM, int(recipe.gold_cost))
	inv.add_item(recipe.result.item_id, int(recipe.result.quantity))
	return Result.OK
