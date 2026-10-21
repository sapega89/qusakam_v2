extends Node
class_name LootSystem

## 💰 LootSystem - Система луту
## Відповідає за генерацію луту з ворогів: гроші. Банок HP немає (Sapega 2026-10-21, D261, 4b).

# Налаштування луту
var gold_drop_chance: float = 0.7  # 70% шанс випасти гроші
var gold_min: int = 5
var gold_max: int = 20

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
	print("💰 LootSystem: Initialized")
	rng.randomize()
	
	# Підключаємося до сигналу смерті ворогів
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(_enemy_id: String, _position: Vector2) -> void:
	"""Обробляє смерть ворога та генерує лут"""
	var inventory_manager: InventoryManager = ServiceLocator.get_inventory_manager()
	# Генеруємо гроші
	if rng.randf() < gold_drop_chance:
		var gold_amount = rng.randi_range(gold_min, gold_max)
		inventory_manager.add_item("coin", gold_amount)
		EventBus.loot_picked_up.emit("coin", gold_amount)  # стрічка здобичі на HUD (BACKLOG 33)

## Налаштування параметрів луту
func set_gold_drop_chance(chance: float):
	"""Встановлює шанс випадання грошей (0.0-1.0)"""
	gold_drop_chance = clamp(chance, 0.0, 1.0)

func set_gold_range(min_amount: int, max_amount: int):
	"""Встановлює діапазон кількості грошей"""
	gold_min = max(0, min_amount)
	gold_max = max(gold_min, max_amount)
