extends RefCounted

## Різновиди ворогів (D495, D560, D652): розмір і еліта за видом, щитоносець — числа з Resources/Data/enemy_variety.json.
##   const EnemyVariety = preload("res://SampleProject/Scripts/Gameplay/EnemyVariety.gd")
##   EnemyVariety.roll_size("melee", "DesertRoad.tscn/Fight_Mesa_EnemySpawnPoint3")  # "small"
## Кидки засіяні ключем точки (кімната + spawn_id): та сама кімната щоразу дає тих самих ворогів.
## Більший ворог — свій вид зі своїм артом, і саме ці види — еліта (D652); вид без аркуша ще не зʼявляється (available).

const DATA_PATH := "res://SampleProject/Resources/Data/enemy_variety.json"
const SIZES: Array[String] = ["small", "medium"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


## Множники розміру [param size_kind]: scale, health, damage, speed, xp.
static func size(size_kind: String) -> Dictionary:
	return data().sizes[size_kind]


## Множники рівня бою [param fight_level] (D642): levels.health / levels.damage, по числу на рівень 1 … 20.
static func level(fight_level: int) -> Dictionary:
	var table: Dictionary = data().levels
	return {"health": float(table.health[fight_level - 1]), "damage": float(table.damage[fight_level - 1])}


## Множники еліти (D560): health, damage, xp — лише для видів з "elite": true.
static func elite() -> Dictionary:
	return data().elite


static func shield() -> Dictionary:
	return data().shield


## Вид [param id] з kinds: sheet, elite, sizes; великий вид ще base і scene, проклятий — foam.
static func kind(id: String) -> Dictionary:
	return data().kinds[id]


## Усі види (без _note).
static func kind_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in data().kinds:
		if not id.begins_with("_"):
			out.append(id)
	return out


## Великі види (D652): ті, що мають base — звичайний вид, який стоїть на їхньому місці, поки немає арту.
static func big_kinds() -> Array[String]:
	return kind_ids().filter(func(id: String) -> bool: return kind(id).has("base"))


static func is_elite(id: String) -> bool:
	return kind(id).elite


## Вид може зʼявитись, коли його аркуш уже є (D652: без арту — не спавниться).
static func available(id: String) -> bool:
	return ResourceLoader.exists(kind(id).sheet)


## Розмір виду [param id] за його вагами sizes, засіяний [param key].
static func roll_size(id: String, key: String) -> String:
	var weights: Dictionary = kind(id).sizes
	var total := 0.0
	for size_kind in SIZES:
		total += weights.get(size_kind, 0)
	var pick := _rng(key + "#size").randf() * total
	for size_kind in SIZES:
		pick -= weights.get(size_kind, 0)
		if pick < 0.0:
			return size_kind
	return SIZES[-1]


static func _rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng
