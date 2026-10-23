extends RefCounted

## Локації світу (D565, D458): кімната MetSys → локація з Resources/Data/locations.json.
## Замінює регіони D492 (regions.json): правило повернення ворогів тепер діє на локацію.
##   const LocationDB = preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
##   LocationDB.of_scene("res://SampleProject/Maps/Laboratory.tscn")  # "laboratory"

const DATA_PATH := "res://SampleProject/Resources/Data/locations.json"

static var _locations: Array = []
static var _by_room: Dictionary = {}


## Усі локації в порядку файла: {id, name, rooms, entries}.
static func all() -> Array:
	_load()
	return _locations


## Локація за id; невідомий id — помилка даних.
static func location(id: String) -> Dictionary:
	for loc: Dictionary in all():
		if loc.id == id:
			return loc
	assert(false, "LocationDB: no location '%s' (locations.json)" % id)
	return {}


## Id локації кімнати [param room] (імʼя сцени без .tscn); кімната поза локаціями — помилка даних.
static func of_room(room: String) -> String:
	_load()
	assert(_by_room.has(room), "LocationDB: %s is in no location (locations.json)" % room)
	return _by_room[room]


## Id локації сцени кімнати.
static func of_scene(scene_path: String) -> String:
	return of_room(scene_path.get_file().get_basename())


## Назва локації мовою гри (ключ — англійська назва, D121).
static func title(id: String) -> String:
	return TranslationServer.translate(location(id).name)


static func _load() -> void:
	if not _locations.is_empty():
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_locations = data.locations
	for loc: Dictionary in _locations:
		for room: String in loc.rooms:
			_by_room[room] = loc.id
