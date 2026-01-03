extends Control

@export var potion_icon: Texture2D
@export var potion_hotkey: String = "use_potion" # або "use_potion"
@export var max_potions: int = 5

var current_potions := 0  # Починаємо з 0, щоб не показувати дефолтні значення

@onready var button = $PotionButton
@onready var icon = $PotionButton/PotionIcon
@onready var count_label = $PotionButton/PotionCount

func _ready():
	# Potion UI тепер наслідує видимість від UICanvas
	print("🎨 PotionUI: _ready() - Potion UI initialized")
	
	# Додаємо до групи для пошуку GameManager
	add_to_group(GameGroups.POTION_UI)
	print("🎨 PotionUI: Added to group 'potion_ui'")
	
	if potion_icon:
		icon.texture = potion_icon
	
	# Оновлюємо кількість зілля з GameManager
	update_potion_count_from_game_manager()
	_update_count()
	
	# Подключаем сигнал нажатия кнопки
	if button:
		button.pressed.connect(_use_potion)
	
	# Підписуємося на події EventBus для автоматичного оновлення
	if Engine.has_singleton("EventBus"):
		EventBus.item_added.connect(_on_item_added)
		EventBus.item_removed.connect(_on_item_removed)
		EventBus.inventory_updated.connect(_on_inventory_updated)
		print("🎨 PotionUI: Підписано на події EventBus")

func _process(_delta):
	# Не обрабатываем использование зелий во время паузы
	if get_tree().paused:
		return
		
	if Input.is_action_just_pressed(potion_hotkey):
		_use_potion()

func _use_potion():
	# Перевіряємо, чи гравець живий
	var player = GameGroups.get_first_node_in_group(GameGroups.PLAYER)
	if player and player.current_health <= 0:
		return
	
	# Перевіряємо кількість зілля в централізованому інвентарі
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		var inventory_manager = service_locator.get_inventory_manager() if service_locator and service_locator.has_method("get_inventory_manager") else null
		if not inventory_manager:
			return
		
		var potion_count = inventory_manager.get_item_count("potion")
		if potion_count > 0:
			# Видаляємо зілля з централізованого інвентарю
			inventory_manager.remove_item("potion", 1)
			
			# Оновлюємо локальний UI
			current_potions = inventory_manager.get_item_count("potion")
			_update_count()
			animate_button()
			
			# Знаходимо гравця та відновлюємо його HP
			if player and player.has_method("heal_damage"):
				player.heal_damage(50)  # Відновлюємо 50 HP
				
				# Емітуємо подію через EventBus
				if Engine.has_singleton("EventBus"):
					EventBus.item_used.emit("potion")

func _update_count():
	if count_label:
		count_label.text = "x%d" % current_potions
		print("🎨 PotionUI: _update_count() - current_potions: ", current_potions, " text: ", count_label.text)
	
func set_potion_count(count: int):
	"""Встановлює кількість зілля з GameManager"""
	current_potions = count
	print("🎨 PotionUI: set_potion_count() called with count: ", count)
	_update_count()

func update_potion_count_from_game_manager():
	"""Оновлює кількість зілля з GameManager"""
	if Engine.has_singleton("ServiceLocator"):
		var inventory_manager = ServiceLocator.get_inventory_manager()
		if inventory_manager:
			var potion_count = inventory_manager.get_item_count("potion")
			print("🎨 PotionUI: update_potion_count_from_game_manager() - found ", potion_count, " potions in InventoryManager")
			current_potions = potion_count
			_update_count()
		else:
			print("🎨 PotionUI: InventoryManager not found, keeping current_potions = ", current_potions)
	else:
		print("🎨 PotionUI: ServiceLocator not found, keeping current_potions = ", current_potions)

func _on_item_added(item_id: String, _quantity: int):
	"""Обробляє подію додавання предмета через EventBus"""
	if item_id == "potion":
		update_potion_count_from_game_manager()

func _on_item_removed(item_id: String, _quantity: int):
	"""Обробляє подію видалення предмета через EventBus"""
	if item_id == "potion":
		update_potion_count_from_game_manager()

func _on_inventory_updated():
	"""Обробляє подію оновлення інвентаря через EventBus"""
	update_potion_count_from_game_manager()

func animate_button():
	if button:
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(1, 1), 0.1)


func spawn_potion(spawn_position: Vector2):
	"""Спавнить зілля для підбору"""
	var potion_scene = preload("res://SampleProject/Scenes/Objects/potion.tscn")
	var potion_instance = potion_scene.instantiate()
	potion_instance.position = spawn_position
	call_deferred("add_child", potion_instance)

func _exit_tree() -> void:
	"""Відписується від всіх сигналів при видаленні вузла (запобігання витоків пам'яті)"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Відписується від всіх сигналів EventBus для запобігання витоків пам'яті"""
	if not Engine.has_singleton("EventBus"):
		return
	
	# Перевіряємо та відписуємося від сигналів інвентаря
	if EventBus.item_added.is_connected(_on_item_added):
		EventBus.item_added.disconnect(_on_item_added)
	if EventBus.item_removed.is_connected(_on_item_removed):
		EventBus.item_removed.disconnect(_on_item_removed)
	if EventBus.inventory_updated.is_connected(_on_inventory_updated):
		EventBus.inventory_updated.disconnect(_on_inventory_updated)
	
	# Перевіряємо та відписуємося від сигналу кнопки
	if button and button.pressed.is_connected(_use_potion):
		button.pressed.disconnect(_use_potion)
	
	print("🎨 PotionUI: Disconnected from all EventBus signals")

