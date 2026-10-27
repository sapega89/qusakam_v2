extends SceneTree

## Зонд розмірної сітки (design/world_scale_plan.md, слайс 1). Кожна кімната SampleProject/Maps: кожен намальований
## об'єкт, що не є повним планом тла (пропи, декор, двері й брами, скрині, NPC, вороги точок спавну, звірята, передній
## план) — його висота у px світу (непрозорий bbox кадру текстури × глобальний масштаб), коефіцієнт плану (scroll_scale.x
## Parallax2D, інакше 1), категорія за ключовим словом із design/world_scale.json, ціль і вердикт (ok / too big /
## too small, з відношенням). Повні плани тла лише перелічені (у них намальовані пропи міряються на око з кадру).
## Із вікном (xvfb) ще й кадр кожної кімнати з героєм на місці прибуття:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##     --script res://SampleProject/UI/probe_world_scale.gd -- out=design/shots/scale [room=Village ...]
## Файли: <out>/probe.json, <out>/rooms/<кімната>.png. Картинка й таблиці: Scripts/Tools/scale_chart.py.
## Лише в зонді: вороги заморожені, зони не реагують на героя, HUD схований. Сцени гри не змінює.

const MAPS_DIR := "res://SampleProject/Maps/"
const CHART := "res://design/world_scale.json"
const HERO_IDLE := "res://SampleProject/Sprites/Player/Idle/2.png"
const ARRIVALS: Array[String] = ["Arrival", "Arrival_Start"]
const STORY_DONE := {
	"LabCells": ["lab_cells_cutscene_complete", "lab_acquaintance_complete"],
}

var game: Node
var dm: Node
var chart: Dictionary
var out_dir := "res://design/shots/scale"
var only_rooms: Array[String] = []
var enemy_script: Script
var spawn_script: Script
var used_cache: Dictionary = {}
var room_names: Array[String] = []
var tokens_re := RegEx.create_from_string("[a-z]+")
var camel_re := RegEx.create_from_string("([a-z0-9])([A-Z])")


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.trim_prefix("out=")
		elif arg.begins_with("room="):
			only_rooms.append(arg.trim_prefix("room="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir + "/rooms"))
	chart = JSON.parse_string(FileAccess.get_file_as_string(CHART))
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	enemy_script = load("res://SampleProject/Scripts/Gameplay/DefaultEnemy.gd")
	spawn_script = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
	physics_frame.connect(_freeze_enemies)
	node_added.connect(_mute_trigger)
	for f: String in DirAccess.get_files_at(MAPS_DIR):
		if f.ends_with(".tscn"):
			room_names.append(f.get_basename())
	var rooms: Array[String] = only_rooms.duplicate() if not only_rooms.is_empty() else room_names.duplicate()
	var hero: Dictionary = _hero()
	var data := {"chart": CHART, "unit": chart.unit, "hero": hero, "rooms": []}
	for room: String in rooms:
		(data.rooms as Array).append(await _probe_room(room))
		print("SCALE %s: %d objects" % [room, (data.rooms[-1].objects as Array).size()])
	var f := FileAccess.open(out_dir + "/probe.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("SCALE done -> %s/probe.json" % out_dir)
	quit()


## Герой: кадр Idle/2.png × глобальний масштаб його Sprite2D.
func _hero() -> Dictionary:
	var sprite: Sprite2D = game.player.get_node("Sprite2D")
	var tex: Texture2D = load(HERO_IDLE)
	var used: Rect2i = _used(tex, Rect2i(Vector2i.ZERO, Vector2i(tex.get_size())))
	var scale: Vector2 = sprite.get_global_transform().get_scale()
	return {"texture": HERO_IDLE, "frame": [0, 0, tex.get_width(), tex.get_height()], "used": _r(used), "scale": [scale.x, scale.y],
			"figure_world_px": used.size.y * absf(scale.y), "cell_world_px": tex.get_height() * absf(scale.y)}


func _probe_room(room: String) -> Dictionary:
	for flag: String in STORY_DONE.get(room, []):
		game.set_quest_flag(flag, true)
	var path: String = MAPS_DIR + room + ".tscn"
	await game.teleport_to_room(path, _arrival(path))
	for i in 30: await physics_frame
	await _drain()
	_hide_ui(root)
	for i in 10: await process_frame
	var map: Node = game.map
	var player: CharacterBody2D = game.player
	var vp: Viewport = root.get_viewport()
	var canvas: Transform2D = vp.get_canvas_transform()
	var view_world: Vector2 = vp.get_visible_rect().size / canvas.get_scale()
	var shot := ""
	if DisplayServer.get_name() != "headless":
		shot = "rooms/%s.png" % room
		root.get_texture().get_image().save_png(out_dir + "/" + shot)
	var hero_rect: Rect2 = _hero_screen(player, canvas)
	# Об'єкти: малюючі вузли, згруповані до найближчого інстанса сцени / тіла (без Parallax2D між ними).
	var groups: Dictionary = {}
	var order: Array[Node] = []
	for node: Node in _all(map):
		if not (node is Sprite2D or node is AnimatedSprite2D):
			continue
		if not (node as CanvasItem).is_visible_in_tree() or player.is_ancestor_of(node) or _in_ui(node, map):
			continue
		if _enemy_of(node) != null and str(_enemy_of(node).name).begins_with("Enemy_"):
			continue  # заспавнені вороги міряються нижче, по одному на вид
		var part: Dictionary = _part(node as CanvasItem)
		if part.is_empty():
			continue
		var key: Node = _object_root(node, map)
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		(groups[key] as Array).append(part)
	var objects: Array = []
	var backdrops: Array = []
	for key: Node in order:
		var parts: Array = groups[key]
		var whole: Rect2 = _union(parts)
		if whole.size.x >= float(chart.backdrop_min_width_world_px) and parts.size() > 1:
			for part: Dictionary in parts:  # широкий інстанс тла: кожна частина сама
				var node: Node = map.get_node(part.node)
				_sort(node, [part], map, objects, backdrops)
		else:
			_sort(key, parts, map, objects, backdrops)
	# Вороги точок спавну: один зразок на вид, щойно створений поруч із точкою.
	var kinds: Dictionary = {}
	for point: Node in _all(map):
		if not is_instance_of(point, spawn_script):
			continue
		var kind: String = point.kind()
		if kinds.has(kind):
			kinds[kind].count += 1
			continue
		var enemy: Node2D = (load(point.scene_path(kind)) as PackedScene).instantiate()
		enemy.enemy_stats = point.enemy_stats()
		enemy.name = "ScaleProbe_%s" % kind
		enemy.position = point.position
		point.get_parent().add_child(enemy)
		for i in 3: await process_frame
		var parts: Array = []
		for node: Node in _all(enemy):
			if (node is Sprite2D or node is AnimatedSprite2D) and (node as CanvasItem).visible:
				var part: Dictionary = _part(node as CanvasItem)
				if not part.is_empty():
					parts.append(part)
		var entry: Dictionary = _object(enemy, parts, map)
		entry["spawn_kind"] = kind
		entry["count"] = 1
		entry["path"] = str(map.get_path_to(point))
		entry.category = _category(_haystacks(enemy, parts, [enemy.scene_file_path.get_file().get_basename(), kind]))
		_verdict(entry)
		kinds[kind] = entry
		enemy.queue_free()
		await process_frame
	for kind: String in kinds:
		objects.append(kinds[kind])
	return {"room": room, "capture": shot, "zoom": canvas.get_scale().x, "view_world": [view_world.x, view_world.y],
			"hero_screen": _r2(hero_rect), "objects": objects, "backdrops": backdrops}


func _sort(node: Node, parts: Array, map: Node, objects: Array, backdrops: Array) -> void:
	var entry: Dictionary = _object(node, parts, map)
	if entry.width_world >= float(chart.backdrop_min_width_world_px):
		backdrops.append({"path": entry.path, "plane": entry.plane, "width_world": entry.width_world,
				"height_world": entry.height_world, "textures": entry.textures})
		return
	entry.category = _category(_haystacks(node, parts))
	if (entry.textures as Array).all(func(t: String) -> bool: return t.ends_with(".svg")):
		entry.category = {"id": "marker", "keyword": "svg", "art_px": null, "h": null}  # іскра підбирання / місце дії
	_verdict(entry)
	objects.append(entry)


func _object(node: Node, parts: Array, map: Node) -> Dictionary:
	var whole: Rect2 = _union(parts)
	var textures: Array[String] = []
	for part: Dictionary in parts:
		if not part.texture in textures:
			textures.append(part.texture)
	return {"path": str(map.get_path_to(node)), "scene": node.scene_file_path, "plane": _plane(node),
			"height_world": snappedf(whole.size.y, 0.1), "width_world": snappedf(whole.size.x, 0.1), "bbox": _r2(whole),
			"textures": textures, "parts": parts}


## Ціль категорії × коефіцієнт плану; ok у межах ±tolerance_art_px (теж × план).
func _verdict(entry: Dictionary) -> void:
	var cat: Dictionary = entry.category
	if cat.id == "unknown" or cat.art_px == null:
		entry["target_world"] = null
		entry["verdict"] = "no target" if cat.id != "unknown" else "unknown"
		entry["ratio"] = null
		return
	var plane: float = entry.plane if entry.plane > 0.0 else 1.0
	var a2w: float = chart.unit.art_to_world
	var target: float = roundf(float(cat.art_px) * plane) * a2w
	var tol: float = float(chart.tolerance_art_px) * a2w
	entry["target_world"] = target
	entry["ratio"] = snappedf(entry.height_world / target, 0.01)
	if absf(entry.height_world - target) <= tol:
		entry["verdict"] = "ok"
	else:
		entry["verdict"] = "too big" if entry.height_world > target else "too small"


## Категорія: перше джерело, де є ключове слово; у джерелі — перша категорія за порядком у world_scale.json.
func _category(hays: Array[String]) -> Dictionary:
	for hay: String in hays:
		for cat: Dictionary in chart.categories:
			if cat.id == "hero":
				continue
			for kw: String in cat.keywords:
				for tail: String in ["_", "s_", "es_"]:
					if hay.contains("_" + kw + tail):
						return {"id": cat.id, "keyword": kw, "art_px": cat.art_px, "h": cat.h}
	return {"id": "unknown", "keyword": "", "art_px": null, "h": null}


## Джерела ключових слів від найточнішого: головне слово імені (Chest_TowerGuard — перший сегмент до «_»,
## WitchHut — останнє слово), усе ім'я, файл сцени, файли текстур, потім повні шляхи. [param first] — перед усім.
func _haystacks(node: Node, parts: Array, first: Array[String] = []) -> Array[String]:
	# Безіменний вузол (@Sprite2D@14 у Surfaces) — за іменем батька.
	var name: String = str(node.name) if not str(node.name).begins_with("@") else str(node.get_parent().name)
	var words: PackedStringArray = _tokens(name)
	var head: String = _tokens(name.get_slice("_", 0))[0] if name.contains("_") and not _tokens(name.get_slice("_", 0)).is_empty() \
			else (words[-1] if not words.is_empty() else "")
	var files: Array[String] = [node.scene_file_path.get_file().get_basename()]
	var paths: Array[String] = [node.scene_file_path]
	for part: Dictionary in parts:
		files.append(str(part.texture).get_file().get_basename())
		files.append(str(part.node).get_file())
		# Тека кімнати (Backgrounds/BanditCamp/…) — не ключове слово: інакше все в таборі стало б «bandit».
		var path: String = part.texture
		for room: String in room_names:
			path = path.replace("/%s/" % room, "/")
		paths.append(path)
	var out: Array[String] = []
	for bit: String in first:
		out.append(_hay(_tokens(bit)))
	out.append(_hay(PackedStringArray([head])))
	out.append(_hay(words))
	for group: Array[String] in [files, paths]:
		var all := PackedStringArray()
		for bit: String in group:
			all.append_array(_tokens(bit))
		out.append(_hay(all))
	return out


func _tokens(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m: RegExMatch in tokens_re.search_all(camel_re.sub(text, "$1_$2", true).to_lower()):
		out.append(m.get_string())
	return out


func _hay(words: PackedStringArray) -> String:
	return "_" + "_".join(words) + "_"


## Частина: кадр текстури, його непрозорий прямокутник і AABB у світі.
func _part(item: CanvasItem) -> Dictionary:
	var tex: Texture2D
	var frame: Rect2i
	var centered: bool
	var offset: Vector2
	var flip_h: bool
	var flip_v: bool
	if item is Sprite2D:
		var s: Sprite2D = item
		tex = s.texture
		if tex == null:
			return {}
		var src := Rect2(Vector2.ZERO, tex.get_size())
		if s.region_enabled:
			src = s.region_rect
		var cell: Vector2 = src.size / Vector2(s.hframes, s.vframes)
		frame = Rect2i(Vector2i(src.position + cell * Vector2(s.frame_coords)), Vector2i(cell))
		centered = s.centered
		offset = s.offset
		flip_h = s.flip_h
		flip_v = s.flip_v
	else:
		var a: AnimatedSprite2D = item
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return {}
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return {}
		frame = Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
		centered = a.centered
		offset = a.offset
		flip_h = a.flip_h
		flip_v = a.flip_v
	if not (tex is CompressedTexture2D or tex is AtlasTexture or tex is ImageTexture):
		return {}  # світло й серпанок (GradientTexture2D) — не предмет
	var base: Texture2D = tex
	var base_off := Vector2i.ZERO
	if tex is AtlasTexture:
		base = (tex as AtlasTexture).atlas
		base_off = Vector2i((tex as AtlasTexture).region.position)
	var used: Rect2i = _used(tex, frame)
	if used.size.x == 0 or used.size.y == 0:
		return {}
	var origin: Vector2 = offset - (Vector2(frame.size) * 0.5 if centered else Vector2.ZERO)
	var ux: float = float(frame.size.x - used.end.x) if flip_h else float(used.position.x)
	var uy: float = float(frame.size.y - used.end.y) if flip_v else float(used.position.y)
	var local := Rect2(origin + Vector2(ux, uy), Vector2(used.size))
	var xf: Transform2D = item.get_global_transform()
	var corners: Array[Vector2] = [xf * local.position, xf * Vector2(local.end.x, local.position.y), xf * local.end,
			xf * Vector2(local.position.x, local.end.y)]
	var box := Rect2(corners[0], Vector2.ZERO)
	for c: Vector2 in corners:
		box = box.expand(c)
	var scale: Vector2 = xf.get_scale()
	return {"node": str(game.map.get_path_to(item)), "texture": base.resource_path,
			"frame": [frame.position.x + base_off.x, frame.position.y + base_off.y, frame.size.x, frame.size.y],
			"used": _r(used), "flip_h": flip_h, "scale": [snappedf(scale.x, 0.0001), snappedf(scale.y, 0.0001)],
			"rotation": snappedf(xf.get_rotation(), 0.001), "modulate_a": snappedf(item.modulate.a * item.self_modulate.a, 0.01),
			"bbox": _r2(box)}


## Непрозорий прямокутник кадру [param frame] (координати кадру); кеш за текстурою й кадром.
func _used(tex: Texture2D, frame: Rect2i) -> Rect2i:
	var key: String = "%s|%s|%s" % [tex.resource_path, tex.get_rid(), frame]
	if used_cache.has(key):
		return used_cache[key]
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var rect: Rect2i = img.get_region(frame.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).get_used_rect()
	used_cache[key] = rect
	return rect


func _union(parts: Array) -> Rect2:
	var r := Rect2(_v(parts[0].bbox, 0), _v(parts[0].bbox, 2))
	for part: Dictionary in parts:
		r = r.merge(Rect2(_v(part.bbox, 0), _v(part.bbox, 2)))
	return r


func _v(a: Array, i: int) -> Vector2:
	return Vector2(a[i], a[i + 1])


## Корінь об'єкта: найближчий предок-інстанс сцени чи тіло; між ним і вузлом нема Parallax2D. Інакше — сам вузол.
func _object_root(node: Node, map: Node) -> Node:
	var n: Node = node
	while n != map:
		if n is Parallax2D:
			return node
		if n.scene_file_path != "" or n is CharacterBody2D:
			return n
		n = n.get_parent()
	return node


## Коефіцієнт плану: scroll_scale.x найближчого Parallax2D, інакше 1.
func _plane(node: Node) -> float:
	var n: Node = node
	while n != null:
		if n is Parallax2D:
			return snappedf((n as Parallax2D).scroll_scale.x, 0.001)
		n = n.get_parent()
	return 1.0


func _enemy_of(node: Node) -> Node:
	var n: Node = node
	while n != null:
		if is_instance_of(n, enemy_script):
			return n
		n = n.get_parent()
	return null


## Прямокутник героя на кадрі (екранні px): його Sprite2D з поточним кадром.
func _hero_screen(player: CharacterBody2D, canvas: Transform2D) -> Rect2:
	var part: Dictionary = _part(player.get_node("Sprite2D") as CanvasItem)
	var b: Array = part.bbox
	return Rect2(canvas * Vector2(b[0], b[1]), Vector2(b[2], b[3]) * canvas.get_scale())


func _r(r: Rect2i) -> Array[int]:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func _r2(r: Rect2) -> Array[float]:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]


## Як у film_rooms.gd: перша мітка старту, інакше SavePoint*, інакше двері.
func _arrival(path: String) -> NodePath:
	var state: SceneState = (load(path) as PackedScene).get_state()
	var names: Array[String] = []
	for i: int in state.get_node_count():
		if str(state.get_node_path(i, true)) == ".":
			names.append(str(state.get_node_name(i)))
	for want: String in ARRIVALS:
		if want in names:
			return NodePath(want)
	for n: String in names:
		if n.begins_with("SavePoint"):
			return NodePath(n)
	for n: String in names:
		if n.contains("Door") and not n.ends_with("Entrance"):
			return NodePath(n)
	push_error("probe_world_scale: no arrival in %s" % path)
	return NodePath(names[0])


func _freeze_enemies() -> void:
	for enemy: Node in _all(game):
		if is_instance_of(enemy, enemy_script) and enemy.process_mode != Node.PROCESS_MODE_DISABLED:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	if dm.is_dialogue_active():
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()


func _mute_trigger(node: Node) -> void:
	if node is Area2D and game.is_ancestor_of(node) and not game.player.is_ancestor_of(node):
		(node as Area2D).monitoring = false
	elif node.scene_file_path.ends_with("/DemoEndScreen.tscn"):
		node.process_mode = Node.PROCESS_MODE_DISABLED


func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame


func _hide_ui(node: Node) -> void:
	for child: Node in node.get_children():
		if child == game.map:
			continue
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		else:
			_hide_ui(child)


func _in_ui(node: Node, map: Node) -> bool:
	var n: Node = node
	while n != null and n != map:
		if n is CanvasLayer:
			return true
		n = n.get_parent()
	return false


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_all(child))
	return out
