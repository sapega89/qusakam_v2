extends RefCounted

## Різновиди ворогів (D495, D560): розмір, еліта, щитоносець — числа з Resources/Data/enemy_variety.json.
##   const EnemyVariety = preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
##   EnemyVariety.roll_size("DesertRoad.tscn/Fight_Mesa_EnemySpawnPoint3")  # "large"
## Кидки засіяні ключем точки (кімната + spawn_id): та сама кімната щоразу дає тих самих ворогів.

const DATA_PATH := "res://SampleProject/Resources/Data/enemy_variety.json"
const SIZES: Array[String] = ["small", "medium", "large"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


## Множники розміру [param kind]: scale, health, damage, speed, xp.
static func size(kind: String) -> Dictionary:
	return data().sizes[kind]


## Множники рівня бою [param fight_level] (D642): levels.health / levels.damage, по числу на рівень 1 … 20.
static func level(fight_level: int) -> Dictionary:
	var table: Dictionary = data().levels
	return {"health": float(table.health[fight_level - 1]), "damage": float(table.damage[fight_level - 1])}


static func elite() -> Dictionary:
	return data().elite


static func shield() -> Dictionary:
	return data().shield


## Розмір за вагами size_weights, засіяний [param key].
static func roll_size(key: String) -> String:
	var weights: Dictionary = data().size_weights
	var total := 0.0
	for kind in SIZES:
		total += weights[kind]
	var pick := _rng(key + "#size").randf() * total
	for kind in SIZES:
		pick -= weights[kind]
		if pick < 0.0:
			return kind
	return SIZES[-1]


## Еліта з шансом elite.chance (1 з 8), засіяна [param key].
static func roll_elite(key: String) -> bool:
	return _rng(key + "#elite").randf() < float(elite().chance)


static func _rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng
