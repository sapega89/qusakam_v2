extends SceneTree

## Карта MetSys ↔ сцени кімнат (B52). Розміри беруться з MapData.txt і налаштувань MetSys:
##   1. UID кімнати в MapData.txt розпізнається.
##   2. Тайли Foreground покривають ширину кожного рядка клітинок кімнати.
##   3. SavePoint / тригери / маркери / точки ворогів лежать у межах клітинок кімнати.
##   4. На кожному проході між кімнатами ліворуч-праворуч підлога з обох боків на одній висоті.
##   5. Ворог з'являється на підлозі під своєю точкою, а не в повітрі (B61).
##   6. Кожен верх, на який можна стати, намальований: тайли колізії сховані (D248) — тоді над кожною кромкою
##      є непрозорий піксель видимого Sprite2D кімнати (Terrain, Gorge, Surfaces, дошки містка). Інакше герой
##      стоїть на невидимій платформі (Sapega 2026-10-20 «я не бачу платформи»).
##   godot --headless --path . --script res://SampleProject/UI/verify_map_geometry.gd

## Не const preload: скрипт тягне сцени ворогів, а їм потрібні автолоади, яких під час компіляції тесту ще немає.
var spawn_point_script: Script
const MAP_DATA := "res://SampleProject/Maps/MapData.txt"
## Підлога по обидва боки проходу може різнитися не більше ніж на тайл.
const FLOOR_TOLERANCE := 32.0
const ENEMY_SCENE := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
## Низ тіла ворога може не доходити до підлоги на стільки пікселів.
const SPAWN_TOLERANCE := 2.0

var fails: Array[String] = []
var cell := Vector2.ZERO
## Відстань від центру ворога до низу його колізії.
var enemy_half_height := 0.0

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	spawn_point_script = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
	cell = root.get_node("MetSys").settings.in_game_cell_size
	var enemy: Node2D = load(ENEMY_SCENE).instantiate()
	var body: CollisionShape2D = enemy.get_node(^"CollisionShape2D")
	enemy_half_height = body.position.y + body.shape.get_rect().end.y
	enemy.free()
	print("cell %s" % cell)
	# {Vector3i клітинка: {borders: [R, D, L, U], uid}}
	var cells := _read_cells()
	# {uid: [Vector3i]}
	var rooms := {}
	for c in cells:
		var uid: String = cells[c].uid
		if not rooms.has(uid):
			rooms[uid] = []
		rooms[uid].append(c)

	# Підлога на краях кімнат у світових координатах: {Vector3i клітинка: {"left": y, "right": y}}.
	var edges := {}
	for uid in rooms:
		var path := ResourceUID.get_id_path(ResourceUID.text_to_id("uid://" + uid)) if ResourceUID.has_id(ResourceUID.text_to_id("uid://" + uid)) else ""
		ck(not path.is_empty(), "uid://%s resolves to a scene (cells %s)" % [uid, rooms[uid]])
		if path.is_empty():
			continue
		_check_room(path, rooms[uid], edges)

	print("[4] floor heights match across passages")
	for c in cells:
		var right: int = cells[c].borders[0]
		var n: Vector3i = c + Vector3i(1, 0, 0)
		if right <= 0 or not cells.has(n) or cells[n].uid == cells[c].uid:
			continue
		var a = edges.get(c, {}).get("right")
		var b = edges.get(n, {}).get("left")
		var name_a := _name(cells[c].uid)
		var name_b := _name(cells[n].uid)
		if a == null or b == null:
			ck(false, "%s %s → %s %s: floor at the edge (%s | %s)" % [name_a, c, name_b, n, a, b])
			continue
		ck(absf(a - b) <= FLOOR_TOLERANCE, "%s %s → %s %s: floor y %.0f vs %.0f" % [name_a, c, name_b, n, a, b])

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()


func _read_cells() -> Dictionary:
	var lines := FileAccess.get_file_as_string(MAP_DATA).split("\n")
	var cells := {}
	for i in lines.size() - 1:
		if not lines[i].begins_with("["):
			continue
		var xyz := lines[i].trim_prefix("[").trim_suffix("]").split(",")
		var data := lines[i + 1]
		if not data.contains(":"):
			continue  # клітинка без сцени (заготовка на карті)
		var borders: Array = []
		for b in data.get_slice("|", 0).split(","):
			borders.append(int(b))
		cells[Vector3i(int(xyz[0]), int(xyz[1]), int(xyz[2]))] = {"borders": borders, "uid": data.get_slice(":", data.get_slice_count(":") - 1)}
	return cells


func _name(uid: String) -> String:
	var id := ResourceUID.text_to_id("uid://" + uid)
	return ResourceUID.get_id_path(id).get_file().get_basename() if ResourceUID.has_id(id) else uid


func _check_room(path: String, room_cells: Array, edges: Dictionary) -> void:
	var name := path.get_file().get_basename()
	print("[%s]" % name)
	var min_c := Vector2i(room_cells[0].x, room_cells[0].y)
	for c in room_cells:
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
	var room: Node = load(path).instantiate()
	var fg: TileMapLayer = room.find_child("Foreground", true, false)
	var tile: Vector2 = Vector2(fg.tile_set.tile_size)

	# 2. Покриття: у кожному рядку клітинок тайли доходять від лівої до правої межі.
	var used := fg.get_used_rect()
	var tiles_px := Rect2(_origin(fg) + Vector2(used.position) * tile, Vector2(used.size) * tile)
	var rows := {}
	for c in room_cells:
		var x0: float = (c.x - min_c.x) * cell.x
		rows[c.y] = Vector2(minf(rows.get(c.y, Vector2(x0, x0)).x, x0), maxf(rows.get(c.y, Vector2(x0, x0)).y, x0 + cell.x))
	var room_w: float = 0.0
	for y in rows:
		room_w = maxf(room_w, rows[y].y)
	ck(tiles_px.end.x >= room_w - tile.x, "%s: tiles reach the right edge (x %.0f of %.0f)" % [name, tiles_px.end.x, room_w])

	# 3. Вузли в межах клітинок кімнати.
	for n in room.find_children("*", "Node2D", true, false):
		if not (n is Area2D or n is Marker2D or n.get_script() == spawn_point_script):
			continue
		var p: Vector2 = n.position
		var parent := n.get_parent()
		while parent != room:
			p += parent.position if parent is Node2D else Vector2.ZERO
			parent = parent.get_parent()
		var inside := false
		for c in room_cells:
			if Rect2(Vector2(c.x - min_c.x, c.y - min_c.y) * cell, cell).has_point(p):
				inside = true
		ck(inside, "%s: %s inside the room (%.0f, %.0f)" % [name, n.name, p.x, p.y])
		# 5. Ворог стоїть на підлозі під точкою.
		if n.get_script() == spawn_point_script:
			var floor_y = _floor_below(fg, tile, p)
			var feet := p.y + enemy_half_height
			if n.enemy_type in ["vulture", "bat", "fly"]:  # D445: летючий з'являється в повітрі — над підлогою, не на ній
				ck(floor_y != null and feet < floor_y, "%s: %s (flier) spawns in the air over the floor (feet y %.0f, floor %s)" % [name, n.name, feet, floor_y])
				continue
			ck(floor_y != null and feet <= floor_y and feet >= floor_y - SPAWN_TOLERANCE,
					"%s: %s spawns on the floor (feet y %.0f, floor %s)" % [name, n.name, feet, floor_y])

	# 4. Підлога на лівому/правому краю кожної клітинки: найвищий твердий тайл у крайньому стовпці
	# нижче першого вільного — це рівень, на який стає герой, що заходить збоку.
	for c in room_cells:
		var o := Vector2(c.x - min_c.x, c.y - min_c.y) * cell
		edges[c] = {
			"left": _floor_at(fg, tile, o.x + tile.x * 0.5, o.y, o.y + cell.y, min_c),
			"right": _floor_at(fg, tile, o.x + cell.x - tile.x * 0.5, o.y, o.y + cell.y, min_c),
		}
	# 6. Верхи невидимих шарів колізії намальовані спрайтами кімнати.
	var sprites := _drawn_sprites(room)
	for layer: TileMapLayer in room.find_children("*", "TileMapLayer", true, false):
		if layer.visible and layer.self_modulate.a > 0.0 or not layer.collision_enabled:
			continue
		var bare: Array[Vector2i] = []
		var tops := 0
		for c: Vector2i in layer.get_used_cells():
			if not _solid(layer, c) or _solid(layer, c + Vector2i.UP):
				continue
			var at := _origin(layer) + Vector2(c) * tile + Vector2(tile.x * 0.5, 3.0)
			if not Rect2(Vector2.ZERO, Vector2(room_w, cell.y * rows.size())).has_point(at):
				continue  # за межею кімнати камера не показує (тайли проходу до сусідньої кімнати)
			tops += 1
			if not _drawn_at(sprites, at):
				bare.append(c)
		ck(bare.is_empty(), "%s: all %d tops of hidden %s are drawn (bare cells %s)" % [name, tops, layer.name, bare.slice(0, 8)])
	room.free()


## [спрайт, перетворення в координати кімнати, картинка] для кожного видимого Sprite2D кімнати, що рухається разом
## з нею (під Parallax2D — фон, він не платформа).
func _drawn_sprites(room: Node) -> Array:
	var out := []
	for s: Sprite2D in room.find_children("*", "Sprite2D", true, false):
		var xf := Transform2D.IDENTITY
		var shown := true
		var n: Node = s
		while n != room:
			if n is Parallax2D or n is CanvasItem and not (n as CanvasItem).visible:
				shown = false
			if n is Node2D:
				xf = (n as Node2D).transform * xf
			n = n.get_parent()
		if shown and s.texture:
			out.append([s, xf.affine_inverse(), s.texture.get_image()])
	return out


func _drawn_at(sprites: Array, p: Vector2) -> bool:
	for entry: Array in sprites:
		var s: Sprite2D = entry[0]
		var local: Vector2 = entry[1] * p
		var rect := s.get_rect()
		if not rect.has_point(local):
			continue
		var img: Image = entry[2]
		var texel := local - rect.position
		if s.region_enabled:
			texel += s.region_rect.position
		var px := Vector2i(posmod(int(texel.x), img.get_width()), posmod(int(texel.y), img.get_height()))
		if img.get_pixelv(px).a > 0.5:
			return true
	return false


## Світова y верху першого твердого тайла під вільним місцем у стовпці x (у межах y0..y1 кімнати).
func _floor_at(fg: TileMapLayer, tile: Vector2, x: float, y0: float, y1: float, min_c: Vector2i) -> Variant:
	var col := int(floor((x - _origin(fg).x) / tile.x))
	var seen_air := false
	var row := int(floor((y0 - _origin(fg).y) / tile.y))
	var last := int(floor((y1 - _origin(fg).y) / tile.y))
	while row < last:
		var solid := _solid(fg, Vector2i(col, row))
		if not solid:
			seen_air = true
		elif seen_air:
			return _origin(fg).y + row * tile.y + min_c.y * cell.y
		row += 1
	return null


## y (у координатах кімнати) верху першого твердого тайла під точкою p, або null.
func _floor_below(fg: TileMapLayer, tile: Vector2, p: Vector2) -> Variant:
	var col := int(floor((p.x - _origin(fg).x) / tile.x))
	var row := int(floor((p.y - _origin(fg).y) / tile.y))
	for i in 64:
		if _solid(fg, Vector2i(col, row + i)):
			return _origin(fg).y + (row + i) * tile.y
	return null


func _solid(fg: TileMapLayer, at: Vector2i) -> bool:
	var data := fg.get_cell_tile_data(at)
	return data != null and data.get_collision_polygons_count(0) > 0


## Зсув шару відносно кімнати (TileMap-батько теж може бути зсунутий, як у City).
func _origin(fg: TileMapLayer) -> Vector2:
	return (fg.get_parent() as Node2D).position + fg.position
