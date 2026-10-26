extends SceneTree

## Кожна підказка — раз за проходження, за першої нагоди (D727; Sapega, 2026-10-26: «тільки один раз за гру це
## вискакує, коли перший раз зустрічається, так само і WASD»), і три «?» про колір відблиску ворога (D725, D504):
##   1. New Game: the WASD (movement) «?» once.
##   2. Each glint colour on an enemy in view — white, yellow, red — gives its «?» once (block / parry / dodge, the
##      button from the input map); the same colour again, or a glint off screen, gives none.
##   3. A room reload: none of them again.
##   4. Save (slot 2), a new tip after the save (first kill), death → Game Over → Resume: the hero is back at the save,
##      nothing seen comes back, the first-kill tip included.
##   5. Load an earlier save of the same playthrough (slot 1, made right after New Game): nothing comes back.
##   6. A new session (the in-memory record gone) loading that earlier save: what later saves of the playthrough saw
##      stays seen.
##   7. New Game starts fresh: the WASD «?» shows again.
## Пише лише в user://verify_tips_once/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_tips_once.gd

const TEST_DIR := "user://verify_tips_once/"
const TELLS := {&"block": "tell_block", &"parry": "tell_parry", &"dodge": "tell_dodge"}

var fails: Array[String] = []
var game: Node
var tray: Node
var sl: Node


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _boot(new_game: bool, save_path: String = "") -> void:
	set_meta("start_new_game", new_game)
	if save_path != "":
		set_meta("save_file_path", save_path)
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _settle()


## Нова сцена Game (завантаження, Resume після смерті): чекаємо, доки її кімната готова й діалоги пройдено.
func _settle() -> void:
	for i in 60: await physics_frame
	var dm: Node = sl.get_dialogue_manager()
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	tray = get_first_node_in_group(&"tip_tray")
	await create_timer(2.5).timeout  # тема руху — за 2 с після входу (TipTray.MOVEMENT_DELAY)


func _seen() -> Array:
	return sl.get_game_manager().player_state.seen_tutorials


## Ворог за [param dx] px від героя (−140 — у кадрі: у Canyon камера впирається в межу, герой праворуч); стоїть (process вимкнено), відблиск — тим самим шляхом, що й замах.
func _enemy(dx: float) -> Node2D:
	var enemy: Node2D = load("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn").instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	game.map.add_child(enemy)
	enemy.global_position = game.player.global_position + Vector2(dx, 0)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	return enemy


func _glint(enemy: Node, kind: StringName) -> void:
	enemy.enemy_logic.tell_kind = kind
	enemy._on_logic_attack_telegraphed()


## Усі три кольори на ворогові в кадрі; повертає «?», що зʼявились.
func _all_glints() -> Array[String]:
	tray.clear()
	var enemy := _enemy(-140.0)
	if not enemy.get_viewport_rect().has_point(enemy.get_global_transform_with_canvas().origin):
		ck(false, "the glint enemy is out of view (%s)" % enemy.get_global_transform_with_canvas().origin)
	for kind in TELLS:
		_glint(enemy, kind)
	await process_frame
	var out: Array[String] = tray.ids().duplicate()
	enemy.queue_free()
	return out


func _initialize() -> void:
	await process_frame
	await process_frame
	sl = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var save_system: Node = root.get_node("SaveSystem")
	save_system.set_save_dir(TEST_DIR)
	save_system.settings_module.settings.hints = true
	root.size = Vector2i(1920, 1080)

	print("[1] New Game: the WASD tip once")
	save_system.set_current_slot(1)
	await _boot(true)
	ck(_seen() == ["movement"] and tray.ids() == ["movement"], "movement «?» (%s, %s)" % [_seen(), tray.ids()])
	var playthrough: String = sl.get_game_manager().player_state.playthrough_id
	ck(playthrough != "", "the playthrough has an id (%s)" % playthrough)
	tray.clear()
	ck(game.save_game(), "an earlier save in slot 1 (only movement seen)")

	print("[2] D725: each glint colour in view gives its «?» once")
	var far := _enemy(4000.0)
	_glint(far, &"parry")
	await process_frame
	ck(tray.ids().is_empty() and not "tell_parry" in _seen(), "a glint off screen gives none (%s)" % [tray.ids()])
	far.queue_free()
	var enemy := _enemy(-140.0)
	ck(enemy.get_viewport_rect().has_point(enemy.get_global_transform_with_canvas().origin), "the enemy is in view")
	for kind: StringName in TELLS:
		_glint(enemy, kind)
		await process_frame
		ck(tray.has(TELLS[kind]), "%s glint → «?» %s" % [kind, TELLS[kind]])
	enemy.queue_free()
	var topics: GDScript = load("res://SampleProject/Scripts/UI/tutorial_topics.gd")
	var keys := {"tell_block": "Hold Ctrl", "tell_parry": "Tap Ctrl", "tell_dodge": "with Shift"}
	for id: String in keys:
		var text: String = topics.resolved(topics.by_id(id)).text
		ck(text.contains(keys[id]), "%s names its button from the input map (%s)" % [id, text])
	ck(await _all_glints() == [], "the same colours again: none")

	print("[3] A room reload")
	var room: String = game.map.scene_file_path
	await game.teleport_to_room(room, ^"Arrival")
	for i in 30: await physics_frame
	ck(await _all_glints() == [] and tray.ids().is_empty(), "no tip comes back after the room reloads")

	print("[4] Save, a new tip, death → Resume from the save")
	save_system.set_current_slot(2)
	ck(game.save_game(), "saved in slot 2")
	root.get_node("EventBus").enemy_died.emit("e0", Vector2.ZERO)
	await process_frame
	ck(tray.ids() == ["first_kill"], "first kill after the save → its «?» (%s)" % [tray.ids()])
	var seen_now: Array = _seen().duplicate()
	game.player.die()
	var screen: Node = null
	for i in 120:
		screen = get_first_node_in_group(&"game_over_screen")
		if screen != null:
			break
		await process_frame
	ck(screen != null, "the Game Over screen is up")
	screen.resume()
	ck(screen.last_action == "load", "Resume takes the save path (%s)" % screen.last_action)
	for i in 200:
		if current_scene != game and current_scene != null and current_scene.is_node_ready():
			break
		await process_frame
	ck(current_scene != game, "Resume loaded the save (a new Game scene)")
	game = current_scene
	await _settle()
	ck(tray.ids().is_empty(), "no «?» after the reload, not movement nor first kill (%s)" % [tray.ids()])
	ck(seen_now.all(func(id: String) -> bool: return id in _seen()), "everything seen before the death stays seen (%s)" % [_seen()])
	ck(await _all_glints() == [], "glint tips do not come back after the death")

	print("[5] Load an earlier save of the same playthrough")
	ck(game.save_game(), "the player saves in slot 2 again (after the death)")
	game.queue_free()
	for i in 4: await process_frame
	save_system.set_current_slot(1)
	await _boot(false, save_system.get_slot_path(1))
	ck(sl.get_game_manager().player_state.playthrough_id == playthrough, "slot 1 is the same playthrough")
	ck(tray.ids().is_empty() and "first_kill" in _seen(), "nothing comes back (%s, seen %s)" % [tray.ids(), _seen()])
	ck(await _all_glints() == [], "no glint tips")

	print("[6] A new session loading the earlier save")
	game.queue_free()
	for i in 4: await process_frame
	sl.get_game_manager().get_node(^"PlayerStateManager").reset_player_state()  # процес гри почався наново
	await _boot(false, save_system.get_slot_path(1))
	ck(tray.ids().is_empty() and "first_kill" in _seen() and "tell_dodge" in _seen(),
			"what slot 2 saw stays seen (%s, seen %s)" % [tray.ids(), _seen()])
	ck(await _all_glints() == [], "no glint tips")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_system.get_player_data_path(1)))
	ck(saved.player.playthrough_id == playthrough and saved.player.seen_tutorials == ["movement"],
			"the record is one list in the save, with the playthrough (%s)" % [saved.player.seen_tutorials])

	print("[7] New Game starts fresh")
	game.queue_free()
	for i in 4: await process_frame
	save_system.set_current_slot(3)
	await _boot(true)
	ck(sl.get_game_manager().player_state.playthrough_id != playthrough, "a new playthrough")
	ck(_seen() == ["movement"] and tray.ids() == ["movement"], "the WASD «?» shows again (%s)" % [tray.ids()])
	ck((await _all_glints()).size() == 3, "and the glint tips again")

	game.queue_free()
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
