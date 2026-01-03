extends Node

# 📦 ItemDatabase - Item and crafting recipe database
# Loads and manages item data from JSON files

const ITEMS_FILE = "res://SampleProject/Resources/Data/items.json"
const RECIPES_FILE = "res://SampleProject/Resources/Data/crafting_recipes.json"

# Сырые данные из JSON (для обратной совместимости)
var items: Dictionary = {}  # item_id -> Dictionary (как в JSON)

# DTO-объекты ItemData (новый API) - опционально, если используется аддон
var items_data: Dictionary = {}  # item_id -> ItemData

var recipes: Dictionary = {}  # recipe_id -> recipe_data
var items_by_category: Dictionary = {}  # category -> [item_ids]
var items_by_type: Dictionary = {}  # type -> [item_ids]

# Signals
signal items_loaded
signal recipes_loaded

func _ready():
	load_items()
	load_recipes()

func load_items():
	"""Loads items from JSON file"""
	items.clear()
	items_data.clear()
	items_by_category.clear()
	items_by_type.clear()

	var file = FileAccess.open(ITEMS_FILE, FileAccess.READ)
	if file == null:
		push_warning("⚠️ ItemDatabase: Cannot open items file: " + ITEMS_FILE + " - using empty items database")
		items_loaded.emit()
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("❌ ItemDatabase: Failed to parse items JSON: " + json.get_error_message())
		return
	
	var data = json.data
	if not data.has("items"):
		push_error("❌ ItemDatabase: Items file missing 'items' key")
		return
	
	# Load items (сырые Dictionary)
	for item_dict in data.items:
		var item_id: String = item_dict.get("id", "")
		if item_id:
			# Сохраняем сырые данные для существующего кода
			items[item_id] = item_dict
			
			# Group by category
			var category = item_dict.get("category", "misc")
			if not items_by_category.has(category):
				items_by_category[category] = []
			items_by_category[category].append(item_id)
			
			# Group by type
			var item_type = item_dict.get("type", "misc")
			if not items_by_type.has(item_type):
				items_by_type[item_type] = []
			items_by_type[item_type].append(item_id)
	
	print("✅ ItemDatabase: Loaded ", items.size(), " items")
	items_loaded.emit()

func load_recipes():
	"""Loads crafting recipes from JSON file"""
	var file = FileAccess.open(RECIPES_FILE, FileAccess.READ)
	if file == null:
		push_warning("⚠️ ItemDatabase: Cannot open recipes file: " + RECIPES_FILE + " - using empty recipes database")
		recipes_loaded.emit()
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("❌ ItemDatabase: Failed to parse recipes JSON: " + json.get_error_message())
		return
	
	var data = json.data
	if not data.has("crafting_recipes"):
		push_error("❌ ItemDatabase: Recipes file missing 'crafting_recipes' key")
		return
	
	# Load recipes
	for recipe_data in data.crafting_recipes:
		var recipe_id = recipe_data.get("id")
		if recipe_id:
			recipes[recipe_id] = recipe_data
	
	print("✅ ItemDatabase: Loaded ", recipes.size(), " crafting recipes")
	recipes_loaded.emit()

func get_item(item_id: String) -> Dictionary:
	"""
	Возвращает сырые данные предмета по ID (как раньше).
	Оставлено для обратной совместимости.
	"""
	if items.has(item_id):
		return items[item_id].duplicate()
	return {}

func get_item_data(item_id: String):
	"""
	Возвращает DTO-объект ItemData по ID (если используется аддон).
	"""
	if items_data.has(item_id):
		return items_data[item_id]
	return null

func get_item_name(item_id: String, language: String = "en") -> String:
	"""Gets item name in specified language"""
	var item = get_item(item_id)
	if item.is_empty():
		return "Unknown Item"
	
	if language == "ru" and item.has("name_ru"):
		return item.name_ru
	return item.get("name", "Unknown Item")

func get_item_description(item_id: String, language: String = "en") -> String:
	"""Gets item description in specified language"""
	var item = get_item(item_id)
	if item.is_empty():
		return ""
	
	if language == "ru" and item.has("description_ru"):
		return item.description_ru
	return item.get("description", "")

func get_items_by_category(category: String) -> Array:
	"""Gets list of item IDs by category"""
	if items_by_category.has(category):
		return items_by_category[category].duplicate()
	return []

func get_items_by_type(item_type: String) -> Array:
	"""Gets list of item IDs by type"""
	if items_by_type.has(item_type):
		return items_by_type[item_type].duplicate()
	return []

func get_all_items() -> Array:
	"""Gets list of all item IDs"""
	return items.keys()

func get_recipe(recipe_id: String) -> Dictionary:
	"""Gets recipe data by ID"""
	if recipes.has(recipe_id):
		return recipes[recipe_id].duplicate()
	return {}

func get_recipes_by_category(category: String) -> Array:
	"""Gets list of recipes by category"""
	var result = []
	for recipe_id in recipes:
		var recipe = recipes[recipe_id]
		if recipe.get("category", "") == category:
			result.append(recipe_id)
	return result

func get_recipes_for_item(item_id: String) -> Array:
	"""Gets list of recipes that create the specified item"""
	var result = []
	for recipe_id in recipes:
		var recipe = recipes[recipe_id]
		if recipe.has("result") and recipe.result.get("item_id") == item_id:
			result.append(recipe_id)
	return result

func can_craft_recipe(recipe_id: String, inventory: Dictionary) -> bool:
	"""Checks if recipe can be crafted with current items in inventory"""
	var recipe = get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	
	if not recipe.has("ingredients"):
		return false
	
	# Check availability of all ingredients
	for ingredient in recipe.ingredients:
		var item_id = ingredient.get("item_id")
		var required_quantity = ingredient.get("quantity", 1)
		var available_quantity = inventory.get(item_id, 0)
		
		if available_quantity < required_quantity:
			return false
	
	return true

func get_all_recipes() -> Array:
	"""Gets list of all recipe IDs"""
	return recipes.keys()

func get_item_icon(item_id: String) -> Texture2D:
	"""Gets item icon, returns placeholder if icon not found"""
	var item = get_item(item_id)
	if item.is_empty():
		print("⚠️ ItemDatabase: Item not found: ", item_id)
		return _get_placeholder_icon()
	
	var icon_path = item.get("icon_path", "")
	if icon_path == "":
		print("⚠️ ItemDatabase: No icon_path for item: ", item_id)
		return _get_placeholder_icon()
	
	# Check file existence
	if not FileAccess.file_exists(icon_path):
		push_warning("⚠️ ItemDatabase: Icon file does not exist for item '" + item_id + "' at path: " + icon_path)
		return _get_placeholder_icon()
	
	# Try to load icon
	var texture: Texture2D = null
	
	# First try loading through ResourceLoader
	var resource = ResourceLoader.load(icon_path)
	if resource != null and resource is Texture2D:
		texture = resource as Texture2D
	else:
		# Try loading directly
		texture = load(icon_path) as Texture2D
		if texture == null:
			# Try loading as ImageTexture
			var image = load(icon_path) as Image
			if image != null:
				var image_texture = ImageTexture.create_from_image(image)
				texture = image_texture
	
	if texture == null:
		# If icon not found, return placeholder
		push_warning("⚠️ ItemDatabase: Failed to load icon for item '" + item_id + "' at path: " + icon_path)
		return _get_placeholder_icon()
	
	return texture

func _get_placeholder_icon() -> Texture2D:
	"""Creates simple placeholder icon (colored square)"""
	# Create simple 64x64 texture with color
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	# Use blue color for placeholder
	image.fill(Color(0.2, 0.4, 0.8, 0.9))  # Blue semi-transparent square
	var texture = ImageTexture.create_from_image(image)
	return texture
