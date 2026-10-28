extends SceneTree

## Замір продуктивності (design/performance_plan.md): старт гри, завантаження кімнат, переходи, кадр, відеопамʼять.
## Перезапускати після кожного виправлення й порівнювати з таблицями плану. Потрібне вікно — у --headless немає ні
## кадру, ні відеопамʼяті:
##   Scripts/Tools/godot_locked.sh --path . --resolution 1920x1080 --script res://SampleProject/UI/measure_performance.gd
##   ... -- secs=1 rooms=Canyon,Village      коротші вікна / частина маршруту
##   ... -- attribution                      окремий свіжий процес: власний час load() кожного ресурсу маршруту
## Друкує лише рядки "PERF ..." — читати через grep '^PERF'.
## Кадр міряється без обмеження (vsync off, max_fps 0): з обмеженням 60 кожен кадр 16,7 мс, і ціни не видно.
## cold — перше завантаження в цьому процесі; файловий кеш ОС після попередніх запусків теплий, тож читання з диска
## сюди не входить — для повільного диска дивись "disk MB".

const MAPS := "res://SampleProject/Maps/%s.tscn"
const GAME := "res://SampleProject/Game.tscn"
const BLUR_SHADER := "res://SampleProject/Shaders/depth_blur.gdshader"
## Сюжетний маршрут демо; маркер — куди Game.teleport_to_room() ставить героя.
const ROUTE: Array = [
	["Canyon", ^"Arrival"], ["Village", ^"Arrival"], ["ElderHouse", ^"Arrival"],
	["DesertRoad", ^"Arrival_Start"], ["CityGates", ^"Arrival"], ["City", ^"SavePoint"],
	["MayorHall", ^"Arrival"], ["LabCells", ^"Arrival"], ["Laboratory", ^"SavePoint_Entrance"],
	["LabBoss", ^"Arrival"], ["LaboratoryOutside", ^"Arrival"],
]
## Переходи пішки через східний край (Maps/MapData.txt): [звідки, куди, рядок клітинок від верху кімнати].
const WALKS: Array = [
	["Canyon", "Village", 0], ["DesertRoad", "CityGates", 0], ["CityGates", "City", 0],
	["City", "MayorHall", 0], ["LabCells", "Laboratory", 0], ["Laboratory", "LabBoss", 2],
	["LabBoss", "LaboratoryOutside", 0],
]


## Рядки логу (print, push_warning, push_error): скільки за вікно і які саме.
class LineCounter extends Logger:
	var mutex: Mutex = Mutex.new()
	var lines: int = 0
	var tagging: bool = false
	var tags: Dictionary = {}
	var recent: Array = []  # [мкс, текст] — останні рядки, щоб пік кадру показав, який код у ньому працював

	func _log_message(message: String, _error: bool) -> void:
		var now: int = Time.get_ticks_usec()
		mutex.lock()
		lines += 1
		recent.append([now, message.strip_edges().left(70)])
		if recent.size() > 64:
			recent.pop_front()
		if tagging:
			var tag: String = message.strip_edges().left(60)
			tags[tag] = int(tags.get(tag, 0)) + 1
		mutex.unlock()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		lines += 1
		if tagging:
			var tag: String = ("push: " + (rationale if rationale != "" else code)).left(60)
			tags[tag] = int(tags.get(tag, 0)) + 1
		mutex.unlock()


## Одне вікно кадрів. Кадр ділиться на відрізки: фізика+ввід (до process_frame), process (до frame_pre_draw),
## малювання на CPU разом зі swap (до frame_post_draw); gpu — час кадру на відеокарті (viewport measure).
class Acc:
	var ft: PackedFloat32Array = PackedFloat32Array()
	var pre: float = 0.0
	var steps: int = 0
	var proc: float = 0.0
	var drawc: float = 0.0
	var rcpu: float = 0.0
	var gpu: float = 0.0
	var draw: float = 0.0
	var items: float = 0.0
	var lines: int = 0
	var nodes: int = 0
	var travel: float = 0.0
	var spikes: PackedStringArray = PackedStringArray()

	func total_ms() -> float:
		var t: float = 0.0
		for v: float in ft:
			t += v
		return t

	func worst(k: int) -> PackedFloat32Array:
		var s: PackedFloat32Array = ft.duplicate()
		s.sort()
		s.reverse()
		return s.slice(0, k)

	func line() -> String:
		var n: int = maxi(ft.size(), 1)
		var s: PackedFloat32Array = ft.duplicate()
		s.sort()
		var p99: float = s[mini(int(n * 0.99), s.size() - 1)] if s.size() > 0 else 0.0
		var worst_ms: float = s[s.size() - 1] if s.size() > 0 else 0.0
		return "avg %5.2f p99 %6.2f max %6.2f ms | CPU: physics %4.2f per 60 Hz step, process %4.2f, draw+swap %4.2f (render %4.2f) | gpu %4.2f | draw calls %3.0f, items %3.0f | nodes %4d | log %4.1f/s%s" % [
				total_ms() / n, p99, worst_ms, pre / maxi(steps, 1), proc / n, drawc / n, rcpu / n, gpu / n, draw / n, items / n,
				nodes, lines / maxf(total_ms() / 1000.0, 0.001), "" if spikes.is_empty() else " | spikes " + "; ".join(spikes)]


## Що в дереві: текстури (для відеопамʼяті), що й скільки малюється (для заповнення), хто працює щокадру.
class Scan:
	var nodes: int = 0
	var tex: Dictionary = {}               # RID → Texture2D
	var fill: float = 0.0                  # пікселів екрана за кадр (усі шари разом)
	var par_fill: float = 0.0              # з них шари Parallax2D (задники, передній план)
	var blur_fill: float = 0.0             # з них через depth_blur — 9 вибірок текстури на піксель
	var drawn: int = 0
	var blurred: Array[CanvasItem] = []    # вузли з власним depth_blur — для заміру без нього
	var parallax: Array[CanvasItem] = []
	var lights: int = 0
	var light_nodes: Array[CanvasItem] = []
	var particles: int = 0
	var screen_readers: int = 0
	var proc: Dictionary = {}              # скрипт (P — _process, F — _physics_process) → вузлів

	func vram_mb() -> float:
		var b: float = 0.0
		for rid: RID in tex:
			var t: Texture2D = tex[rid]
			b += t.get_width() * t.get_height() * 4.0  # RGBA8: усі імпорти — Lossless без mipmaps
		return b / 1048576.0

	func megapixels() -> float:
		var p: float = 0.0
		for rid: RID in tex:
			var t: Texture2D = tex[rid]
			p += t.get_width() * t.get_height()
		return p / 1000000.0


var secs: float = 5.0
var only: PackedStringArray = PackedStringArray()
var counter: LineCounter = LineCounter.new()
var acc: Acc = null
var t_frame: int = 0     # process_frame поточного кадру
var t_pre: int = 0
var t_post: int = 0
var last_proc: float = 0.0
var last_draw: float = 0.0
var last_lines: int = 0
var stepped: int = 0
var vp: RID
var game: Node
var dm: Node
var metsys: Node
var bus: Node
var t_game_child: int = 0
var t_game_ready: int = 0
var t_child: int = 0
var t_ready: int = 0
var t_change: int = 0
var t_load_start: int = 0    # заміна кімнати: Game.room_swapping (екран уже чорний, D434) або Game.ready для першої
var load_inst: int = 0       # від t_load_start до входу кімнати в дерево = load() + instantiate()
var t_swap: int = 0          # Game.room_swapping: кінець згасання й фонового довантаження
var ready_marks: Array = []   # [імʼя прямої дитини кімнати, мкс її ready]; [0] — останній вхід у дерево
var textures: Dictionary = {}     # шлях → [ширина, висота, найменший масштаб на екрані, кімнати]
var processing: Dictionary = {}   # скрипт → найбільше вузлів в одній кімнаті
var all_tags: Dictionary = {}


func _initialize() -> void:
	var boot_ms: int = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("secs="):
			secs = arg.trim_prefix("secs=").to_float()
		elif arg.begins_with("rooms="):
			only = arg.trim_prefix("rooms=").split(",")
	OS.add_logger(counter)
	if OS.get_cmdline_user_args().has("attribution"):
		await _attribution()
		OS.remove_logger(counter)
		quit()
		return
	await process_frame
	await process_frame
	metsys = root.get_node("MetSys")
	bus = root.get_node("EventBus")
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	process_frame.connect(_on_frame)
	physics_frame.connect(func() -> void: stepped += 1)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	metsys.room_changed.connect(func(_room: String) -> void: t_change = _us())
	_uncap()
	var p0: int = _us()
	for i: int in 200:
		print("[INFO:Game] Game: Поточна позиція гравця ДО init_room: (1234.5, 678.9)")
	var print_us: float = (_us() - p0) / 200.0
	print("PERF env | %s | %s | %s x%d | window %s, screen %s, canvas %s | engine+autoloads before script %d ms | print() %.0f us/line (%s build)" % [
			RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
			OS.get_processor_name(), OS.get_processor_count(), DisplayServer.window_get_size(),
			DisplayServer.screen_get_size(), root.get_visible_rect().size, boot_ms, print_us,
			"debug" if OS.is_debug_build() else "release"])

	var canyon: Dictionary = await _start()
	for entry: Array in ROUTE:
		var room: String = entry[0]
		if not _wanted(room):
			continue
		var tp: Dictionary = canyon
		if not _in(room):
			tp = await _teleport(room, entry[1])
		await _room(room, tp)
	for w: Array in WALKS:
		if _wanted(w[0]) and _wanted(w[1]):
			await _walk(w[0], w[1], w[2])
	for i: int in range(ROUTE.size() - 1, -1, -1):
		var room: String = ROUTE[i][0]
		if _wanted(room) and not _in(room):
			var tp: Dictionary = await _teleport(room, ROUTE[i][1])
			print("PERF again | %-17s | %s" % [room, _tp_line(tp)])
	var s0: int = _us()
	game.save_game()  # прогін скрипта пише в user://script_run_saves/ (SaveSystem._start_script_run_dir), не в сейви гравця
	print("PERF save  | Game.save_game() %s — runs on every room transition when Settings → auto_save is on (D413, off by default)" % _ms(_us() - s0))
	_summary()
	OS.remove_logger(counter)
	quit()


func _us() -> int:
	return Time.get_ticks_usec()


func _ms(us: int) -> String:
	return "%.1f ms" % (us / 1000.0)


func _mon(m: Performance.Monitor) -> float:
	return Performance.get_monitor(m)


func _wanted(room: String) -> bool:
	return only.is_empty() or only.has(room)


func _in(room: String) -> bool:
	return game.map != null and game.map.scene_file_path == MAPS % room


func _marker(room: String) -> NodePath:
	for entry: Array in ROUTE:
		if entry[0] == room:
			return entry[1]
	return ^"Arrival"


func _uncap() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _on_frame() -> void:
	var now: int = _us()
	if acc != null:
		var ms: float = (now - t_frame) / 1000.0
		acc.ft.append(ms)
		if stepped > 0:
			acc.pre += (now - t_post) / 1000.0
			acc.steps += stepped
		acc.gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		acc.rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		acc.draw += RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		acc.items += RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
				RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		if ms > 20.0 and acc.spikes.size() < 4:
			acc.spikes.append("+%.1fs %.0f ms (process %.0f, draw %.0f, physics+input %.0f, log %d%s)" % [
					acc.total_ms() / 1000.0, ms, last_proc, last_draw, (now - t_post) / 1000.0, counter.lines - last_lines,
					_lines_since(t_frame)])
	stepped = 0
	t_frame = now
	last_lines = counter.lines


## Перші два рядки логу, надруковані від [param since] (мкс) — підказка, чий код зайняв кадр.
func _lines_since(since: int) -> String:
	var out: PackedStringArray = PackedStringArray()
	counter.mutex.lock()
	for e: Array in counter.recent:
		if int(e[0]) >= since and out.size() < 2 and not String(e[1]).begins_with("PERF"):
			out.append(String(e[1]))
	counter.mutex.unlock()
	return "" if out.is_empty() else ": " + " / ".join(out)


func _on_pre_draw() -> void:
	t_pre = _us()
	last_proc = (t_pre - t_frame) / 1000.0
	if acc != null:
		acc.proc += last_proc


func _on_post_draw() -> void:
	t_post = _us()
	last_draw = (t_post - t_pre) / 1000.0
	if acc != null:
		acc.drawc += last_draw


func _begin() -> Acc:
	var a: Acc = Acc.new()
	a.lines = counter.lines
	counter.tagging = true
	acc = a
	return a


func _end(a: Acc) -> void:
	acc = null
	counter.tagging = false
	a.lines = counter.lines - a.lines
	a.nodes = int(_mon(Performance.OBJECT_NODE_COUNT))


func _window(seconds: float) -> Acc:
	_uncap()
	var a: Acc = _begin()
	await create_timer(seconds, true, false, true).timeout
	_end(a)
	return a


## Герой біжить: праворуч чверть вікна, ліворуч половину, праворуч чверть — повертається туди, звідки почав.
func _run(seconds: float) -> Acc:
	_uncap()
	var a: Acc = _begin()
	var x: float = game.player.global_position.x
	var width: float = metsys.get_current_room_instance().get_size().x
	for leg: Array in [[KEY_D, 0.25], [KEY_A, 0.5], [KEY_D, 0.25]]:
		_key(leg[0], true)
		var stop: int = _us() + int(seconds * float(leg[1]) * 1000000.0)
		while _us() < stop:
			await process_frame
			var nx: float = game.player.global_position.x
			a.travel += absf(nx - x)
			x = nx
			if (leg[0] == KEY_D and x > width - 150.0) or (leg[0] == KEY_A and x < 150.0):
				break  # край кімнати — далі був би перехід, а не біг
		_key(leg[0], false)
	_end(a)
	return a


## Той самий кадр без [param items]: без depth_blur ([param blur]) або без шарів Parallax2D.
func _without(items: Array[CanvasItem], blur: bool) -> Acc:
	var saved: Array = []
	for ci: CanvasItem in items:
		saved.append(ci.material if blur else ci.visible)
		if blur:
			ci.material = null
		else:
			ci.visible = false
	var a: Acc = await _window(secs)
	for i: int in items.size():
		if blur:
			items[i].material = saved[i]
		else:
			items[i].visible = saved[i]
	return a


func _key(code: Key, pressed: bool) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _drain() -> void:
	for r: int in 10:
		for i: int in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		for i: int in 10:
			await process_frame
		if not dm.is_dialogue_active():
			return


# ── Старт: головне меню → New Game, як MainMenu.new_game_button_up() ─────────────────────────────────────────────

func _start() -> Dictionary:
	var t0: int = _us()
	var menu_ps: PackedScene = load("res://SampleProject/MainMenu.tscn")
	var t1: int = _us()
	var menu: Node = menu_ps.instantiate()
	var t2: int = _us()
	root.add_child(menu)
	current_scene = menu
	var t3: int = _us()
	await process_frame
	var t4: int = _us()
	print("PERF start | MainMenu.tscn | load %s, instantiate %s, add_child+_ready %s, first frame %s" % [
			_ms(t1 - t0), _ms(t2 - t1), _ms(t3 - t2), _ms(t4 - t3)])
	await create_timer(1.0).timeout

	root.child_entered_tree.connect(_on_root_child)
	var a: Acc = _begin()
	var s0: int = _us()
	menu.new_game_button_up()  # як клік: згасання в чорне → SceneLoader (фоновий load Game.tscn) → кімната → поява (D434)
	var s1: int = _us()
	var entered: Array = [0]
	bus.room_entered.connect(func(_r: String) -> void: entered[0] = _us(), CONNECT_ONE_SHOT)
	var worst_seen: float = 0.0   # найдовший кадр, коли на екрані щось видно
	var worst_black: float = 0.0  # найдовший кадр під повністю чорним екраном
	var last: int = _us()
	while entered[0] == 0 or ScreenFade.is_on(root):
		var black: bool = ScreenFade.is_black(root)
		await process_frame
		var now: int = _us()
		if black:
			worst_black = maxf(worst_black, (now - last) / 1000.0)
		else:
			worst_seen = maxf(worst_seen, (now - last) / 1000.0)
		last = now
	var s3: int = _us()
	var s2: int = entered[0]
	for i: int in 5:
		await process_frame
	_end(a)
	game = current_scene
	game.room_swapping.connect(func() -> void:
		t_swap = _us()
		t_load_start = t_swap)
	var tp: Dictionary = {
		"load_inst": load_inst, "add": t_ready - t_child, "total": s2 - s0,
		"frames": a.worst(3), "lines": a.lines, "ready_top": _ready_top(),
	}
	print("PERF start | New Game → room_entered %s, → light again %s | click frame %s | Game add_child+_ready %s, then _initialize_save_and_room + Canyon load+instantiate %s, add_child+_ready %s | longest frame on screen %.0f ms, under black %.0f ms | longest frames %s | log lines %d" % [
			_ms(s2 - s0), _ms(s3 - s0), _ms(s1 - s0), _ms(t_game_ready - t_game_child), _ms(tp["load_inst"]),
			_ms(tp["add"]), worst_seen, worst_black, _frames(tp["frames"]), a.lines])
	var g0: int = _us()
	var gps: PackedScene = load(GAME)  # залежності вже живі в грі: лише сама сцена
	var g1: int = _us()
	var g: Node = gps.instantiate()
	var g2: int = _us()
	g.free()
	print("PERF start | Game.tscn split | scene-only reload %s, instantiate %s" % [_ms(g1 - g0), _ms(g2 - g1)])
	await _drain()
	game.player.set_invulnerable(true)  # боси й вороги не зупиняють прогін
	return tp


func _on_root_child(n: Node) -> void:
	if n.scene_file_path != GAME:
		return
	t_game_child = _us()
	n.ready.connect(_on_game_ready, CONNECT_ONE_SHOT)
	n.child_entered_tree.connect(_on_game_child)


## Game._ready() відкладає _initialize_save_and_room() → load_room() першої кімнати: з цієї миті й міряємо.
func _on_game_ready() -> void:
	t_game_ready = _us()
	t_load_start = t_game_ready


## Кімната — пряма дитина Game (MetSysGame.load_room): від t_load_start до add_child (load + instantiate) і до ready.
func _on_game_child(n: Node) -> void:
	if not n.scene_file_path.begins_with("res://SampleProject/Maps/"):
		return
	t_child = _us()
	load_inst = t_child - t_load_start
	ready_marks = [["", t_child]]
	n.child_entered_tree.connect(_on_room_child)
	n.ready.connect(_on_room_ready.bind(n), CONNECT_ONE_SHOT)


func _on_room_ready(n: Node) -> void:
	t_ready = _us()
	n.child_entered_tree.disconnect(_on_room_child)


func _on_room_child(c: Node) -> void:
	ready_marks[0][1] = _us()  # останній вхід у дерево ≈ початок фази _ready
	c.ready.connect(func() -> void: ready_marks.append([String(c.name), _us()]), CONNECT_ONE_SHOT)


## Найдорожчі _ready кімнати: піддерево кожної прямої дитини й скрипт самої кімнати (він останній).
func _ready_top() -> String:
	var cost: Array = []
	for i: int in range(1, ready_marks.size()):
		cost.append([ready_marks[i][0], int(ready_marks[i][1]) - int(ready_marks[i - 1][1])])
	if ready_marks.size() > 1 and t_ready > 0:
		cost.append(["(room script)", t_ready - int(ready_marks[ready_marks.size() - 1][1])])
	cost.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var parts: PackedStringArray = PackedStringArray()
	for c: Array in cost.slice(0, 3):
		parts.append("%s %.1f" % [c[0], int(c[1]) / 1000.0])
	return ", ".join(parts)


# ── Кімнати ───────────────────────────────────────────────────────────────────────────────────────────────────────

## Як у грі: Game.teleport_to_room() → load_room(): згасання, фонове довантаження під чорним, instantiate() + add_child(),
## поява (D434). Кімната, якої RoomPreloader ще не тримає, — тут видно ціну її завантаження: "fade+black".
func _teleport(room: String, marker: NodePath) -> Dictionary:
	t_child = 0
	t_ready = 0
	var a: Acc = _begin()
	var t0: int = _us()
	t_swap = 0
	await game.teleport_to_room(MAPS % room, marker)
	var t1: int = _us()
	for i: int in 3:
		await process_frame
	_end(a)
	return {"load_inst": load_inst, "add": t_ready - t_child, "total": t1 - t0, "fade_black": t_swap - t0,
			"after": t1 - t_ready, "frames": a.worst(3), "lines": a.lines, "ready_top": _ready_top(), "spikes": a.spikes}


func _frames(f: PackedFloat32Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for v: float in f:
		parts.append("%.0f" % v)
	return "/".join(parts) + " ms"


func _tp_line(tp: Dictionary) -> String:
	return "fade out+black %s | load+instantiate %s | add_child+_ready %s (slowest: %s) | after ready %s | whole call %s | longest frames %s | log lines %d%s" % [
			_ms(tp.get("fade_black", 0)), _ms(tp["load_inst"]), _ms(tp["add"]), tp.get("ready_top", ""), _ms(tp.get("after", 0)), _ms(tp["total"]),
			_frames(tp["frames"]), tp["lines"], "" if (tp.get("spikes", PackedStringArray()) as PackedStringArray).is_empty()
			else " | spikes " + "; ".join(tp["spikes"] as PackedStringArray)]


## load() кімнати, коли її залежності вже живі (лише сама сцена), load() утриманої сцени й instantiate().
func _split(room: String) -> String:
	var path: String = MAPS % room
	var was_cached: bool = ResourceLoader.has_cached(path)
	var t0: int = _us()
	var ps: PackedScene = load(path)
	var t1: int = _us()
	var held: PackedScene = load(path)
	var t2: int = _us()
	var n: Node = ps.instantiate()
	var t3: int = _us()
	n.free()
	return "scene-only %s%s | held PackedScene %s (same %s) | instantiate %s" % [
			_ms(t1 - t0), " (was cached!)" if was_cached else "", _ms(t2 - t1), held == ps, _ms(t3 - t2)]


func _room(room: String, tp: Dictionary) -> void:
	var split: String = _split(room)
	await _drain()
	await create_timer(0.5, true, false, true).timeout
	var here: String = game.map.scene_file_path.get_file().get_basename()
	var s_room: Scan = Scan.new()
	_scan(game.map, s_room, room)
	var s_all: Scan = Scan.new()
	_scan(root, s_all, "")
	for key: String in s_all.proc:
		processing[key] = maxi(int(processing.get(key, 0)), int(s_all.proc[key]))
	for rid: RID in s_all.tex:
		var t: Texture2D = s_all.tex[rid]
		var key: String = t.resource_path if t.resource_path != "" else "%s (runtime)" % t.get_class()
		var e: Array = textures.get(key, [t.get_width(), t.get_height(), INF, []])
		var where: String = room if s_room.tex.has(rid) else "game"
		if not (e[3] as Array).has(where):
			(e[3] as Array).append(where)
		textures[key] = e
	var screen: float = root.get_visible_rect().get_area()
	print("PERF load  | %-17s | %s | %s" % [room, _tp_line(tp), split])
	print("PERF tex   | %-17s | room: %d textures, %.1f MP, ~%.1f MB VRAM | whole tree %d textures ~%.1f MB | monitors: texture %.0f MB, video %.0f MB | room nodes %d, scene nodes %d%s" % [
			room, s_room.tex.size(), s_room.megapixels(), s_room.vram_mb(), s_all.tex.size(), s_all.vram_mb(),
			_mon(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, _mon(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			s_room.nodes, int(_mon(Performance.OBJECT_NODE_COUNT)), "" if here == room else " | NOW IN %s" % here])
	print("PERF fill  | %-17s | %d items drawn, %.1f MP/frame = %.1f× screen, parallax layers %.1f× | depth_blur %.1f MP = %.1f× screen × 9 taps | parallax layers %d, blurred items %d | lights %d, particles %d, screen readers %d" % [
			room, s_all.drawn, s_all.fill / 1e6, s_all.fill / screen, s_all.par_fill / screen, s_all.blur_fill / 1e6, s_all.blur_fill / screen,
			s_all.parallax.size(), s_all.blurred.size(), s_all.lights, s_all.particles, s_all.screen_readers])
	for i: int in 3:
		await process_frame  # кадр із самим скануванням не входить у вікно
	var idle: Acc = await _window(secs)
	_tags()
	print("PERF frame | %-17s | idle      | %s" % [room, idle.line()])
	var run: Acc = await _run(secs)
	_tags()
	print("PERF frame | %-17s | run       | %s | hero ran %.0f px" % [room, run.line(), run.travel])
	var noblur: Acc = await _without(s_all.blurred, true)
	print("PERF frame | %-17s | -blur     | %s" % [room, noblur.line()])
	var nopar: Acc = await _without(s_all.parallax, false)
	print("PERF frame | %-17s | -parallax | %s" % [room, nopar.line()])
	var world_env: WorldEnvironment = game.get_node(^"WorldEnvironment") as WorldEnvironment
	var env: Environment = world_env.environment
	world_env.environment = null
	var nopost: Acc = await _window(secs)
	world_env.environment = env
	print("PERF frame | %-17s | -post     | %s" % [room, nopost.line()])
	if not s_all.light_nodes.is_empty():
		var nolights: Acc = await _without(s_all.light_nodes, false)
		print("PERF frame | %-17s | -lights   | %s" % [room, nolights.line()])
	# D554: увесь пресет Low (GraphicsQuality) разом; потім назад High.
	var quality: Node = root.get_node("DisplayManager").graphics_quality
	quality.apply("low")
	var low: Acc = await _window(secs)
	quality.apply("high")
	print("PERF frame | %-17s | low       | %s" % [room, low.line()])


func _tags() -> void:
	counter.mutex.lock()
	for tag: String in counter.tags:
		all_tags[tag] = int(all_tags.get(tag, 0)) + int(counter.tags[tag])
	counter.tags.clear()
	counter.mutex.unlock()


func _scan(n: Node, s: Scan, room: String) -> void:
	s.nodes += 1
	if n.is_processing() or n.is_physics_processing():
		var sc: Script = n.get_script() as Script
		var key: String = (sc.resource_path.get_file() if sc != null else n.get_class()) \
				+ (" P" if n.is_processing() else "") + (" F" if n.is_physics_processing() else "")
		s.proc[key] = int(s.proc.get(key, 0)) + 1
	for p: Dictionary in n.get_property_list():
		if int(p["type"]) == TYPE_OBJECT and int(p["usage"]) & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE):
			_tex(n.get(String(p["name"])), s)
	if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
		_draw_cost(n as CanvasItem, s, room)
		if n is Light2D:
			s.lights += 1
			s.light_nodes.append(n as CanvasItem)
		if n is CPUParticles2D or n is GPUParticles2D:
			s.particles += 1
		if n is BackBufferCopy:
			s.screen_readers += 1
	for c: Node in n.get_children():
		_scan(c, s, room)


func _tex(v: Variant, s: Scan) -> void:
	if v is AtlasTexture:
		_tex((v as AtlasTexture).atlas, s)
	elif v is Texture2D:
		s.tex[(v as Texture2D).get_rid()] = v
	elif v is SpriteFrames:
		var sf: SpriteFrames = v as SpriteFrames
		for anim: String in sf.get_animation_names():
			for i: int in sf.get_frame_count(anim):
				_tex(sf.get_frame_texture(anim, i), s)
	elif v is TileSet:
		var ts: TileSet = v as TileSet
		for i: int in ts.get_source_count():
			var src: TileSetSource = ts.get_source(ts.get_source_id(i))
			if src is TileSetAtlasSource:
				_tex((src as TileSetAtlasSource).texture, s)
	elif v is ShaderMaterial:
		var sm: ShaderMaterial = v as ShaderMaterial
		if sm.shader != null:
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				_tex(sm.get_shader_parameter(u["name"]), s)
	elif v is StyleBoxTexture:
		_tex((v as StyleBoxTexture).texture, s)


## Скільки пікселів екрана вкриває вузол цього кадру (з повторами Parallax2D) і чи через depth_blur.
func _draw_cost(ci: CanvasItem, s: Scan, room: String) -> void:
	var vis: Rect2 = root.get_visible_rect()
	var r: Rect2 = Rect2()
	var t: Texture2D = null
	if ci is Sprite2D:
		t = (ci as Sprite2D).texture
		if t != null:
			r = (ci as Sprite2D).get_rect()
	elif ci is AnimatedSprite2D:
		var a: AnimatedSprite2D = ci as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) \
				and a.sprite_frames.get_frame_count(a.animation) > a.frame:
			var ft: Texture2D = a.sprite_frames.get_frame_texture(a.animation, a.frame)
			if ft != null:
				var sz: Vector2 = ft.get_size()
				r = Rect2(a.offset - (sz * 0.5 if a.centered else Vector2.ZERO), sz)
	elif ci is TextureRect or ci is NinePatchRect or ci is ColorRect or ci is Panel:
		r = Rect2(Vector2.ZERO, (ci as Control).size)
	var area: float = 0.0
	if ci is TileMapLayer:
		area = _tiles_area(ci as TileMapLayer, vis)
	elif r.has_area():
		area = _area(ci, r, vis)
	if area <= 0.0:
		return
	s.fill += area
	s.drawn += 1
	var m: Material = _material(ci)
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var sh: Shader = (m as ShaderMaterial).shader
		if sh.resource_path == BLUR_SHADER:
			s.blur_fill += area
			if ci.material != null:
				s.blurred.append(ci)
		if sh.code.contains("hint_screen_texture"):
			s.screen_readers += 1
	var par: Parallax2D = _parallax(ci)
	if par != null:
		s.par_fill += area
		if not s.parallax.has(par):
			s.parallax.append(par)
	if t != null and room != "" and t.resource_path != "":
		var e: Array = textures.get(t.resource_path, [t.get_width(), t.get_height(), INF, []])
		e[2] = minf(float(e[2]), absf(ci.get_global_transform_with_canvas().get_scale().x))
		textures[t.resource_path] = e


func _area(ci: CanvasItem, r: Rect2, vis: Rect2) -> float:
	var sr: Rect2 = ci.get_global_transform_with_canvas() * r
	var par: Parallax2D = _parallax(ci)
	if par == null or par.repeat_size == Vector2.ZERO:
		return sr.intersection(vis).get_area()
	# Повтори Parallax2D малюються як repeat_times + 1 копій із кроком repeat_size, від -(repeat_times / 2).
	var step: Vector2 = par.get_global_transform_with_canvas().basis_xform(par.repeat_size)
	var from: int = -int(par.repeat_times * 0.5)
	var total: float = 0.0
	for k: int in range(from, from + par.repeat_times + 1):
		total += Rect2(sr.position + step * k, sr.size).intersection(vis).get_area()
	return total


func _tiles_area(t: TileMapLayer, vis: Rect2) -> float:
	if t.tile_set == null:
		return 0.0
	var xf: Transform2D = t.get_global_transform_with_canvas()
	var tile: Vector2 = Vector2(t.tile_set.tile_size)
	var one: float = (xf * Rect2(-tile * 0.5, tile)).get_area()
	var n: int = 0
	for c: Vector2i in t.get_used_cells():
		if vis.has_point(xf * t.map_to_local(c)):
			n += 1
	return n * one


func _material(ci: CanvasItem) -> Material:
	var c: CanvasItem = ci
	while c != null and c.material == null and c.use_parent_material:
		c = c.get_parent() as CanvasItem
	return c.material if c != null else null


func _parallax(n: Node) -> Parallax2D:
	var p: Node = n
	while p != null:
		if p is Parallax2D:
			return p as Parallax2D
		p = p.get_parent()
	return null


# ── Переходи пішки: герой біжить через східний край, далі MetSys → FadeRoomTransitions → load_room ─────────────────

func _walk(from: String, to: String, row: int) -> void:
	if not _in(from):
		await _teleport(from, _marker(from))
		await _drain()
		await create_timer(0.3, true, false, true).timeout
	var cell: Vector2 = metsys.settings.in_game_cell_size
	var size: Vector2 = metsys.get_current_room_instance().get_size()
	var body: CharacterBody2D = game.player as CharacterBody2D
	var x: float = size.x - 40.0
	await physics_frame
	var ex: Array[RID] = [body.get_rid()]
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			Vector2(x, row * cell.y + 8.0), Vector2(x, (row + 1) * cell.y - 8.0), body.collision_mask, ex)
	var hit: Dictionary = body.get_world_2d().direct_space_state.intersect_ray(q)
	var y: float = (row + 0.5) * cell.y
	if not hit.is_empty():
		var hp: Vector2 = hit["position"]
		y = hp.y - 48.0
	game.place_player(Vector2(x, y))
	for i: int in 20:
		await physics_frame
	t_change = 0
	t_swap = 0
	t_child = 0
	t_ready = 0
	_uncap()
	var a: Acc = _begin()
	var t0: int = _us()
	var how: String = "walked"
	_key(KEY_D, true)
	while t_change == 0 and _us() - t0 < 2500000:
		await process_frame
	if t_change == 0:
		how = "nudged across the edge"
		body.global_position.x = size.x + 8.0
		while t_change == 0 and _us() - t0 < 4000000:
			await process_frame
	_key(KEY_D, false)
	var t1: int = _us()
	while _us() - t1 < 1500000:  # 0,25 с згасання + 0,25 с появи (D434) + init_room
		await process_frame
	_end(a)
	var slow: int = 0
	for v: float in a.ft:
		if v > 33.0:
			slow += 1
	var now_in: String = game.map.scene_file_path.get_file().get_basename()
	print("PERF walk  | %-17s → %-17s | %s | cell change → swap (fade out+black) %s, swap → room ready %s | load+instantiate %s, add_child+_ready %s (slowest: %s) | longest frames %s, frames > 33 ms: %d | log lines %d%s%s" % [
			from, to, how, _ms(t_swap - t_change) if t_swap > 0 else "never", _ms(t_ready - t_swap) if t_swap > 0 else "never", _ms(load_inst),
			_ms(t_ready - t_child), _ready_top(), _frames(a.worst(3)), slow, a.lines, "" if now_in == to else " | NOW IN %s" % now_in,
			"" if a.spikes.is_empty() else " | spikes " + "; ".join(a.spikes)])
	await _drain()


# ── Підсумки ──────────────────────────────────────────────────────────────────────────────────────────────────────

func _summary() -> void:
	var keys: Array = textures.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(textures[a][0]) * int(textures[a][1]) > int(textures[b][0]) * int(textures[b][1]))
	for key: String in keys.slice(0, 15):
		var e: Array = textures[key]
		var cf: ConfigFile = ConfigFile.new()
		var mode: String = "?"
		if cf.load(key + ".import") == OK:
			mode = "compress %s mipmaps %s size_limit %s" % [cf.get_value("params", "compress/mode", "?"),
					cf.get_value("params", "mipmaps/generate", "?"), cf.get_value("params", "process/size_limit", "?")]
		var scale: String = "%.2f px/texel" % float(e[2]) if float(e[2]) < INF else "not a visible Sprite2D"
		print("PERF bigtex | %5dx%-5d %5.1f MB | on screen %s | %s | %s | %s" % [e[0], e[1],
				int(e[0]) * int(e[1]) * 4.0 / 1048576.0, scale, mode, key.trim_prefix("res://SampleProject/"),
				",".join(PackedStringArray(e[3]))])
	var procs: Array = processing.keys()
	procs.sort_custom(func(a: String, b: String) -> bool: return int(processing[a]) > int(processing[b]))
	var parts: PackedStringArray = PackedStringArray()
	for key: String in procs.slice(0, 14):
		parts.append("%s ×%d" % [key, processing[key]])
	print("PERF proc  | nodes with _process (P) / _physics_process (F), whole tree, most in one room: %s" % ", ".join(parts))
	var tags: Array = all_tags.keys()
	tags.sort_custom(func(a: String, b: String) -> bool: return int(all_tags[a]) > int(all_tags[b]))
	for tag: String in tags.slice(0, 8):
		print("PERF log   | %5d × %s" % [all_tags[tag], tag])


## Хто з’їдає час load() (окремий процес: -- attribution). Кожен ресурс вантажиться окремо, від листків до сцени,
## тож його час — лише його власний: розбір сцени, компіляція скрипту, декодування текстури, звук. Порядок як у грі:
## головне меню, Game.tscn (герой, HUD), далі кімнати маршруту; спільне з попередніми вже в памʼяті й не входить.
## Окремий процес, бо скомпільовані скрипти лишаються в кеші до кінця процесу: після прогону гри їх уже не видно.
func _attribution() -> void:
	var held: Dictionary = {}
	var own: Dictionary = {}  # шлях → [мс, клас, байт на диску, сцена]
	var scenes: Array = [["MainMenu", ["res://SampleProject/MainMenu.tscn"]], ["Game", [GAME]]]
	for entry: Array in ROUTE:
		if _wanted(entry[0]):
			scenes.append([entry[0], [MAPS % entry[0]]])
	# Ворогів спавнер вантажить за шляхом при першій появі (EnemySpawnPoint.gd), поза залежностями кімнати.
	scenes.append(["Enemies", []])
	for sc: Array in scenes:
		var name: String = sc[0]
		var paths: Array = sc[1]
		if name == "Enemies":  # шляхи — коли кімнати вже скомпілювали EnemySpawnPoint.gd
			var spawn: GDScript = load("res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
			paths = (spawn.get_script_constant_map()["ENEMY_SCENES"] as Dictionary).values()
		var seen: Dictionary = {}
		for path: String in paths:
			_load_tree(path, name, held, own, seen)
		var disk: int = 0
		for p: String in seen:
			disk += _disk_bytes(p)
		var mine: float = 0.0
		var mine_disk: int = 0
		var scripts: float = 0.0
		var textures_ms: float = 0.0
		for p: String in own:
			if own[p][3] == name:
				mine += float(own[p][0])
				mine_disk += int(own[p][2])
				if own[p][1] == "GDScript":
					scripts += float(own[p][0])
				elif own[p][1] == "CompressedTexture2D":
					textures_ms += float(own[p][0])
		print("PERF disk  | %-17s | %3d files, %5.1f MB on disk incl. shared | new for this scene: %5.1f MB, own load %6.1f ms (scripts %5.1f, textures %5.1f)" % [
				name, seen.size(), disk / 1048576.0, mine_disk / 1048576.0, mine, scripts, textures_ms])
	var by_type: Dictionary = {}
	for p: String in own:
		var e: Array = by_type.get(own[p][1], [0.0, 0, 0])
		e[0] = float(e[0]) + float(own[p][0])
		e[1] = int(e[1]) + 1
		e[2] = int(e[2]) + int(own[p][2])
		by_type[own[p][1]] = e
	var types: Array = by_type.keys()
	types.sort_custom(func(a: String, b: String) -> bool: return float(by_type[a][0]) > float(by_type[b][0]))
	for ty: String in types:
		print("PERF type  | %-24s | %4d files | %7.1f ms | %6.1f MB on disk" % [ty, by_type[ty][1], by_type[ty][0],
				int(by_type[ty][2]) / 1048576.0])
	var paths: Array = own.keys()
	paths.sort_custom(func(a: String, b: String) -> bool: return float(own[a][0]) > float(own[b][0]))
	for p: String in paths.slice(0, 30):
		print("PERF res   | %6.1f ms | %-22s | %5.2f MB | %-10s | %s" % [own[p][0], own[p][1], int(own[p][2]) / 1048576.0,
				own[p][3], p.trim_prefix("res://")])


func _load_tree(path: String, room: String, held: Dictionary, own: Dictionary, seen: Dictionary) -> void:
	if seen.has(path):
		return
	seen[path] = true
	for d: String in ResourceLoader.get_dependencies(path):
		var dp: String = d.get_slice("::", 2)
		_load_tree(dp if dp != "" else d.get_slice("::", 0), room, held, own, seen)
	if held.has(path) or ResourceLoader.has_cached(path):
		return
	var t0: int = _us()
	var r: Resource = load(path)
	var ms: float = (_us() - t0) / 1000.0
	held[path] = r
	own[path] = [ms, r.get_class() if r != null else "?", _disk_bytes(path), room]


## Байт, які load() читає з диска: для імпортованого — файл у .godot/imported, інакше сам файл.
func _disk_bytes(path: String) -> int:
	var file: String = path
	if FileAccess.file_exists(path + ".import"):
		var cf: ConfigFile = ConfigFile.new()
		if cf.load(path + ".import") == OK:
			file = String(cf.get_value("remap", "path", path))
	var f: FileAccess = FileAccess.open(file, FileAccess.READ)
	return f.get_length() if f != null else 0
