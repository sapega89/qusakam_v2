extends SceneTree

## performance_plan, slice 4: знімки шести зовнішніх кімнат до і після Scripts/Tools/region_backdrops.gd —
## попіксельне порівняння має дати 0. Кімната без скриптів і з вимкненою обробкою (нічого не рухається, частинок
## немає), камера як у грі (zoom 2.25), по шість кадрів на кімнату. Потрібне ВІКНО:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_backdrop_regions.gd -- out=<тека>
##   ... -- compare=<тека до>,<тека після>     рахує різні пікселі, нічого не знімає

const ROOMS: Array[String] = ["Canyon", "Village", "DesertRoad", "CityGates", "City", "LaboratoryOutside"]
const MAPS := "res://SampleProject/Maps/%s.tscn"
const ZOOM := 2.25
const SPOTS: Array[Vector2] = [Vector2(0.2, 0.35), Vector2(0.5, 0.35), Vector2(0.8, 0.35),
		Vector2(0.2, 0.75), Vector2(0.5, 0.75), Vector2(0.8, 0.75)]


func _initialize() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("compare="):
			_compare(arg.trim_prefix("compare=").split(","))
			quit()
			return
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(out)
	var cell: Vector2 = root.get_node("MetSys").settings.in_game_cell_size
	var camera := Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	camera.position_smoothing_enabled = false
	root.add_child(camera)
	camera.make_current()
	for room_name: String in ROOMS:
		var room: Node = load(MAPS % room_name).instantiate()
		_strip(room)
		room.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(room)
		var size: Vector2 = Vector2(_room_size(room_name)) * cell
		for i: int in SPOTS.size():
			camera.position = size * SPOTS[i]
			for f: int in 4:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, room_name, i])
		room.free()
		await process_frame
	print("CAPTURE done: %d rooms -> %s" % [ROOMS.size(), out])
	quit()


## Без скриптів кімната — лише те, що записано в сцені: ні сюжету, ні ворогів, ні випадковості.
func _strip(n: Node) -> void:
	for c: Node in n.get_children():
		_strip(c)
	n.set_script(null)


## Розмір кімнати в клітинках MetSys з MapData.txt.
func _room_size(room_name: String) -> Vector2i:
	var lines := FileAccess.get_file_as_string("res://SampleProject/Maps/MapData.txt").split("\n")
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for i: int in lines.size() - 1:
		if not lines[i].begins_with("["):
			continue
		var uid := lines[i + 1].get_slice(":", lines[i + 1].get_slice_count(":") - 1)
		if uid.is_empty() or ResourceUID.get_id_path(ResourceUID.text_to_id("uid://" + uid)) != MAPS % room_name:
			continue
		var xyz := lines[i].trim_prefix("[").trim_suffix("]").split(",")
		var c := Vector2i(int(xyz[0]), int(xyz[1]))
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return hi - lo + Vector2i.ONE


func _compare(dirs: PackedStringArray) -> void:
	var total: int = 0
	for room_name: String in ROOMS:
		var room_diff: int = 0
		for i: int in SPOTS.size():
			var a: PackedByteArray = _rgb("%s/%s_%d.png" % [dirs[0], room_name, i])
			var b: PackedByteArray = _rgb("%s/%s_%d.png" % [dirs[1], room_name, i])
			if a == b:
				continue
			for k: int in range(0, a.size(), 3):
				if a[k] != b[k] or a[k + 1] != b[k + 1] or a[k + 2] != b[k + 2]:
					room_diff += 1
		print("DIFF %-17s %d px differ (%d shots)" % [room_name, room_diff, SPOTS.size()])
		total += room_diff
	print("DIFF total %d px" % total)


func _rgb(path: String) -> PackedByteArray:
	var image := Image.load_from_file(path)
	image.convert(Image.FORMAT_RGB8)
	return image.get_data()
