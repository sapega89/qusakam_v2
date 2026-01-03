extends RefCounted
class_name StatCalculator

## Статический класс для расчета производных статов на основе атрибутов и экипировки
## Требует класс CharacterAttributes (можно адаптировать под свою систему)

## Рассчитать максимальное здоровье
static func calculate_max_health(attributes: CharacterAttributes, equipment_stats: Dictionary) -> int:
	var effective_constitution = attributes.get_effective_constitution()
	
	# Базовая формула: 50 + (constitution * 5)
	var base_health = 50
	var health_per_con = 5
	var health_from_stats = base_health + (effective_constitution * health_per_con)
	
	# Бонус от защиты экипировки (каждая единица защиты = 2 HP)
	var defense_bonus = equipment_stats.get("defense", 0) * 2
	
	return health_from_stats + defense_bonus

## Рассчитать физический урон
static func calculate_physical_damage(attributes: CharacterAttributes, equipment_stats: Dictionary) -> int:
	var effective_strength = attributes.get_effective_strength()
	
	# Базовая формула: 10 + (strength * 2)
	var base_damage = 10
	var damage_per_str = 2
	var damage_from_stats = base_damage + (effective_strength * damage_per_str)
	
	# Прямой бонус атаки от экипировки
	var attack_bonus = equipment_stats.get("attack", 0)
	
	return damage_from_stats + attack_bonus

## Рассчитать магический урон
static func calculate_magic_damage(attributes: CharacterAttributes, equipment_stats: Dictionary) -> int:
	var effective_intelligence = attributes.get_effective_intelligence()
	
	# Базовая формула: 5 + (intelligence * 2)
	var base_damage = 5
	var damage_per_int = 2
	var damage_from_stats = base_damage + (effective_intelligence * damage_per_int)
	
	# Прямой бонус магии от экипировки
	var magic_bonus = equipment_stats.get("magic", 0)
	
	return damage_from_stats + magic_bonus

## Рассчитать физическую защиту
static func calculate_physical_defense(equipment_stats: Dictionary) -> int:
	return equipment_stats.get("defense", 0)

## Рассчитать магическую защиту
static func calculate_magic_defense(equipment_stats: Dictionary) -> int:
	# Магическая защита = половина от физической защиты
	return equipment_stats.get("defense", 0) / 2

## Рассчитать скорость атаки (множитель)
static func calculate_attack_speed(attributes: CharacterAttributes) -> float:
	var effective_dexterity = attributes.get_effective_dexterity()
	
	# Базовая формула: 1.0 + (dexterity * 0.02)
	# Максимальная скорость: 2.0x
	var base_speed = 1.0
	var speed_per_dex = 0.02
	return min(base_speed + (effective_dexterity * speed_per_dex), 2.0)

## Рассчитать шанс уклонения (0.0 - 1.0)
static func calculate_dodge_chance(attributes: CharacterAttributes) -> float:
	var effective_dexterity = attributes.get_effective_dexterity()
	
	# Базовая формула: 0% + (dexterity * 0.5%)
	# Максимальный шанс: 50%
	var base_dodge = 0.0
	var dodge_per_dex = 0.005
	return min(base_dodge + (effective_dexterity * dodge_per_dex), 0.5)

## Рассчитать точность (можно расширить позже)
static func calculate_accuracy(attributes: CharacterAttributes) -> float:
	var effective_dexterity = attributes.get_effective_dexterity()
	
	# Базовая точность: 80% + (dexterity * 0.5%)
	# Максимальная точность: 100%
	var base_accuracy = 0.8
	var accuracy_per_dex = 0.005
	return min(base_accuracy + (effective_dexterity * accuracy_per_dex), 1.0)

## Рассчитать критический шанс (можно расширить позже)
static func calculate_critical_chance(attributes: CharacterAttributes) -> float:
	var effective_dexterity = attributes.get_effective_dexterity()
	
	# Базовая формула: 5% + (dexterity * 0.2%)
	# Максимальный шанс: 50%
	var base_critical = 0.05
	var critical_per_dex = 0.002
	return min(base_critical + (effective_dexterity * critical_per_dex), 0.5)

## Получить все рассчитанные статы как словарь
static func calculate_all_stats(attributes: CharacterAttributes, equipment_stats: Dictionary) -> Dictionary:
	return {
		"max_health": calculate_max_health(attributes, equipment_stats),
		"physical_damage": calculate_physical_damage(attributes, equipment_stats),
		"magic_damage": calculate_magic_damage(attributes, equipment_stats),
		"physical_defense": calculate_physical_defense(equipment_stats),
		"magic_defense": calculate_magic_defense(equipment_stats),
		"attack_speed": calculate_attack_speed(attributes),
		"dodge_chance": calculate_dodge_chance(attributes),
		"accuracy": calculate_accuracy(attributes),
		"critical_chance": calculate_critical_chance(attributes)
	}

