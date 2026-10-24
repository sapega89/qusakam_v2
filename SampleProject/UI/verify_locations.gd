extends SceneTree

## Локації як дані (D565, D458, world_structure_plan слайс 1):
##   godot --headless --path . --script res://SampleProject/UI/verify_locations.gd
##   1. Кожна кімната MetSys (сцена в Maps/ і на карті MapData.txt) — рівно в одній локації; зайвих кімнат немає.
##   2. Кожна локація має вхід, і вхід — її власна кімната.
##   3. Три локації демо D565 з їхніми кімнатами; назви перекладено (uk.po).
##   4. LocationDB: кімната → локація; Village і DesertRoad — одна локація (дорога стала частиною Canyon of Whispers).
##   5. GameFlow.location_title (картка сейва) — назва локації кімнати, ключ; картка показує її мовою гри.

const LocationDB = preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
const MAPS_DIR := "res://SampleProject/Maps"
const DEMO := {
	"canyon_of_whispers": ["Canyon", "Village", "ElderHouse", "DesertRoad", "LizardCave", "DragonMural", "BanditCamp", "MesaClimb"],  # + бічні кімнати D643
	"city": ["CityGates", "City", "MayorHall", "GatehouseCellar"],
	"laboratory": ["LaboratoryOutside", "Laboratory", "LabCells", "LabBoss"],
}

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


## Кімнати на карті MetSys: сцени, на які посилаються клітинки MapData.txt (":<uid>" у кінці рядка меж).
func _mapped_rooms() -> Array[String]:
	var out: Array[String] = []
	for line in FileAccess.get_file_as_string(MAPS_DIR + "/MapData.txt").split("\n"):
		var at := line.rfind(":")
		if line.begins_with("[") or at == -1 or at == line.length() - 1:
			continue
		var path := ResourceUID.get_id_path(ResourceUID.text_to_id("uid://" + line.substr(at + 1).strip_edges()))
		var room := path.get_file().get_basename()
		if room != "" and not out.has(room):
			out.append(room)
	return out


func _initialize() -> void:
	await process_frame  # LocalizationManager додає переклади у своєму _ready()
	var scenes: Array[String] = []
	for file in DirAccess.get_files_at(MAPS_DIR):
		if file.ends_with(".tscn"):
			scenes.append(file.get_basename())
	var mapped := _mapped_rooms()
	ck(mapped.size() == scenes.size() and mapped.all(func(r: String) -> bool: return scenes.has(r)),
			"every room scene is on the MetSys map (%d scenes, %d mapped)" % [scenes.size(), mapped.size()])

	# 1. Рівно одна локація на кімнату.
	var count := {}
	for loc: Dictionary in LocationDB.all():
		for room: String in loc.rooms:
			count[room] = count.get(room, 0) + 1
	for room in scenes:
		ck(count.get(room, 0) == 1, "%s is in exactly one location (%d)" % [room, count.get(room, 0)])
	for room: String in count:
		ck(scenes.has(room), "location room %s is a scene in Maps/" % room)

	# 2. Вхід — своя кімната.
	for loc: Dictionary in LocationDB.all():
		ck(not loc.entries.is_empty() and loc.entries.all(func(r: String) -> bool: return loc.rooms.has(r)),
				"%s has an entry among its own rooms (%s)" % [loc.id, loc.entries])

	# 3. Локації демо D565.
	ck(LocationDB.all().map(func(l: Dictionary) -> String: return l.id) == DEMO.keys(), "the three D565 locations, in story order")
	for id: String in DEMO:
		var rooms: Array = LocationDB.location(id).rooms
		ck(rooms.size() == DEMO[id].size() and DEMO[id].all(func(r: String) -> bool: return rooms.has(r)),
				"%s holds %s" % [id, DEMO[id]])
	TranslationServer.set_locale("uk")
	for loc: Dictionary in LocationDB.all():
		var uk := LocationDB.title(loc.id)
		ck(uk != loc.name and uk != "", "%s has a Ukrainian name (%s → %s)" % [loc.id, loc.name, uk])
	TranslationServer.set_locale("en")
	ck(LocationDB.title("city") == "The City", "English name of the City")

	# 4. Кімната → локація.
	ck(LocationDB.of_scene("res://SampleProject/Maps/LabBoss.tscn") == "laboratory", "LabBoss → laboratory")
	ck(LocationDB.of_room("Village") == LocationDB.of_room("DesertRoad"), "Village and DesertRoad are one location")
	ck(LocationDB.of_room("DesertRoad") != LocationDB.of_room("CityGates"), "DesertRoad → CityGates crosses into the City")

	# 5. Картка сейва: локація, не зона журналу (D618 замість D133).
	var flow: Node = load("res://SampleProject/Scripts/Managers/Story/GameFlow.gd").new()
	for room in scenes:
		var title: String = flow.location_title("%s/%s.tscn" % [MAPS_DIR, room])
		ck(title == LocationDB.location(LocationDB.of_room(room)).name, "save card: %s → %s" % [room, title])
	ck(flow.location_title(MAPS_DIR + "/MayorHall.tscn") == "The City", "MayorHall reads The City, not \"Mayor Hall\"")
	ck(flow.location_title(MAPS_DIR + "/DesertRoad.tscn") == "Canyon of Whispers", "DesertRoad reads Canyon of Whispers")
	flow.free()
	var card: Node = load("res://SampleProject/UI/Components/save_slot_card.tscn").instantiate()
	root.add_child(card)
	card.setup({"exists": true, "slot": 1, "location": "The City", "timestamp": "2026-10-23T12:00:00"}, true)
	TranslationServer.set_locale("uk")
	ck(card._location.atr(card._location.text) == LocationDB.title("city") and LocationDB.title("city") != "The City",
			"the card shows the location in Ukrainian (%s)" % card._location.atr(card._location.text))
	TranslationServer.set_locale("en")
	ck(card._location.atr(card._location.text) == "The City", "and in English")
	card.free()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
