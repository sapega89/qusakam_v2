extends RefCounted

## Регіони світу (D487, D492): кімната → регіон із Resources/Data/regions.json.
##   const Regions = preload("res://SampleProject/Scripts/Systems/Regions.gd")
##   Regions.of_scene("res://SampleProject/Maps/Laboratory.tscn")  # "laboratory"

const DATA_PATH := "res://SampleProject/Resources/Data/regions.json"

static var _by_room: Dictionary = {}


## Регіон сцени кімнати; кімната без регіону — помилка даних.
static func of_scene(scene_path: String) -> String:
	if _by_room.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		for region: String in data:
			if region.begins_with("_"):
				continue
			for room: String in data[region]:
				_by_room[room] = region
	var room := scene_path.get_file().get_basename()
	assert(_by_room.has(room), "Regions: %s is in no region (regions.json)" % room)
	return _by_room[room]
