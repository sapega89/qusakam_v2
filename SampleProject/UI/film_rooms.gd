extends SceneTree

## Фільм кімнати для критиків глибини (depth_critics_plan, слайс 1). Герой бігає справжніми діями (move_left/right,
## jump): лінія ходу в один бік зі стрибком, назад, стоїть 1 с; камера гри їде за ним. Movie Maker пише відео,
## а зонд щокадру міряє кожен візуальний план на екрані проти камери і ноги героя проти колізії під ним.
## Один запуск — одна кімната (Movie Maker пише один файл на запуск). Потрібне вікно:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##     --write-movie <тека>/<кімната>.avi --fixed-fps 30 --script res://SampleProject/UI/film_rooms.gd -- room=<кімната> out=<тека>
## Файли: <тека>/<кімната>.avi, <тека>/<кімната>.layers.json. Усі кімнати + пакунок: Scripts/Tools/film_rooms.sh.
## Лише у фільмі: вороги вимкнені (бої не перебивають прохід), HUD і весь UI сховані.

const MAPS := "res://SampleProject/Maps/%s.tscn"
## Перевага міток старту: перша наявна серед дітей кімнати.
const ARRIVALS: Array[String] = ["Arrival", "Arrival_Start"]
## Лише у фільмі: сюжет кімнати вже пройдено, щоб вхідна кат-сцена не забрала камеру й героя (LabCells без цього
## тримає камеру на камерах в'язнів, а героя — у сцені).
const STORY_DONE := {
	"LabCells": ["lab_cells_cutscene_complete", "lab_acquaintance_complete"],
}
const RUN_FRAMES := 150  # 2,5 с в один бік
const JUMP_AT := 60
const JUMP_HOLD := 18
const STAND_FRAMES := 60
## Скільки кадрів без руху вважаємо «уперся в стіну».
const BLOCKED_FRAMES := 20
## Біг зупиняється за стільки px від краю кімнати: за краєм MetSys перемикає кімнату.
const EDGE_MARGIN := 64.0
## Кроки швидкості, що вважаються різними планами (×камери).
const SPEED_STEP := 0.05
## Розмір зменшеного кадру для середніх значень плану.
const STATS_SIZE := Vector2i(480, 270)

var game: Node
var dm: Node
var room_name := ""
var out_dir := ""
var planes: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var hidden_ui: Array[String] = []
var frozen_enemies: int = 0
var phase := "settle"
var enemy_script: Script


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("room="):
			room_name = arg.trim_prefix("room=")
		elif arg.begins_with("out="):
			out_dir = arg.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: без підказок «?»
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	enemy_script = load("res://SampleProject/Scripts/Gameplay/DefaultEnemy.gd")  # не class_name: autoload ще нема при компіляції
	physics_frame.connect(_freeze_enemies)
	node_added.connect(_mute_trigger)
	for flag: String in STORY_DONE.get(room_name, []):
		game.set_quest_flag(flag, true)
	var arrival: NodePath = _arrival(MAPS % room_name)
	await game.teleport_to_room(MAPS % room_name, arrival)
	for i in 30: await physics_frame
	await _drain()
	_hide_ui(root)
	for i in 30: await physics_frame
	var player: CharacterBody2D = game.player
	_collect_planes()
	var info := {"arrival": str(arrival), "start": [player.global_position.x, player.global_position.y]}
	var bounds: Rect2 = _room_bounds()
	var dir: float = 1.0 if bounds.get_center().x >= player.global_position.x else -1.0
	# Сюжет кімнати, що зупинив героя (LaboratoryOutside: екран кінця демо), — лише у фільмі пускаємо його знову.
	info["movement_was_off"] = player.event
	var camera: Camera2D = player.get_node("Camera2D")
	if camera.top_level:
		push_error("film_rooms: %s starts with the camera detached from the hero" % room_name)
	info["camera_detached"] = camera.top_level
	if player.event:
		player.set_movement_enabled(true)
	phase = "run_out"
	RenderingServer.frame_pre_draw.connect(_sample)
	var start: Vector2 = player.global_position
	info["run_out_px"] = await _run(dir, true)
	var far: Vector2 = player.global_position
	phase = "turn"
	for i in 6: await physics_frame
	phase = "run_back"
	info["run_back_px"] = await _run(-dir, false)
	phase = "stand"
	for i in STAND_FRAMES: await physics_frame
	await process_frame
	RenderingServer.frame_pre_draw.disconnect(_sample)
	info["film_frames"] = [samples[0].frame, samples[-1].frame]
	if not game.map.scene_file_path.ends_with("/%s.tscn" % room_name):
		push_error("film_rooms: the hero left %s for %s" % [room_name, game.map.scene_file_path])
	# Соло на трьох екранах проходу: там, де стоїть (старт і кінець), посередині, на розвороті. Кадри — після фільму.
	var screens: Dictionary = {"stand": await _solo_pass()}
	for spot: String in ["mid", "far"]:
		var at: Vector2 = far if spot == "far" else start.lerp(far, 0.5)
		player.global_position = Vector2(at.x, minf(at.y, player.global_position.y))
		for i in 90: await physics_frame
		screens[spot] = await _solo_pass()
	_write(info, screens)
	print("FILM %s: %d frames, %d planes -> %s" % [room_name, info.film_frames[1] - info.film_frames[0] + 1, planes.size(),
			out_dir])
	quit()


## Перша мітка старту з ARRIVALS, інакше перша SavePoint*, інакше перші двері (*Door*) кімнати.
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
	push_error("film_rooms: no arrival in %s" % path)
	return NodePath(names[0])


## Біг справжньою дією; у першому відрізку — стрибок. Повертає пройдену відстань (px світу).
func _run(dir: float, with_jump: bool) -> float:
	var action: StringName = &"move_right" if dir > 0.0 else &"move_left"
	var player: CharacterBody2D = game.player
	var from_x: float = player.global_position.x
	var still: int = 0
	var last_x: float = from_x
	var bounds: Rect2 = _room_bounds()
	Input.action_press(action)
	for i: int in RUN_FRAMES:
		if with_jump and i == JUMP_AT:
			Input.action_press(&"jump")
		if with_jump and i == JUMP_AT + JUMP_HOLD:
			Input.action_release(&"jump")
		await physics_frame
		still = still + 1 if absf(player.global_position.x - last_x) < 0.5 else 0
		last_x = player.global_position.x
		if i > BLOCKED_FRAMES and still >= BLOCKED_FRAMES and not (with_jump and i < JUMP_AT + JUMP_HOLD):
			break
		var x: float = player.global_position.x
		if (dir < 0.0 and x < bounds.position.x + EDGE_MARGIN) or (dir > 0.0 and x > bounds.end.x - EDGE_MARGIN):
			break
	Input.action_release(action)
	Input.action_release(&"jump")
	return player.global_position.x - from_x


## Межі кімнати у світі (клітинки MetSys).
func _room_bounds() -> Rect2:
	var room: Node2D = game.get_node("/root/MetSys").get_current_room_instance()
	return Rect2(room.global_position, room.get_size())


## Бої лише у фільмі: кожен ворог, щойно зʼявився, вимкнений і схований (тіло виходить з фізики), посилання кімнати
## на нього лишаються живими.
func _freeze_enemies() -> void:
	for enemy: Node in _all(game):
		if is_instance_of(enemy, enemy_script) and enemy.process_mode != Node.PROCESS_MODE_DISABLED:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			(enemy as CanvasItem).visible = false
			frozen_enemies += 1
	if dm.is_dialogue_active():
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()


## Лише у фільмі: зони кімнати (сюжетні тригери, розмови, двері, точки збереження) не реагують на героя — кат-сцена
## чи діалог забрали б у нього керування посеред проходу. Вмикаються ще до _ready кімнати. Фінал демо
## (LaboratoryOutside, D473) заморожений: інакше його твін відчепив би камеру й повів угору.
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


## HUD і весь інший UI: кожен CanvasLayer поза кімнатою.
func _hide_ui(node: Node) -> void:
	for child: Node in node.get_children():
		if child == game.map:
			continue
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
			hidden_ui.append(str(child.get_path()))
		else:
			_hide_ui(child)


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_all(child))
	return out


## План: кожен Parallax2D; кожна дитина кімнати з графікою поза Parallax2D; вузол top_level; усе, що висить на
## камері. Персонажі (гравець, NPC, вороги, супутники) — не план, але в соло-кадрі їх теж ховаємо.
func _collect_planes() -> void:
	var by_root: Dictionary = {}
	var camera: Camera2D = game.player.get_node("Camera2D")
	var order: Dictionary = {}
	for node: Node in _all(game):
		order[node] = order.size()
	for node: Node in _all(game):
		if not _draws(node) or not (node as CanvasItem).is_visible_in_tree() or _in_ui(node):
			continue
		var plane_root: Node = _plane_root(node, camera)
		if plane_root == null:
			continue
		if not by_root.has(plane_root):
			# Порядок малювання: z, потім порядок у дереві.
			var plane := {"node": plane_root, "items": [] as Array[CanvasItem], "kind": _kind(plane_root, camera),
					"z": _abs_z(plane_root), "order": order[plane_root],
					"path": str(game.map.get_path_to(plane_root)) if game.map.is_ancestor_of(plane_root)
							else str(game.get_path_to(plane_root))}
			if plane_root is Parallax2D:
				# Знято зараз: до кінця фільму вузол може звільнитися (ефект).
				var px: Parallax2D = plane_root
				var scale: Vector2 = px.get_global_transform_with_canvas().get_scale()
				plane["parallax"] = {"scroll_scale": [px.scroll_scale.x, px.scroll_scale.y],
						"autoscroll": [px.autoscroll.x, px.autoscroll.y], "repeat_size": [px.repeat_size.x, px.repeat_size.y],
						"period": [absf(px.repeat_size.x * scale.x), absf(px.repeat_size.y * scale.y)]}
			by_root[plane_root] = plane
			planes.append(plane)
		(by_root[plane_root].items as Array[CanvasItem]).append(node as CanvasItem)


## Вузол, що сам щось малює (тригери, мітки й порожні Node2D — ні).
const DRAWING: Array[String] = ["Sprite2D", "AnimatedSprite2D", "TileMapLayer", "Polygon2D", "Line2D", "MeshInstance2D",
		"MultiMeshInstance2D", "CPUParticles2D", "GPUParticles2D", "ColorRect", "TextureRect", "NinePatchRect", "Label",
		"Panel", "RichTextLabel"]
func _draws(node: Node) -> bool:
	if node.get_class() in DRAWING:
		return true
	var script: Script = node.get_script()
	return node is CanvasItem and script != null and script.source_code.contains("func _draw(")


func _in_ui(node: Node) -> bool:
	var n: Node = node
	while n != null and n != game.map:
		if n is CanvasLayer:
			return true
		n = n.get_parent()
	return false


## Корінь плану для вузла або null — персонаж.
func _plane_root(node: Node, camera: Camera2D) -> Node:
	var n: Node = node
	var top: Node = null
	while n != game:
		if n == camera:
			return camera
		if n is CharacterBody2D:
			return null
		if n is Parallax2D:
			return n
		if top == null and n is CanvasItem and (n as CanvasItem).top_level:
			top = n
		if n.get_parent() == game.map:
			return top if top != null else n
		n = n.get_parent()
	return top


func _kind(plane_root: Node, camera: Camera2D) -> String:
	if plane_root == camera:
		return "camera"
	if plane_root is Parallax2D:
		return "parallax"
	if (plane_root as CanvasItem).top_level:
		return "top_level"
	return "room"


## Справжній z вузла: сума відносних z до першого абсолютного.
func _abs_z(node: Node) -> int:
	var z: int = 0
	var n: Node = node
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z


## Кадр зонда: камера, кожен план на екрані, ноги героя проти колізії. Знімаємо перед малюванням — те, що в кадрі.
func _sample() -> void:
	var vp: Viewport = root.get_viewport()
	var canvas: Transform2D = vp.get_canvas_transform()
	var view: Vector2 = vp.get_visible_rect().size
	var center: Vector2 = canvas.affine_inverse() * (view * 0.5)
	var player: CharacterBody2D = game.player
	var feet: Vector2 = _feet(player)
	var pos: Array = []
	for plane: Dictionary in planes:
		if not is_instance_valid(plane.node):  # план, що зник сам (ефект) — стоїть, де був
			pos.append(samples[-1].planes[pos.size()])
			continue
		var o: Vector2 = (plane.node as CanvasItem).get_global_transform_with_canvas().origin
		pos.append([o.x, o.y])
	var gap: Variant = null
	if player.is_on_floor():
		var q := PhysicsRayQueryParameters2D.create(feet - Vector2(0, 8), feet + Vector2(0, 64), player.collision_mask,
				[player.get_rid()])
		var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			gap = (hit.position as Vector2).y - feet.y
	var fs: Vector2 = canvas * feet
	samples.append({"frame": Engine.get_frames_drawn(), "physics": Engine.get_physics_frames(), "phase": phase,
			"cam": [center.x, center.y], "zoom": canvas.get_scale().x, "planes": pos,
			"feet": [feet.x, feet.y], "feet_screen": [fs.x, fs.y], "floor_gap": gap})


## Низ колізії героя у світі.
func _feet(player: CharacterBody2D) -> Vector2:
	var shape_node: CollisionShape2D = player.get_node("CollisionShape2D")
	var rect: Rect2 = shape_node.shape.get_rect()
	return shape_node.global_transform * Vector2(rect.get_center().x, rect.end.y)


## Соло: кожен план сам. Решту ховаємо: предок кореня плану — self_modulate.a = 0 (лише сам вузол), інше — visible =
## false; персонажі теж (шейдер героя не слухає modulate). Два кадри: на чорному і на білому тлі, з них альфа і
## справжній колір (прозорий серпанок не змішується з тлом). Грейд і glow (WorldEnvironment, D233) на час соло
## вимкнені: вони красять і чисте тло, і альфа виходила б хибною — значення плану до грейду. Повертає {номер плану: значення, "feet_screen": …}.
func _solo_pass() -> Dictionary:
	phase = "solo"
	var everything: Array[CanvasItem] = []
	for node: Node in _all(game):
		if node is CanvasItem and not _in_ui(node):
			everything.append(node as CanvasItem)
	# Вузли, що зникають самі (ефекти, спливні числа), за час соло можуть звільнитися — їх пропускаємо.
	var saved_mod: Array[Color] = []
	var saved_vis: Array[bool] = []
	for item: CanvasItem in everything:
		saved_mod.append(item.self_modulate)
		saved_vis.append(item.visible)
	# Що належить якомусь плану (малюючі вузли і корені планів) — у чужому соло ховається; решта — каркас.
	var owner_of: Dictionary = {}
	for p: int in planes.size():
		owner_of[planes[p].node] = p
		for item: Variant in planes[p].items:
			if is_instance_valid(item):
				owner_of[item] = p
	var old_clear: Color = RenderingServer.get_default_clear_color()
	var world_env: WorldEnvironment = game.get_node("WorldEnvironment")
	var env: Environment = world_env.environment
	world_env.environment = null
	var out: Dictionary = {}
	var player: CharacterBody2D = game.player
	var feet_screen: Vector2 = root.get_viewport().get_canvas_transform() * _feet(player)
	var camera: Node = player.get_node("Camera2D")
	var hero_items: Array[CanvasItem] = []
	for node: Node in _all(player):
		if node is CanvasItem and node != camera and not camera.is_ancestor_of(node):
			hero_items.append(node as CanvasItem)
	# Останній «план» — сам герой: де насправді його намальовані ступні відносно колізії.
	for p: int in planes.size() + 1:
		if p < planes.size() and not is_instance_valid(planes[p].node):
			var none := PackedByteArray()
			none.resize(STATS_SIZE.x * STATS_SIZE.y)
			out[p] = {"coverage": 0.0, "mask": none, "gone": true}
			continue
		var plane_root: CanvasItem = planes[p].node if p < planes.size() else player
		var mine: Dictionary = {}
		var items: Array = planes[p].items if p < planes.size() else hero_items
		for item: Variant in items:
			if is_instance_valid(item):
				mine[item] = true
		for i: int in everything.size():
			var item: CanvasItem = everything[i]
			if not is_instance_valid(item):
				continue
			item.self_modulate = saved_mod[i]
			item.visible = saved_vis[i]
			if mine.has(item):
				continue
			if item == plane_root or item.is_ancestor_of(plane_root):
				item.self_modulate = Color(saved_mod[i], 0.0)
			elif owner_of.has(item) or item is CharacterBody2D:
				item.visible = false
		var black: Image = await _grab(Color.BLACK)
		var white: Image = await _grab(Color.WHITE)
		if p == planes.size():
			out["hero_sprite_bottom_px"] = _sprite_bottom(black, white, feet_screen)
		else:
			out[p] = _stats(black, white, feet_screen)
	_occlude(out)
	for i: int in everything.size():
		if is_instance_valid(everything[i]):
			everything[i].self_modulate = saved_mod[i]
			everything[i].visible = saved_vis[i]
	RenderingServer.set_default_clear_color(old_clear)
	world_env.environment = env
	await process_frame
	out["feet_screen"] = [feet_screen.x, feet_screen.y]
	out["hero"] = [player.global_position.x, player.global_position.y]
	return out


## Скільки плану справді видно на екрані: його непрозоре мінус те, що закривають плани, намальовані поверх
## (за z і порядком у дереві). Маски після цього не потрібні.
func _occlude(out: Dictionary) -> void:
	var front: Array[int] = []
	for p: int in planes.size():
		front.append(p)
	front.sort_custom(func(a: int, b: int) -> bool:
		if planes[a].z != planes[b].z:
			return planes[a].z > planes[b].z
		return planes[a].order > planes[b].order)
	var covered := PackedByteArray()
	covered.resize(STATS_SIZE.x * STATS_SIZE.y)
	for p: int in front:
		var mask: PackedByteArray = out[p].mask
		var seen: int = 0
		for i: int in mask.size():
			if mask[i] == 1 and covered[i] == 0:
				seen += 1
				covered[i] = 1
		out[p].visible = float(seen) / float(mask.size())
		out[p].erase("mask")


func _grab(clear: Color) -> Image:
	RenderingServer.set_default_clear_color(clear)
	for i in 3: await process_frame
	return root.get_texture().get_image()


## Середні значення плану (зменшений кадр): покриття, світлота (луma), контраст (σ луми), насиченість (HSV S);
## і верх намальованого під ногами героя (перший непрозорий рядок у стовпцях біля його ніг).
func _stats(black: Image, white: Image, feet_screen: Vector2) -> Dictionary:
	var top: Variant = _painted_top(black, white, feet_screen)
	black.resize(STATS_SIZE.x, STATS_SIZE.y, Image.INTERPOLATE_BILINEAR)
	white.resize(STATS_SIZE.x, STATS_SIZE.y, Image.INTERPOLATE_BILINEAR)
	var sum_w: float = 0.0
	var sum_l: float = 0.0
	var sum_l2: float = 0.0
	var sum_s: float = 0.0
	var covered: int = 0
	var mask := PackedByteArray()
	mask.resize(STATS_SIZE.x * STATS_SIZE.y)
	for y: int in STATS_SIZE.y:
		for x: int in STATS_SIZE.x:
			var b: Color = black.get_pixel(x, y)
			var w: Color = white.get_pixel(x, y)
			var a: float = clampf(1.0 - ((w.r - b.r) + (w.g - b.g) + (w.b - b.b)) / 3.0, 0.0, 1.0)
			if a < 0.02:
				continue
			if a > 0.5:
				covered += 1
				mask[y * STATS_SIZE.x + x] = 1
			var c := Color(minf(b.r / a, 1.0), minf(b.g / a, 1.0), minf(b.b / a, 1.0))
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			sum_w += a
			sum_l += a * l
			sum_l2 += a * l * l
			sum_s += a * c.s
	if covered == 0:
		return {"coverage": 0.0, "mask": mask}
	var mean: float = sum_l / sum_w
	return {"coverage": float(covered) / float(STATS_SIZE.x * STATS_SIZE.y), "value": mean,
			"contrast": sqrt(maxf(0.0, sum_l2 / sum_w - mean * mean)), "saturation": sum_s / sum_w,
			"painted_top_px": top, "mask": mask}


## Перший непрозорий піксель (на 3 рядки поспіль) у п'яти стовпцях біля ніг, від −80 до +80 px екрана; зсув від ніг
## (екранні px, + нижче ніг). null — плану під ногами нема або він суцільний і вище (небо, стіна), а не верх підлоги.
func _painted_top(black: Image, white: Image, feet: Vector2) -> Variant:
	var tops: Array[float] = []
	var from_y: int = maxi(0, int(feet.y) - 80)
	for dx: int in [-16, -8, 0, 8, 16]:
		var x: int = clampi(int(feet.x) + dx, 0, black.get_width() - 1)
		var run: int = 0
		for y: int in range(from_y, mini(black.get_height(), int(feet.y) + 80)):
			var b: Color = black.get_pixel(x, y)
			var w: Color = white.get_pixel(x, y)
			var a: float = 1.0 - ((w.r - b.r) + (w.g - b.g) + (w.b - b.b)) / 3.0
			run = run + 1 if a > 0.5 else 0
			if run == 3:
				if y - 2 > from_y:
					tops.append(float(y - 2) - feet.y)
				break
	if tops.size() < 3:
		return null
	tops.sort()
	return tops[tops.size() / 2]


## <кімната>.layers.json — плани з виміряною швидкістю і соло-значеннями на кожному екрані; <кімната>.probe.json —
## покадровий зонд (лише для налагодження, у git не йде).
## Нижній непрозорий рядок героя у стовпцях біля ніг (екранні px від низу колізії, + нижче).
func _sprite_bottom(black: Image, white: Image, feet: Vector2) -> Variant:
	var bottom: int = -1
	for dx: int in [-16, -8, 0, 8, 16]:
		var x: int = clampi(int(feet.x) + dx, 0, black.get_width() - 1)
		for y: int in range(mini(black.get_height() - 1, int(feet.y) + 80), maxi(0, int(feet.y) - 80), -1):
			var b: Color = black.get_pixel(x, y)
			var w: Color = white.get_pixel(x, y)
			if 1.0 - ((w.r - b.r) + (w.g - b.g) + (w.b - b.b)) / 3.0 > 0.5:
				bottom = maxi(bottom, y)
				break
	return null if bottom < 0 else float(bottom) - feet.y


func _write(info: Dictionary, screens: Dictionary) -> void:
	var film: Array[Dictionary] = samples.filter(func(s: Dictionary) -> bool: return s.phase != "settle")
	var zoom: float = film[0].zoom
	var view: Vector2 = root.get_viewport().get_visible_rect().size
	var layers: Array = []
	for p: int in planes.size():
		var plane: Dictionary = planes[p]
		var entry := {"path": plane.path, "kind": plane.kind, "z": plane.z, "order": plane.order, "items": (plane.items as Array).size(),
				"speed_x": _speed(film, p, 0, zoom), "speed_y": _speed(film, p, 1, zoom), "screens": {}}
		if plane.kind == "camera":
			# Вузол камери — ціль, а не центр кадру (згладжування); пил на ній летить у світових координатах.
			entry.speed_x = null
			entry.speed_y = null
		if plane.has("parallax"):
			for key: String in ["scroll_scale", "autoscroll", "repeat_size"]:
				entry[key] = plane.parallax[key]
		for spot: String in screens:
			entry.screens[spot] = screens[spot][p]
		layers.append(entry)
	var gaps: Array[float] = []
	for s: Dictionary in film:
		if s.floor_gap != null:
			gaps.append(absf(s.floor_gap))
	gaps.sort()
	var spots: Dictionary = {}
	for spot: String in screens:
		spots[spot] = {"feet_screen": screens[spot].feet_screen, "hero": screens[spot].hero,
				"hero_sprite_bottom_px": screens[spot].hero_sprite_bottom_px}
	# Кадрів відео на секунду гри: кадри / фізичні такти (--fixed-fps рушій із аргументів прибирає).
	var fixed: int = roundi(float(Engine.physics_ticks_per_second) * float(film[-1].frame - film[0].frame)
			/ float(film[-1].physics - film[0].physics))
	var data := {"room": room_name, "movie_fps": fixed, "view": [view.x, view.y], "zoom": zoom,
			"hero_z": _abs_z(game.player), "info": info, "screens": spots, "hidden_ui": hidden_ui,
			"frozen_enemies": frozen_enemies,
			"floor_gap_px": {"frames_on_floor": gaps.size(), "median": gaps[gaps.size() / 2] if not gaps.is_empty() else null,
				"max": gaps[-1] if not gaps.is_empty() else null},
			"layers": layers}
	_save("%s/%s.layers.json" % [out_dir, room_name], data)
	_save("%s/%s.probe.json" % [out_dir, room_name], {"planes": layers.map(func(l: Dictionary) -> String: return l.path),
			"frames": film})


func _save(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## Швидкість плану як кратне камери: найменші квадрати screen = a − s·zoom·cam (+ c·t для автоскролу), по осі axis.
## Parallax2D з повтором перескакує на період — розгортаємо. null, якщо камера по цій осі майже не рухалась.
func _speed(film: Array[Dictionary], p: int, axis: int, zoom: float) -> Variant:
	var cams: Array[float] = []
	for s: Dictionary in film:
		cams.append(float(s.cam[axis]))
	if cams.max() - cams.min() < 24.0:
		return null
	var period: float = 0.0
	var drift: bool = false
	if planes[p].has("parallax"):
		period = planes[p].parallax.period[axis]
		drift = planes[p].parallax.autoscroll[axis] != 0.0
	var k: int = 3 if drift else 2
	var m: Array = []
	for i: int in k:
		m.append([0.0, 0.0, 0.0, 0.0])
	var t0: float = float(film[0].physics)
	var shift: float = 0.0
	var last: float = float(film[0].planes[p][axis])
	for s: Dictionary in film:
		var y: float = float(s.planes[p][axis])
		if period > 0.0 and absf(y - last) > period * 0.5:
			shift -= roundf((y - last) / period) * period
		last = y
		var row: Array[float] = [1.0, float(s.cam[axis]) - cams[0], (float(s.physics) - t0) / float(Engine.physics_ticks_per_second)]
		for i: int in k:
			m[i][k] += row[i] * (y + shift)
			for j: int in k:
				m[i][j] += row[i] * row[j]
	var x: Array = _solve(m, k)
	if x.is_empty():
		return null
	return snappedf(-float(x[1]) / zoom, 0.001)


## Гаусс для k×k (стовпець k — права частина).
func _solve(a: Array, k: int) -> Array:
	for c: int in k:
		var best: int = c
		for i: int in range(c + 1, k):
			if absf(a[i][c]) > absf(a[best][c]):
				best = i
		var tmp: Array = a[c]
		a[c] = a[best]
		a[best] = tmp
		if absf(a[c][c]) < 1e-9:
			return []
		for i: int in k:
			if i != c:
				var f: float = a[i][c] / a[c][c]
				for j: int in range(c, k + 1):
					a[i][j] -= f * a[c][j]
	var out: Array = []
	for i: int in k:
		out.append(a[i][k] / a[i][i])
	return out
