extends SceneTree

## Самоперевірка B149: меню гри відкривається, поки RoomPreloader у фоні вантажить кімнати й сцени SceneWarmer'а, —
## і гра не зависає. Тест навмисно НЕ чекає room_preloader.busy() перед відкриттям меню.
##   godot --headless --path . --script res://SampleProject/UI/verify_menu_after_room_change.gd
##
## Корінь B149: preload() сцени вантажить її під час компіляції скрипта, а компіляція тримає спільний замок кешу
## GDScript. Якщо в тій сцені є ресурс, який саме вантажить фоновий потік, головний потік чекає на потік, а потік —
## на замок, щоб скомпілювати скрипти того ресурсу. [1] перевіряє правило статично, [2] і [3] — у грі.

const Kit := preload("res://SampleProject/UI/input_kit.gd")
const MAPS := "res://SampleProject/Maps/%s.tscn"
const MENU_STATE := "res://SampleProject/Scenes/UI/States/game_menu_state.tscn"
## Спільна тема: UIRoot вантажить її на старті й тримає (D134), тож у фоні вона ніколи не вантажиться.
const THEME := "res://SampleProject/UI/Themes/GameUITheme.tres"
const SHOP := "res://SampleProject/Scenes/Shop/shop_menu.tscn"
## Кімнати з міткою Arrival, далекі одна від одної: кожен перехід лишає preloader'у нових сусідів.
## Без кімнат, що самі запускають кат-сцену (LabCells, MayorHall: під діалогом меню не відкривається взагалі;
## LaboratoryOutside: кінець демо).
const ROUTE: Array[String] = ["Village", "LizardCave", "ElderHouse", "MesaClimb", "BanditCamp", "GatehouseCellar",
		"CityGates", "DragonMural", "Canyon", "Village", "MesaClimb", "LizardCave", "CityGates", "BanditCamp", "Canyon"]

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var _deps: Dictionary = {}       # шлях → його прямі залежності (для .gd — preload і extends)
var _closures: Dictionary = {}   # шлях → усе, що він тягне (Dictionary як множина)


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	var game: Node = await Kit.boot(self)
	game.player.set_invulnerable(true)
	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()

	print("[2] The first opening of the game menu while the shop (warm-up, shares base_menu with the menu) loads")
	# Крамницю відпускаємо й просимо знову: перше відкриття меню йде саме тоді, коли воркер її вантажить.
	game.room_preloader.held.erase(SHOP)
	await Kit.frames(self, 2)
	ck(not ResourceLoader.has_cached(SHOP), "the shop scene is out of the cache")
	game.room_preloader.request(SHOP)
	ck(game.room_preloader.busy(), "the preloader is loading the shop when the menu opens")
	ck(await _open_skills(ui), "the game menu and its Skills tab opened")
	ck(await _held_within(game, SHOP, 10.0), "the shop finished loading in the background too")
	ui.close_game_menu()
	await Kit.frames(self, 2)

	print("[1] No script preloads a scene that shares a scripted scene with the background loads")
	var background: Array[String] = game.scene_warmer.paths()
	for file: String in DirAccess.get_files_at("res://SampleProject/Maps"):
		if file.ends_with(".tscn"):
			background.append("res://SampleProject/Maps/" + file)
	var bg_set: Dictionary = {}
	for path: String in background:
		bg_set.merge(_closure(path))
	# Сцена меню вантажиться при відкритті (B149), тож її дерево треба обійти окремо.
	var menu_set: Dictionary = _closure(MENU_STATE).duplicate()
	menu_set.merge(_closure(GameMenuState.GAME_MENU_SCENE_PATH))
	var menu_bad: Array[String] = _compile_time_collisions(menu_set, bg_set)
	ck(menu_bad.is_empty(), "the game menu's scripts (%d files): no preload shares a scene with %d background paths %s"
			% [menu_set.size(), background.size(), menu_bad])
	var bg_bad: Array[String] = _compile_time_collisions(bg_set, menu_set)
	ck(bg_bad.is_empty(), "the background scenes' scripts: no preload shares a scene with the game menu %s" % [bg_bad])

	print("[3] %d room changes, the game menu (Skills tab) opened at once after each" % ROUTE.size())
	var busy_at_open := 0
	var opened := 0
	for room: String in ROUTE:
		# Як гравець, що тисне меню, щойно кімната з'явилась: кімната вже нова (room_loaded → preloader просить її
		# сусідів), екран ще світлішає.
		game.teleport_to_room(MAPS % room, ^"Arrival")
		while game.map == null or game.map.scene_file_path != MAPS % room:
			await process_frame
		if game.room_preloader.busy():
			busy_at_open += 1
		if await _open_skills(ui):
			opened += 1
		else:
			print("    the menu did not open after %s" % room)
		ui.close_game_menu()
		if game.room_changing:
			await game.room_change_finished
		await Kit.frames(self, 2)
	ck(opened == ROUTE.size(), "the menu and its Skills tab opened after every change (%d / %d)" % [opened, ROUTE.size()])
	ck(busy_at_open >= ROUTE.size() / 2, "the preloader was still loading at most of the openings (%d / %d)"
			% [busy_at_open, ROUTE.size()])

	# Тест не має лишати фонові потоки при виході (як verify_main_menu).
	while game.room_preloader.busy():
		await process_frame
	print("")
	print("RESULT: ALL PASS" if fails.is_empty() else "RESULT: %d FAIL" % fails.size())
	quit()


func _held_within(game: Node, path: String, secs: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		if game.room_preloader.is_held(path):
			return true
		await process_frame
	return false


func _open_skills(ui: Node) -> bool:
	ui.open_game_menu()
	await process_frame
	var menu: Node = get_first_node_in_group(&"game_menu")
	if menu == null:
		return false
	menu.switch_to_tab("Skills")
	await process_frame
	return menu.find_child("SkillsComponent", true, false) != null and ui.current_state_name == "GameMenuState"


## Скрипти з [param scripts_from], що preload'ять не-скрипт, у якому є сцена чи ресурс зі скриптом зі [param other].
## preload іншого скрипта не рахується: він іде через кеш GDScript, а не через завантаження ресурсу.
func _compile_time_collisions(scripts_from: Dictionary, other: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for path: String in scripts_from:
		if not path.ends_with(".gd"):
			continue
		for dep: String in _direct(path):
			if not (dep.ends_with(".tscn") or dep.ends_with(".tres")):
				continue
			for shared: String in _closure(dep):
				if shared != THEME and other.has(shared) and (shared.ends_with(".tscn") or shared.ends_with(".tres")) \
						and _closure(shared).keys().any(func(p: String) -> bool: return p.ends_with(".gd")):
					out.append("%s → %s → %s" % [path.get_file(), dep.get_file(), shared.get_file()])
					break
	return out


func _direct(path: String) -> Array[String]:
	if _deps.has(path):
		return _deps[path]
	var out: Array[String] = []
	if path.ends_with(".gd"):
		# ResourceLoader.get_dependencies() не бачить preload у GDScript — читаємо джерело.
		var source: String = FileAccess.get_file_as_string(path)
		var re := RegEx.create_from_string("(?m)(?:preload\\(|^extends\\s+)\"([^\"]+)\"")
		for m: RegExMatch in re.search_all(source):
			var ref: String = m.get_string(1)
			out.append(ResourceUID.get_id_path(ResourceUID.text_to_id(ref)) if ref.begins_with("uid://") else ref)
		_deps[path] = out
		return out
	for dep: String in ResourceLoader.get_dependencies(path):
		var parts: PackedStringArray = dep.split("::")
		var dep_path: String = parts[parts.size() - 1] if parts[parts.size() - 1].begins_with("res://") else parts[0]
		if dep_path.begins_with("uid://"):
			dep_path = ResourceUID.get_id_path(ResourceUID.text_to_id(dep_path))
		if dep_path.begins_with("res://"):
			out.append(dep_path)
	_deps[path] = out
	return out


func _closure(start: String) -> Dictionary:
	if _closures.has(start):
		return _closures[start]
	var seen: Dictionary = {}
	var stack: Array[String] = [start]
	while not stack.is_empty():
		var path: String = stack.pop_back()
		if seen.has(path):
			continue
		seen[path] = true
		stack.append_array(_direct(path))
	_closures[start] = seen
	return seen
