extends Node
class_name LootSystem

## 💰 LootSystem - Система луту
## Відповідає за генерацію луту з ворогів (гроші, банки HP)

# Налаштування луту
var gold_drop_chance: float = 0.7  # 70% шанс випасти гроші
var gold_min: int = 5
var gold_max: int = 20

var potion_drop_chance: float = 0.3  # 30% шанс випасти банку HP
var potion_drop_max: int = 1  # Максимум 1 банка за ворога

# Посилання на менеджери
var inventory_manager: InventoryManager = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
	print("💰 LootSystem: Initialized")
	rng.randomize()
	
	# Затримка для забезпечення ініціалізації GameManager та InventoryManager
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Знаходимо InventoryManager через ServiceLocatorHelper
	inventory_manager = ServiceLocatorHelper.get_service_locator().get_inventory_manager() if ServiceLocatorHelper.get_service_locator() else null
	
	# Если не нашли через ServiceLocator, пытаемся найти напрямую в GameManager
	if not inventory_manager:
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			inventory_manager = game_manager.get_node_or_null("InventoryManager")
	
	if not inventory_manager:
		push_warning("⚠️ LootSystem: InventoryManager not found")
	
	# Підключаємося до сигналу смерті ворогів
	if Engine.has_singleton("EventBus"):
		if not EventBus.enemy_died.is_connected(_on_enemy_died):
			EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(_enemy_id: String, _position: Vector2) -> void:
	"""Обробляє смерть ворога та генерує лут"""
	if not inventory_manager:
		return
	
	# Генеруємо гроші
	if rng.randf() < gold_drop_chance:
		var gold_amount = rng.randi_range(gold_min, gold_max)
		inventory_manager.add_item("coin", gold_amount)
	
	# Генеруємо банки HP
	if rng.randf() < potion_drop_chance:
		inventory_manager.add_item("potion", 1)

## Налаштування параметрів луту
func set_gold_drop_chance(chance: float):
	"""Встановлює шанс випадання грошей (0.0-1.0)"""
	gold_drop_chance = clamp(chance, 0.0, 1.0)

func set_gold_range(min_amount: int, max_amount: int):
	"""Встановлює діапазон кількості грошей"""
	gold_min = max(0, min_amount)
	gold_max = max(gold_min, max_amount)

func set_potion_drop_chance(chance: float):
	"""Встановлює шанс випадання банок HP (0.0-1.0)"""
	potion_drop_chance = clamp(chance, 0.0, 1.0)
