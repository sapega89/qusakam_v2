extends Area2D

# 🛒 Merchant - Merchant NPC
# Простий NPC для відкриття магазину

@onready var interaction_label = $InteractionLabel

var player_nearby = false
var is_shop_open = false
var shop_menu_instance: Control = null
var shop_canvas_layer: CanvasLayer = null

# ID торговця для завантаження товарів з JSON
@export var merchant_id: String = "default"

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if interaction_label:
		interaction_label.visible = false
		interaction_label.text = "Press E to open shop"
	
	# Додаємо до групи торговців
	add_to_group(GameGroups.MERCHANT)

	DebugLogger.info("Merchant: Initialized at position %s" % global_position, "Merchant")

func _on_body_entered(body):
	if body.is_in_group(GameGroups.PLAYER):
		player_nearby = true
		if interaction_label:
			interaction_label.visible = true

func _on_body_exited(body):
	if body.is_in_group(GameGroups.PLAYER):
		player_nearby = false
		if interaction_label:
			interaction_label.visible = false

func _unhandled_input(event):
	"""Використовуємо _unhandled_input замість _input для обробки вводу після інших систем"""
	if is_shop_open and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()
		return
	
	if is_shop_open:
		return
	
	if player_nearby and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E)):
		DebugLogger.info("Merchant: E key pressed, opening shop...", "Merchant")
		open_shop()
		get_viewport().set_input_as_handled()

func open_shop():
	"""Відкриває магазин"""
	DebugLogger.info("Merchant: open_shop() called, player_nearby: %s" % player_nearby, "Merchant")
	
	if is_shop_open and shop_menu_instance:
		close_shop()
		return
	
	var shop_ui_scene = load("res://SampleProject/Scenes/Shop/shop_menu.tscn")
	if not shop_ui_scene:
		push_error("❌ Merchant: ShopMenu scene not found!")
		return
	
	# Завантажуємо товари з JSON
	var shop_items = _load_merchant_items()
	if shop_items.is_empty():
		push_warning("⚠️ Merchant: No items found for merchant_id: " + merchant_id + ", using empty shop")
		# Все одно відкриваємо магазин, навіть якщо товарів немає
		shop_items = []
	
	# Створюємо CanvasLayer для магазину
	shop_canvas_layer = CanvasLayer.new()
	shop_canvas_layer.layer = 13
	shop_canvas_layer.name = "ShopCanvasLayer"
	shop_canvas_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Створюємо екземпляр ShopUI
	shop_menu_instance = shop_ui_scene.instantiate()
	if not shop_menu_instance:
		push_error("❌ Merchant: Failed to instantiate ShopUI scene!")
		shop_canvas_layer.queue_free()
		return
	
	shop_menu_instance.name = "ShopMenuInstance"
	
	# Додаємо до поточної сцени
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(shop_canvas_layer)
		shop_canvas_layer.add_child(shop_menu_instance)
	else:
		push_error("❌ Merchant: Current scene not found!")
		shop_canvas_layer.queue_free()
		return
	
	# Чекаємо кілька кадрів, щоб ShopUI встиг ініціалізуватися
	await get_tree().process_frame
	await get_tree().process_frame

	DebugLogger.info("Merchant: Setting up shop with %d items" % shop_items.size(), "Merchant")
	
	# Налаштовуємо магазин з товарами
	if shop_menu_instance.has_method("setup_shop"):
		shop_menu_instance.setup_shop(shop_items)
		is_shop_open = true
		
		# Переконуємося, що магазин видимий
		shop_menu_instance.visible = true
		shop_menu_instance.modulate = Color.WHITE
		
		# Також переконуємося, що base_menu видимий
		if shop_menu_instance.has("base_menu"):
			var base_menu = shop_menu_instance.get("base_menu")
			if base_menu and base_menu.has("visible"):
				base_menu.visible = true
		
		# Підключаємо сигнал закриття
		if shop_menu_instance.has_signal("shop_closed"):
			if not shop_menu_instance.shop_closed.is_connected(_on_shop_closed):
				shop_menu_instance.shop_closed.connect(_on_shop_closed)
		
		# Ставимо гру на паузу
		get_tree().paused = true

		DebugLogger.info("Merchant: Shop opened successfully with %d items" % shop_items.size(), "Merchant")
		DebugLogger.info("Merchant: Shop menu visible: %s" % shop_menu_instance.visible, "Merchant")
	else:
		push_error("❌ Merchant: ShopUI doesn't have setup_shop method!")
		close_shop()

func close_shop():
	"""Закриває магазин"""
	if not is_shop_open:
		return
	
	is_shop_open = false
	
	if shop_canvas_layer and is_instance_valid(shop_canvas_layer):
		shop_canvas_layer.queue_free()
		shop_canvas_layer = null
	
	shop_menu_instance = null
	get_tree().paused = false

	DebugLogger.info("Merchant: Shop closed", "Merchant")

func _on_shop_closed():
	"""Обробник сигналу закриття магазину"""
	close_shop()

func _load_merchant_items() -> Array:
	"""Завантажує товари торговця з JSON файлу"""
	const MERCHANTS_FILE = "res://SampleProject/Resources/Data/merchants.json"
	
	var file = FileAccess.open(MERCHANTS_FILE, FileAccess.READ)
	if file == null:
		push_error("❌ Merchant: Cannot open merchants file: " + MERCHANTS_FILE)
		return []
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("❌ Merchant: Failed to parse merchants JSON: " + json.get_error_message())
		return []
	
	var data = json.data
	if not data.has("merchants"):
		push_error("❌ Merchant: Merchants file missing 'merchants' key")
		return []
	
	if not data.merchants.has(merchant_id):
		push_warning("⚠️ Merchant: Merchant ID '" + merchant_id + "' not found, using 'default'")
		merchant_id = "default"
	
	if not data.merchants.has(merchant_id):
		push_error("❌ Merchant: Default merchant not found in JSON!")
		return []
	
	var merchant_data = data.merchants[merchant_id]
	if not merchant_data.has("items"):
		push_error("❌ Merchant: Merchant data missing 'items' key")
		return []
	
	return merchant_data.items.duplicate()

func _exit_tree() -> void:
	"""Відключаємося від сигналів при видаленні"""
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if body_exited.is_connected(_on_body_exited):
		body_exited.disconnect(_on_body_exited)

	# Закриваємо магазин якщо він відкритий
	if is_shop_open:
		close_shop()

