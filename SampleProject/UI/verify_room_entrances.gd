extends SceneTree

## TIMEOUT: 900

## Кожен прохід пояснений картинкою, і виходиш тим, чим зайшов (M11/M12, room_art_audit, Sapega 2026-10-26):
##   godot --headless --path . --script res://SampleProject/UI/verify_room_entrances.gd
##   1. Кожен RoomDoor: арт входу (room_entrance.tscn) або намальований отвір з аудиту (✅); низ арту на підлозі
##      під ним (±2 px), центр дверей — в отворі, отвір вищий за героя; світло виходу (ExitLight, ADD); вхід за героєм
##      і нікого не закриває (NPC, скриня, драбина); arrival веде до дверей, якими зайшов.
##   2. Внутрішні краї (місто ↔ зала мера, камери ↔ коридори ↔ зала боса) — пари дверей, межа на карті MetSys закрита.
##   3. Печера ящурів у каньйоні далеко від спуску (Descent/Edge, CanyonExitTrigger): щонайменше 3/4 екрана.
##   4. Передній план (Parallax2D зі scroll > 1): ніщо не дістає лінії ходу, крім вибраних заслонів (Occluder*, Pillar*);
##      заслони не закривають двері, NPC і скрині, коли камера на них, а колони — середину бою; у печерах і льоху —
##      темний передній шар і темрява згори екрана (TopShade біля верху кадру).
##      B199: поки йде бій, жоден заслон не закриває героя чи точку спавну на повній непрозорості
##      (FightOccluderFade), а після бою заслони вертаються.
##   5. Драбини в матеріалі кімнати; кожен уступ має опору (A15).
##   6. Справжнім E крізь кожні двері в обидва боки: герой у цільовій кімнаті біля дверей, якими вийде назад.
## Пише лише в user://verify_room_entrances/.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const MAPS := "res://SampleProject/Maps/%s.tscn"
const TEST_DIR := "user://verify_room_entrances/"
const ROOMS := ["Canyon", "Village", "ElderHouse", "DesertRoad", "LizardCave", "DragonMural", "BanditCamp", "MesaClimb",
		"CityGates", "GatehouseCellar", "City", "MayorHall", "LabCells", "Laboratory", "LabBoss", "LaboratoryOutside",
		# M7: кімнати графів регіонів
		"CanyonFloor", "SmugglersStash", "LizardCaves", "MesaTop", "ZahraRest", "OldRuins", "Aqueduct", "GateApproach",
		"PalaceSquare", "Rooftops", "PigeonLoft", "TavernAttic", "MayorArchive", "Cistern", "CisternStash",
		"AlchemistCorridor", "AlchemistStore", "MalikStash", "CollapsedDrain"]
## Двері, чий отвір намальований у самому тлі (аудит: ✅), — їм окремий арт не потрібен.
const PAINTED := {
	"Village/ElderDoor": "the house's painted wooden door",
	"CityGates/CellarDoor": "the dark arch with cobwebs",
	"LizardCave/ExitDoor": "the lit cave opening (D729)",
	"GatehouseCellar/ExitDoor": "the foot of the painted stairs (D729)",
	"ZahraRest/WellDoor": "the stone well with its iron grate",
	"OldRuins/WellDoor": "the well shaft with its rope",
	"Aqueduct/ApproachDoor": "the side doorway with the stair up",
	"Aqueduct/CellarDoor": "the barred cellar arch",
	"GateApproach/AqueductDoor": "the well house's doorway with the stair down",
	"CanyonFloor/StashDoor": "the smugglers' crack in the dead-end cliff",
	"SmugglersStash/ExitDoor": "the dark tunnel back to the broken wall",
}
const EXIT_LIGHT := "res://SampleProject/Resources/Lighting/exit_light.tres"
## Герой у масштабі гри 1.5: 47 px кадру → 70 px.
const HERO_HEIGHT := 70.0
## Колишні проходи крізь край: [клітинка, сторона (0 праворуч, 2 ліворуч)] — тепер стіна.
const CLOSED_BORDERS := [[Vector3i(28, 5, 0), 0], [Vector3i(29, 5, 0), 2], [Vector3i(13, 3, 2), 0],
		[Vector3i(14, 3, 2), 2], [Vector3i(15, 5, 2), 0], [Vector3i(16, 5, 2), 2]]
const EDGE_DOORS := {"PalaceSquare": "MayorHallDoor", "MayorHall": "CityDoor", "LabCells": "CorridorDoor",
		"Laboratory": "CellsDoor", "LabBoss": "CorridorDoor"}
## Темний передній шар і темрява згори (Sapega: печера «темніше зверху, листя… передній фон закриває вид»).
const SHADED := ["LizardCave", "DragonMural", "GatehouseCellar", "MesaClimb", "ElderHouse"]
const OUTDOOR := ["Canyon", "Village", "DesertRoad", "CityGates", "City", "LaboratoryOutside"]
## Уступи, що стоять на намальованій будові (дах крамниці, верх башти, підлога горища) — опора вже в тлі.
const BUILT_IN := {
	"DesertRoad/Ledge_ShopRoof": "the shop's roof", "DesertRoad/Ledge_TowerTop": "the ruined tower's top",
	"ElderHouse/Attic/Ledge_Hatch": "the attic floor over the beams",
}
## Тверді уступи з тайлів/рельєфу: [x0, x1, верх] — під кожним опора з Supports.
## Лабораторія й зала боса — без уступів і містків (D832; рівні поверхи перевіряє verify_laboratory).
const LEDGES := {
	"Canyon": [[48, 288, 576], [512, 568, 480], [584, 792, 512], [416, 800, 672], [48, 248, 768]],
}
const IRON_LADDER_ROOMS := ["Laboratory", "GatehouseCellar"]

var fails: Array[String] = []
var game: Node


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(1)
	game = await Kit.boot(self)
	# Тест картинки й дверей, не бою: з D840/D841 герой 20-го рівня без вкладених очок (100 HP) гине від
	# підлаштованих під нього ворогів на дорозі, і пауза смерті зупиняє решту перевірок.
	game.player.set_invulnerable(true)
	_open_everything()

	print("[1] Every door: its entrance, the floor under it, the opening, the light, the way back")
	for room: String in ROOMS:
		await _visit(room)
		_check_doors(room)
		_check_front(room)
		await _check_cover(room)
		await _check_limits(room)
		await _check_fight_fade(room)
		_check_ladders(room)
		_check_supports(room)

	print("[2] Inner edges are door pairs, the MetSys borders closed")
	var map_data: Object = root.get_node("MetSys").map_data
	for cb: Array in CLOSED_BORDERS:
		ck(map_data.get_cell_at(cb[0]).get_border(cb[1]) == 0, "border %s side %d is a wall" % [cb[0], cb[1]])
	for room: String in EDGE_DOORS:
		ck(not map_data.get_cells_assigned_to(room + ".tscn").is_empty(), "%s keeps its cells" % room)

	print("[3] The canyon cave is a place of its own, not next to the descent")
	await _visit("Canyon")
	var cave: Vector2 = game.map.get_node(^"LizardCaveDoor").global_position
	var view_w: float = game.get_viewport().get_visible_rect().size.x / game.player.get_node(^"Camera2D").zoom.x
	for path: NodePath in [^"Descent/Edge", ^"CanyonExitTrigger"]:
		var d: float = absf(cave.x - (game.map.get_node(path) as Node2D).global_position.x)
		ck(d >= view_w * 0.75, "the cave door is %.0f px from %s (≥ %.0f, 3/4 of a screen)" % [d, path, view_w * 0.75])

	print("[4] Through every door both ways (real E)")
	for room: String in ROOMS:
		await _visit(room)
		var names: Array[String] = []
		for door: Node in _doors(game.map):
			names.append(door.name)
		for door_name: String in names:
			await _through(room, door_name)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


## Усе, що зачиняє двері сюжетом, — відчинено: тут перевіряється картинка й перехід, не сюжет.
func _open_everything() -> void:
	var gates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/gates.json")).gates
	for id: String in gates:
		if gates[id].has("flag"):
			game.set_quest_flag(gates[id].flag, true)
	for flag: String in ["lab_cells_cutscene_complete", "lab_acquaintance_complete"]:
		game.set_quest_flag(flag, true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_xp_manager().add_xp(100000)  # клятва — з 5-го рівня
	ck(sl.get_skill_manager().swear_oath("paladin") == 0, "the oath sworn (the mayor's door opens with it)")


func _visit(room: String) -> void:
	await game.teleport_to_room(MAPS % room, _first_door_or_arrival(room))
	for i in 20: await physics_frame
	await Kit.drain(self)
	# Двері за брилою (Wall_Mural у каньйоні, M7: дошки голубника, тріснуті стіни схованок) — брилу розбито.
	for door: Node in _doors(game.map):
		if door.cover.is_empty():
			continue
		var wall: Node = door.get_node_or_null(door.cover)  # розбита раніше брила вже прибрала себе
		if wall != null and not wall.was_broken():
			wall.smash()
			for i in 10: await physics_frame


func _first_door_or_arrival(room: String) -> NodePath:
	var scene: Node = (load(MAPS % room) as PackedScene).instantiate()
	var doors := _doors(scene)
	var path := NodePath(doors[0].name) if not doors.is_empty() else ^"Arrival"
	scene.free()
	return path


func _doors(scene: Node) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in scene.get_children():
		if _is_door(n):
			out.append(n)
	return out


## RoomDoor за скриптом: class_name у SceneTree-скрипті компілюється раніше за автолоади.
func _is_door(n: Node) -> bool:
	return n is Area2D and n.get_script() != null and (n.get_script() as Script).resource_path.ends_with("/RoomDoor.gd")


func _space() -> PhysicsDirectSpaceState2D:
	return game.map.get_world_2d().direct_space_state


## Перша тверда поверхня під точкою (без героя), або INF.
func _floor_below(p: Vector2, reach: float = 1200.0) -> float:
	var q := PhysicsRayQueryParameters2D.create(p, p + Vector2(0, reach))
	q.exclude = [game.player.get_rid()]
	for i in 8:
		var hit := _space().intersect_ray(q)
		if hit.is_empty():
			return INF
		if not (hit.collider is CharacterBody2D):  # вороги й NPC — не підлога
			return hit.position.y
		q.exclude = q.exclude + [hit.rid]
	return INF


func _solid_at(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.exclude = [game.player.get_rid()]
	return not _space().intersect_point(q, 1).is_empty()


func _check_doors(room: String) -> void:
	for door: Area2D in _doors(game.map):
		var key := "%s/%s" % [room, door.name]
		var light: Sprite2D = door.get_node(^"ExitLight")
		ck(light.texture.resource_path == EXIT_LIGHT and (light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
				and (light.visible or not door.cover.is_empty()), "%s: lit (warm additive glow)" % key)
		ck(light.z_index + door.z_index < game.player.z_index, "%s: the light is behind the hero" % key)
		var target: Node = (load(door.target_room) as PackedScene).instantiate()
		var back: Node = target.get_node_or_null(door.arrival)
		ck(back != null and _is_door(back) and back.target_room == MAPS % room and String(back.arrival) == String(door.name),
				"%s: arrives at %s:%s, which leads back to this door" % [key, door.target_room.get_file().get_basename(), door.arrival])
		target.free()
		if PAINTED.has(key):
			ck(game.map.get_node_or_null(NodePath(door.name + "Entrance")) == null, "%s: the painted opening (%s)" % [key, PAINTED[key]])
			continue
		var art: Sprite2D = game.map.get_node_or_null(NodePath(door.name + "Entrance"))
		ck(art != null and art.has_method(&"opening_rect"), "%s: has its entrance art" % key)
		if art == null:
			continue
		var foot: float = _floor_below(art.global_position - Vector2(0, 40))
		ck(absf(foot - art.global_position.y) <= 2.0, "%s: %s's foot on the floor (foot %.0f, floor %.0f)" % [key, art.art_name(), art.global_position.y, foot])
		var opening: Rect2 = art.opening_rect()
		ck(opening.has_point(door.global_position), "%s: the door's area is centred in the opening (%s in %s)" % [key, door.global_position, opening])
		ck(absf(opening.get_center().x - door.global_position.x) <= 2.0, "%s: centred across the opening" % key)
		ck(opening.size.y >= HERO_HEIGHT, "%s: the hero fits the opening (%.0f px)" % [key, opening.size.y])
		ck(opening.end.y <= foot + 1.0 and _floor_below(door.global_position) - door.global_position.y < 120.0,
				"%s: the arrival stands in front of the opening, over the floor" % key)
		ck(art.z_index < game.player.z_index and art.z_index > -9, "%s: drawn in the walkable plane, behind the hero (z %d)" % [key, art.z_index])
		_check_not_covering(key, art)


## Арт входу не малюється поверх NPC, скрині чи драбини, що стоять у ньому.
func _check_not_covering(key: String, art: Sprite2D) -> void:
	var rect: Rect2 = art.global_transform * art.get_rect()
	for n: Node in game.map.get_children():
		if not (n is Node2D) or n == art or not rect.has_point((n as Node2D).global_position):
			continue
		var kind := _subject_kind(n)
		if kind == "" or kind == "door":
			continue
		var above: bool = (n as CanvasItem).z_index > art.z_index or ((n as CanvasItem).z_index == art.z_index and n.get_index() > art.get_index())
		ck(above, "%s: the %s %s stands in front of the entrance" % [key, kind, n.name])


func _subject_kind(n: Node) -> String:
	if _is_door(n):
		return "door"
	if n.scene_file_path.contains("/NPCs/") or n.scene_file_path.ends_with("grandfather.tscn"):
		return "NPC"
	if n.scene_file_path.ends_with("Chest.tscn"):
		return "chest"
	if n.is_in_group(GameGroups.LADDERS):
		return "ladder"
	return ""


## Прямокутник видимого предмета в координатах світу (x — для шару з паралаксом — зсунутий камерою).
func _item_rect(ci: CanvasItem) -> Rect2:
	if ci is AnimatedSprite2D:
		var s: AnimatedSprite2D = ci
		var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
		var r := Rect2(s.offset, tex.get_size())
		if s.centered:
			r.position -= tex.get_size() / 2.0
		return s.global_transform * r
	return (ci as Node2D).global_transform * (ci as Sprite2D).get_rect()


func _front_items(room_node: Node) -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	for p: Node in room_node.find_children("*", "Parallax2D", true, false):
		if (p as Parallax2D).scroll_scale.x <= 1.0:
			continue
		for c: Node in p.find_children("*", "", true, false):
			if c is Sprite2D or c is AnimatedSprite2D:
				out.append(c)
	return out


func _is_occluder(ci: CanvasItem) -> bool:
	return String(ci.name).begins_with("Occluder") or String(ci.name).begins_with("Pillar")


func _check_front(room: String) -> void:
	var size: Vector2 = game.map.get_node(^"RoomInstance").get_size()
	var drift: float = 0.3 * maxf(size.x - 853.0, 0.0)
	var items := _front_items(game.map)
	for ci: CanvasItem in items:
		if _is_occluder(ci):
			continue
		var r := _item_rect(ci)
		var row_top: float = floorf(r.position.y / 480.0) * 480.0
		var hanging: bool = r.end.y - row_top < 240.0
		var worst := INF
		var x: float = maxf(r.position.x - drift, 0.0)
		while x <= minf(r.end.x, size.x):
			if hanging:
				# Над стелею чи стіною (точка під краєм — у твердому) героя бути не може.
				if not _solid_at(Vector2(x, r.end.y + 2.0)):
					worst = minf(worst, _floor_below(Vector2(x, r.end.y)) - r.end.y)
			else:
				var walk: float = _floor_below(Vector2(x, row_top - 1.0))
				if walk <= r.position.y:
					worst = minf(worst, r.position.y - walk)
			x += 16.0
		if hanging:
			ck(worst >= 100.0, "%s: %s hangs clear of the hero's head (%.0f px)" % [room, ci.name, worst])
		else:
			ck(worst >= 16.0, "%s: %s stays below the walk line (%.0f px)" % [room, ci.name, worst])
	if room in OUTDOOR:
		ck(game.map.get_node_or_null(^"Front") == null, "%s: no front band under the hero's feet" % room)
		ck(items.any(_is_occluder), "%s: tall dark occluders pass in front" % room)
	if room in SHADED:
		var dark: Node = game.map.get_node_or_null(^"FrontDark")
		ck(dark != null and (dark as CanvasItem).modulate.v < 0.5 and (dark as Parallax2D).scroll_scale.x > 1.0
				and (dark as CanvasItem).z_index > game.player.z_index, "%s: a dark foreground layer closer than the hero" % room)
		ck(dark != null and dark.get_children().any(func(c: Node) -> bool: return String(c.name).begins_with("Roots") or String(c.name).begins_with("Web")),
				"%s: roots / webs hang along the top" % room)
		var shade: Node2D = game.map.get_node_or_null(^"TopShade")
		var top_left: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse().origin
		ck(shade != null and shade.global_position.distance_to(top_left) < 2.0, "%s: the dark gradient sits at the top of the screen" % room)


## Камера на кожних дверях, NPC і скрині — їх не закриває жоден заслон; камера на бою — колона не посередині.
func _check_cover(room: String) -> void:
	var occluders := _front_items(game.map).filter(_is_occluder)
	if occluders.is_empty():
		return
	var subjects: Array[Node2D] = []
	var fights: Array[Node2D] = []
	for n: Node in game.map.get_children():
		if _subject_kind(n) in ["door", "NPC", "chest"]:
			subjects.append(n)
		if String(n.name).begins_with("Fight_"):
			for t: Node in n.get_children():
				if t is Area2D:
					fights.append(t)
	var vw: float = game.get_viewport().get_visible_rect().size.x
	for s: Node2D in subjects + fights:
		var at := s.global_position
		game.place_player(Vector2(at.x, at.y - 40.0))
		game.player.velocity = Vector2.ZERO
		for i in 4: await physics_frame
		(game.player.get_node(^"Camera2D") as Camera2D).reset_smoothing()
		for i in 10: await physics_frame
		var canvas := game.get_viewport().get_canvas_transform()
		var target: Rect2
		if s in fights:
			var vh: float = game.get_viewport().get_visible_rect().size.y
			target = Rect2(vw / 3.0, vh / 4.0, vw / 3.0, vh / 2.0)  # середина кадру, де йде бій
		else:
			var art: Node = game.map.get_node_or_null(NodePath(s.name + "Entrance"))
			var world: Rect2 = art.opening_rect() if art != null else Rect2(at.x - 24.0, at.y - 80.0, 48.0, 80.0)
			target = canvas * world
		for o: CanvasItem in occluders:
			var r: Rect2 = o.get_global_transform_with_canvas() * _local_rect(o)
			ck(not r.intersects(target), "%s: %s does not cover %s%s (%s vs %s, hero x %.0f)" % [room, o.name, "the fight's middle at " if s in fights else "", s.name, r, target, game.player.global_position.x])


## B199: кожен бій кімнати запущено, герой на кожній точці з живим ворогом — заслон над героєм чи точкою
## тьмяний (≤ FADED_ALPHA + 0.05); бій знято — усі заслони знову повні.
func _check_fight_fade(room: String) -> void:
	var occluders := _front_items(game.map).filter(_is_occluder)
	var spawners: Array[Node] = game.map.find_children("*", "RoomEnemySpawner", true, false)
	if occluders.is_empty() or spawners.is_empty():
		return
	# Вузол гри, не preload: скрипт тягне Game і автолоади, яких ще немає, коли компілюється цей SceneTree.
	var fade: Node = game.get_node(^"FightOccluderFade")
	var limit: float = fade.FADED_ALPHA + 0.05
	var body: Rect2 = fade.BODY
	var checked := 0
	for spawner: Node in spawners:
		if spawner.get_alive_enemies_count() == 0:
			spawner.spawn_all_enemies()
		for i in 10: await physics_frame
		for sp: Node2D in spawner.spawn_points:
			if not sp.is_enemy_alive():
				continue
			game.place_player(sp.global_position + Vector2(0.0, -40.0))
			game.player.velocity = Vector2.ZERO
			for i in 4: await physics_frame
			(game.player.get_node(^"Camera2D") as Camera2D).reset_smoothing()
			for i in 20: await process_frame
			game.player.current_health = game.player.Max_Health
			var canvas := game.get_viewport().get_canvas_transform()
			var view: Rect2 = game.get_viewport().get_visible_rect()
			var hero: Rect2 = canvas * Rect2(game.player.global_position + body.position, body.size)
			var point: Rect2 = canvas * Rect2(sp.global_position + body.position, body.size)
			for o: CanvasItem in occluders:
				var r: Rect2 = fade.screen_rect(o).intersection(view)
				if r.has_area() and (r.intersects(hero) or r.intersects(point)):
					checked += 1
					ck(o.modulate.a <= limit, "%s: %s fades over the fight at %s/%s (alpha %.2f)" % [room, o.name, spawner.name, sp.name, o.modulate.a])
		spawner.despawn_all_enemies()
	for i in 20: await process_frame
	game.player.current_health = game.player.Max_Health
	var others: Array = get_nodes_in_group(GameGroups.ENEMIES).filter(func(e: Node) -> bool: return e.is_alive() and game.map.is_ancestor_of(e))
	if others.is_empty():
		ck(occluders.all(func(o: CanvasItem) -> bool: return o.modulate.a >= 0.99), "%s: the occluders come back after the fight" % room)
	print("  ..  %s: %d occluder-over-fight cases" % [room, checked])


## B177: камера на межі кімнати стоїть — заслон ×1.3 тоді теж стоїть. Біля обох меж він поза кадром або лише
## краєм (зовнішні LIMIT_EDGE кадру), а не стоїть над героєм. B178: заслон, що сягає нижче ніг героя, ставить
## намальовану основу нижче кадру — інакше вона їде по дорозі.
const LIMIT_EDGE := 0.12


func _check_limits(room: String) -> void:
	var occluders := _front_items(game.map).filter(_is_occluder)
	if occluders.is_empty():
		return
	var size: Vector2 = game.map.get_node(^"RoomInstance").get_size()
	var y: float = game.player.global_position.y - 40.0
	var view: Rect2 = game.get_viewport().get_visible_rect()
	var edge: float = view.size.x * LIMIT_EDGE
	for x: float in [40.0, size.x - 40.0]:
		game.place_player(Vector2(x, y))
		game.player.velocity = Vector2.ZERO
		for i in 4: await physics_frame
		(game.player.get_node(^"Camera2D") as Camera2D).reset_smoothing()
		for i in 10: await physics_frame
		var feet: float = game.player.get_global_transform_with_canvas().origin.y
		for o: CanvasItem in occluders:
			var drawn: Rect2 = o.get_global_transform_with_canvas() * _local_rect(o)
			if drawn.end.y > feet and drawn.position.y < view.size.y and x < size.x / 2.0:
				ck(drawn.end.y >= view.size.y, "%s: %s has its foot below the view (%.0f of %.0f)" % [room, o.name, drawn.end.y, view.size.y])
			var seen: Rect2 = drawn.intersection(view)
			var ok: bool = seen.size.x <= 0.0 or seen.position.x >= view.size.x - edge or seen.end.x <= edge
			ck(ok, "%s: %s rests off the middle at the %s camera limit (seen x %.0f-%.0f of %.0f)" % [room, o.name,
					"left" if x < size.x / 2.0 else "right", seen.position.x, seen.end.x, view.size.x])


func _local_rect(ci: CanvasItem) -> Rect2:
	if ci is AnimatedSprite2D:
		var s: AnimatedSprite2D = ci
		var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
		return Rect2(s.offset - (tex.get_size() / 2.0 if s.centered else Vector2.ZERO), tex.get_size())
	return (ci as Sprite2D).get_rect()


func _check_ladders(room: String) -> void:
	for l: Node in game.map.find_children("*", "", true, false):
		if l.is_in_group(GameGroups.LADDERS):
			var want := "iron" if room in IRON_LADDER_ROOMS else "wood"
			ck(l.art == want, "%s: %s is %s (%s)" % [room, l.name, want, l.art])


func _check_supports(room: String) -> void:
	for body: Node in game.map.find_children("*", "StaticBody2D", true, false):
		var shape: CollisionShape2D = body.get_node_or_null(^"CollisionShape2D")
		if shape == null or not shape.one_way_collision:
			continue
		var key := "%s/%s" % [room, game.map.get_path_to(body)]
		if BUILT_IN.has(key):
			ck(true, "%s stands on %s" % [key, BUILT_IN[key]])
			continue
		var top: float = shape.global_position.y - (shape.shape as RectangleShape2D).size.y / 2.0
		var sup: Node = body.get_node_or_null(^"Support")
		ck(sup != null and absf(sup.global_position.y - top) <= 8.0 and sup.bottom() - top >= 30.0,
				"%s: held up by %s" % [key, sup.texture.resource_path.get_file() if sup != null else "nothing"])
	for l: Array in LEDGES.get(room, []):
		var mid: float = (l[0] + l[1]) / 2.0
		ck(absf(_floor_below(Vector2(mid, l[2] - 24.0)) - l[2]) <= 4.0, "%s: the ledge %s is there" % [room, l])
		var held := false
		for s: Node in game.map.get_node(^"Supports").get_children():
			held = held or (absf(s.global_position.x - mid) <= (l[1] - l[0]) / 2.0 + 8.0 and absf(s.global_position.y - l[2]) <= 6.0)
		ck(held, "%s: the ledge %s has its support" % [room, l])


## E біля дверей → цільова кімната, герой біля дверей, якими вийде; E знову → назад до цих дверей.
func _through(room: String, door_name: String) -> void:
	await game.teleport_to_room(MAPS % room, NodePath(door_name))
	for i in 20: await physics_frame
	await Kit.drain(self)
	var door: Area2D = game.map.get_node(NodePath(door_name))
	var target: String = door.target_room
	var arrival: String = door.arrival
	game.place_player(door.global_position)
	for i in 20: await physics_frame
	ck(door.interactable.player_nearby and door.interactable.enabled, "%s/%s offers Enter" % [room, door_name])
	await Kit.key(self, KEY_E)
	await _until_room(target)
	for i in 20: await physics_frame
	await Kit.drain(self)
	var back: Node2D = game.map.get_node_or_null(arrival)
	ck(game.map.scene_file_path == target and back != null and game.player.global_position.distance_to(back.global_position) < 64.0,
			"%s/%s → %s at %s (hero %s)" % [room, door_name, target.get_file().get_basename(), arrival, game.player.global_position])
	if back == null:
		return
	ck(back.interactable.player_nearby, "%s:%s offers the way back" % [target.get_file().get_basename(), arrival])
	await Kit.key(self, KEY_E)
	await _until_room(MAPS % room)
	for i in 20: await physics_frame
	await Kit.drain(self)
	ck(game.map.scene_file_path == MAPS % room and game.player.global_position.distance_to(game.map.get_node(NodePath(door_name)).global_position) < 64.0,
			"…and back out at %s/%s, the door he came in by" % [room, door_name])


func _until_room(path: String) -> void:
	for i in 180:
		if game.map != null and game.map.scene_file_path == path:
			return
		await physics_frame
