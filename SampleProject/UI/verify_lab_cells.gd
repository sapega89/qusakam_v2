extends SceneTree

## Камери лабораторії (queue row 9.5, D304, D305, D462): справжній ввід.
## Телепорт із зали мера → кат-сцена камер грає раз: Алісию ведуть до столу без кішки (B126), алхімік і камери
## реагують на крик, джина й вибухи (D460); пропуск (утримання Tab) закінчується в тому самому стані, що й
## повний перегляд. Герой виходить із камери (move_right) → Малік підходить першим, одна розмова знайомства (D462),
## завдання malik_escort, три асисти разом;
## пропуск (утримання геймпада Y) — той самий стан. Асист кличе справжня клавіша F. Завантаження сейва лише з прапорцями
## (B53) починає з потрібного біту. Двері на схід ведуть у коридори (move_right).
##   godot --headless --path . --script res://SampleProject/UI/verify_lab_cells.gd

const CELLS := "res://SampleProject/Maps/LabCells.tscn"
const CORRIDORS := "res://SampleProject/Maps/Laboratory.tscn"
const TEST_DIR := "user://verify_lab_cells/"
const TEST_SLOT := 1
const CELLS_TALKS: Array[String] = ["Lab_Cells_Arrival", "Lab_Cells_Injection", "Lab_Cells_Prisoner",
		"Lab_Cells_Djinn", "Lab_Cells_Faint", "Lab_Cells_Awake"]
const MEET_TALKS: Array[String] = ["Lab_Acquaintance"]
## Хто реагує в кат-сцені камер (D460).
const REACTORS: Array[String] = ["Scientist", "CompanionNPC_astrit", "CompanionNPC_alisia", "CompanionNPC_urizen", "Malik"]
const UNLOCKS: Array[String] = ["lab_companion_01_complete", "lab_companion_02_complete", "lab_companion_03_complete"]

var fails: Array[String] = []
var game: Node
var dm: Node
var sl: Node
var started: Array[String] = []
var assists: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _drain() -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _key(code: Key, pressed: bool) -> InputEvent:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev

func _pad_y(pressed: bool) -> InputEvent:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_Y
	ev.pressed = pressed
	return ev

func _boot(save_path: String) -> void:
	started.clear()  # до старту: розмова, що почалась під час завантаження, теж рахується
	if save_path.is_empty():
		set_meta("start_new_game", true)
	else:
		set_meta("save_file_path", save_path)
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame

func _cells() -> Node:
	return game.map if game.map != null and game.map.scene_file_path == CELLS else null

func _state() -> String:
	return _cells().get_current_state_name() if _cells() else "-"

func _hud_visible() -> bool:
	return (game.get_node(^"UI") as CanvasLayer).visible and (game.get_node(^"UICanvas") as CanvasLayer).visible

func _prompt() -> Node:
	return root.get_node_or_null(^"CutsceneSkipPrompt")

## Кат-сцена скінчилась: стан [param state], керування й HUD повернуто.
func _settled(state: String) -> bool:
	return _state() == state and not game.player.event and _prompt() == null and not dm.is_dialogue_active()

## Дочитує кожну репліку, доки сцена не дійде до [param state].
func _play_to(state: String) -> void:
	var deadline := Time.get_ticks_msec() + 60000
	while not _settled(state) and Time.get_ticks_msec() < deadline:
		if dm.is_dialogue_active() and not dm.is_bubble_playing():  # облачко гортається саме (bubble_time_scale 0)
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
	for i in 30: await physics_frame

## Справжнє утримання кнопки пропуску секунду; далі сцена домотується сама.
func _skip_to(state: String, press: InputEvent, release: InputEvent) -> void:
	await _until(func() -> bool: return _prompt() != null, 8.0)
	ck(_prompt() != null and not _hud_visible(), "skip prompt shown, HUD hidden")
	Input.parse_input_event(press)
	await create_timer(1.2, true, false, true).timeout
	Input.parse_input_event(release)
	await _until(func() -> bool: return _settled(state), 20.0)
	for i in 30: await physics_frame

func _snap() -> Dictionary:
	var cells := _cells()
	var npcs := {}
	for id in ["astrit", "alisia", "urizen"]:
		var npc: Node2D = cells.get_node_or_null("CompanionNPC_" + id)
		npcs[id] = npc.global_position if npc and not npc.is_queued_for_deletion() else null
	return {"state": _state(), "flags": game.get_quest_flags().duplicate(true), "objective": game.get_objective(),
			"hero": game.player.global_position, "npcs": npcs,
			"bars": cells.get_node(^"Bars").visible, "lock": not cells.get_node(^"CellLock/Collision").disabled,
			"door": not cells.get_node(^"ExitDoor/Collision").disabled,
			"scientist": cells.get_node(^"Scientist").visible, "malik": cells.get_node(^"Malik").visible,
			"prisoner": [cells.get_node(^"Prisoner").visible, (cells.get_node(^"Prisoner") as Node2D).global_position],
			"djinn": cells.find_children("*", "CharacterBody2D", false, false).filter(
					func(n: Node) -> bool: return n.is_in_group(&"enemies")).size(),
			"party": sl.get_companion_manager().get_party().duplicate(),
			"hud": _hud_visible(), "control": not game.player.event, "speed": Engine.time_scale}

func _same(played: Dictionary, skipped: Dictionary, beat: String) -> void:
	for key in ["state", "flags", "objective", "npcs", "bars", "lock", "door", "scientist", "malik", "prisoner", "djinn", "party"]:
		ck(str(played[key]) == str(skipped[key]), "%s: skipped %s == played (%s vs %s)" % [beat, key, skipped[key], played[key]])
	ck((played.hero as Vector2).distance_to(skipped.hero) < 4.0, "%s: hero ends where played (%s vs %s)" % [beat, skipped.hero, played.hero])
	ck(skipped.hud and skipped.control and is_equal_approx(skipped.speed, 1.0), "%s: HUD, control and normal speed back (%s, %s, %.1f)" % [beat, skipped.hud, skipped.control, skipped.speed])

func _awake_ok(s: Dictionary, label: String) -> void:
	ck(s.state == "AWAKE", "%s: AWAKE (%s)" % [label, s.state])
	ck(not s.bars and not s.lock and s.door, "%s: bars gone, cell open, east door shut" % label)
	ck(not s.scientist and s.djinn == 0 and s.prisoner[0], "%s: the alchemist and the djinn gone, the prisoner lies by the table" % label)
	ck(s.malik and s.npcs.values().all(func(v: Variant) -> bool: return v != null), "%s: Malik and the three still in their cells" % label)
	ck(s.objective == "Step out of the cell", "%s: objective (%s)" % [label, s.objective])
	ck(game.get_quest_flag("lab_cells_cutscene_complete") and not game.get_quest_flag("lab_acquaintance_complete"), "%s: lab_cells_cutscene_complete only" % label)

func _free_ok(s: Dictionary, label: String) -> void:
	ck(s.state == "FREE", "%s: FREE (%s)" % [label, s.state])
	ck(not s.door and not s.malik, "%s: east door open, Malik gone into the shadows" % label)
	ck(s.npcs.values().all(func(v: Variant) -> bool: return v == null), "%s: the companions ran to the hero and left (%s)" % [label, s.npcs])
	ck(s.objective == "Fight through the laboratory", "%s: objective (%s)" % [label, s.objective])
	ck(game.get_quest_flag("lab_acquaintance_complete") and game.get_quest_flag("task_malik_escort_taken"), "%s: lab_acquaintance_complete, task malik_escort taken" % label)
	ck(UNLOCKS.all(func(f: String) -> bool: return game.get_quest_flag(f)), "%s: all three assists unlocked at once" % label)

## Справжній ввід: герой іде праворуч, доки не почнеться знайомство.
func _step_out() -> void:
	_press(&"move_right")
	await _until(func() -> bool: return _state() != "AWAKE", 6.0)
	_press(&"move_right", false)

## Сейв у камерах із прапорцями [param flags] (решта бітів скинуто) → нова сесія з нього.
func _load_with(flags: Dictionary, slot_path: String) -> void:
	for f in ["lab_cells_cutscene_complete", "lab_acquaintance_complete", "task_malik_escort_taken"] + UNLOCKS:
		game.set_quest_flag(f, flags.get(f, false))
	ck(game.save_game(), "saved in the cells with %s" % [flags.keys()])
	game.queue_free()
	for i in 4: await process_frame
	await _boot(slot_path)

func _initialize() -> void:
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.hints = false  # D728: no «?» tips in this run
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	var slot_path: String = save_system.get_slot_path(TEST_SLOT)
	await process_frame
	sl = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))
	root.get_node("EventBus").assist_called.connect(func(id: String) -> void: assists.append(id))
	await _boot("")
	await _drain()  # вступ Canyon

	print("[1] Arriving from the Mayor Hall: the cells cutscene plays through")
	game.set_quest_flag("city_mayor_hall_complete", true)
	started.clear()  # кат-сцена камер стартує ще під появою (D434)
	await game.teleport_to_room(CELLS, ^"Arrival")

	await _until(func() -> bool: return dm.is_dialogue_active(), 6.0)
	var cells := _cells()
	ck(cells != null and _state() == "CUTSCENE", "in the cells, CUTSCENE (%s)" % _state())
	ck(game.player.event and not _hud_visible() and _prompt() != null, "input taken, HUD hidden, skip prompt shown")
	ck(cells.get_node(^"Bars").visible and not cells.get_node(^"CellLock/Collision").disabled, "behind bars, the cell locked")
	ck(absf(game.player.global_position.x - (cells.get_node(^"Arrival") as Node2D).global_position.x) < 2.0, "the hero is in his cell (x %.0f)" % game.player.global_position.x)
	ck(started == ["Lab_Cells_Arrival"], "first the arrival talk (%s)" % [started])
	var alisia: Node2D = cells.get_node(^"CompanionNPC_alisia")
	var alisia_body: Node2D = alisia.get_node(^"Sprite")
	var cat: Node2D = alisia.get_node(^"Cat")
	var alisia_cell: float = alisia_body.global_position.x
	var alisia_node_x: float = alisia.global_position.x
	var cat_x: float = cat.global_position.x
	var alisia_max := alisia_cell
	var cat_moved := 0.0
	var table_top: Vector2 = (cells.get_node(^"Marks/TableTop") as Node2D).global_position
	var scientist_anim: AnimationPlayer = cells.get_node(^"Scientist/AnimationPlayer")
	var lay_at_inject := false  # B127: на столі, коли алхімік колє
	var sat_up_talking := false  # B127: сидить на столі під репліку Lab_Cells_Injection
	var djinn_seen := false
	var blasts := 0
	var emotes := {}  # "Актор:вид" → true
	var hurt := {}    # актор, чиє тіло почервоніло (pain)
	var bases := {}
	for actor in REACTORS:
		var body: Node2D = cells.get_node(actor).get_child(0) if actor != "CompanionNPC_alisia" else alisia_body
		bases[actor] = body.position
	var deadline := Time.get_ticks_msec() + 60000
	while not _settled("AWAKE") and Time.get_ticks_msec() < deadline:
		if dm.is_dialogue_active() and not dm.is_bubble_playing():  # облачко гортається саме (bubble_time_scale 0)
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		alisia_max = maxf(alisia_max, alisia_body.global_position.x)
		var on_table := alisia_body.global_position.distance_to(table_top) < 1.0
		lay_at_inject = lay_at_inject or (on_table and alisia_body.animation == &"lie" and scientist_anim.current_animation == "inject")
		sat_up_talking = sat_up_talking or (on_table and alisia_body.animation == &"sit_up" and started.has("Lab_Cells_Injection") and dm.is_dialogue_active())
		cat_moved = maxf(cat_moved, absf(cat.global_position.x - cat_x))
		djinn_seen = djinn_seen or cells.find_children("*", "CharacterBody2D", false, false).any(
				func(n: Node) -> bool: return n.is_in_group(&"enemies") and (n as Node2D).visible)
		blasts = maxi(blasts, cells.find_children("Explosion*", "Node2D", false, false).size())
		for actor in REACTORS:
			for child in cells.get_node(actor).get_children():
				if child.scene_file_path.ends_with("Emote.tscn"):
					emotes["%s:%s" % [actor, child.get(&"kind")]] = true
				elif child is CanvasItem and (child as CanvasItem).modulate.g < 0.6:
					hurt[actor] = true
		await process_frame
	for i in 30: await physics_frame
	ck(started == CELLS_TALKS, "the beats in order (%s)" % [started])
	ck(alisia_max > alisia_cell + 200.0 and absf(alisia_body.global_position.x - alisia_cell) < 1.0, "Alisia led to the table (x %.0f) and back to her cell" % alisia_max)
	ck(lay_at_inject, "B127: Alisia lies on the operating table while the alchemist injects her")
	ck(sat_up_talking, "B127: she sits up dazed on the table for the injection line, then is led back")
	ck(alisia_body.animation == &"idle", "Alisia stands in her cell again (%s)" % alisia_body.animation)
	ck(cat_moved < 1.0 and absf(alisia.global_position.x - alisia_node_x) < 1.0, "B126: the cat stays in cell 3 (moved %.0f px)" % cat_moved)
	ck(djinn_seen and blasts > 0, "the djinn bursts out, explosions (%d at once)" % blasts)
	for actor in REACTORS:
		ck(emotes.has(actor + ":surprise") and emotes.has(actor + ":fear"), "D460: %s reacts — «!» at the cry, a sweat drop at the djinn (%s)" % [actor,
				emotes.keys().filter(func(k: String) -> bool: return k.begins_with(actor + ":"))])
	ck(hurt.has("CompanionNPC_alisia"), "D460: Alisia flinches red at the injection (%s)" % [hurt.keys()])
	ck(hurt.size() >= 3, "D460: the blasts hurt those next to them (%s)" % [hurt.keys()])
	var settled := REACTORS.all(func(actor: String) -> bool:
		var body: CanvasItem = cells.get_node(actor).get_child(0) if actor != "CompanionNPC_alisia" else alisia_body
		var still := cells.get_node(actor).get_children().all(func(c: Node) -> bool: return not c.scene_file_path.ends_with("Emote.tscn"))
		return still and body.modulate == Color.WHITE and (body as Node2D).position.distance_to(bases[actor]) < 0.5)
	ck(settled, "after the reactions every body is back in place, untinted, no icon left")
	var played := _snap()
	_awake_ok(played, "played")
	ck(played.hud and played.control and is_equal_approx(played.speed, 1.0), "played: HUD, control and normal speed back")

	print("[2] The same beat skipped with a real Tab hold, from the same start")
	game.set_quest_flag("lab_cells_cutscene_complete", false)
	started.clear()  # кат-сцена камер стартує ще під появою (D434)
	await game.teleport_to_room(CELLS, ^"Arrival")

	await _skip_to("AWAKE", _key(KEY_TAB, true), _key(KEY_TAB, false))
	_same(played, _snap(), "cells")
	ck(started == CELLS_TALKS, "skipped: every talk paged through (%s)" % [started])

	print("[3] The cutscene plays once: back in the room, nothing replays")
	started.clear()  # кат-сцена камер стартує ще під появою (D434)
	await game.teleport_to_room(CELLS, ^"Arrival")

	for i in 60: await physics_frame
	ck(_state() == "AWAKE" and started.is_empty() and not game.player.event, "AWAKE, no talk, control free (%s, %s)" % [_state(), started])

	print("[4] Stepping out of the cell (real move_right): the acquaintance, Malik, the task, the assists")
	assists.clear()
	var before_meet: Dictionary = game.get_quest_flags().duplicate(true)
	await _step_out()
	ck(game.player.event, "the acquaintance takes the input")
	await _until(func() -> bool: return dm.is_dialogue_active(), 10.0)
	var malik_x: float = (_cells().get_node(^"Malik") as Node2D).global_position.x
	var meet_x: float = (_cells().get_node(^"Marks/MalikMeet") as Node2D).global_position.x
	ck(absf(malik_x - meet_x) < 2.0, "D462: Malik walks over before the first line (x %.0f, meet %.0f)" % [malik_x, meet_x])
	await _play_to("FREE")
	ck(started == MEET_TALKS, "one talk: Malik asks, each names themselves, Malik leads on (%s)" % [started])
	var met := _snap()
	_free_ok(met, "played")
	var cm: Node = sl.get_companion_manager()
	ck(met.party.is_empty() and cm.get_unlocked().size() == 3, "all three available, none in the party until picked, D464 (%s)" % [met.party])
	ck("choose_companions" in sl.get_game_manager().player_state.seen_tutorials, "the picker tutorial fired once more than one can be chosen (D463)")
	Input.parse_input_event(_key(KEY_F, true))
	await physics_frame
	Input.parse_input_event(_key(KEY_F, false))
	for i in 10: await physics_frame
	ck(assists.is_empty(), "F calls nobody before a pick (%s)" % [assists])
	cm.toggle_party("astrit")
	Input.parse_input_event(_key(KEY_F, true))
	await physics_frame
	Input.parse_input_event(_key(KEY_F, false))
	for i in 10: await physics_frame
	ck(assists.size() == 1 and assists[0] in ["alisia", "astrit", "urizen"], "a real F press calls a companion's assist (%s)" % [assists])
	cm.toggle_party("astrit")  # назад у табір: пропуск знайомства порівнює загін з цим проходом

	print("[5] The acquaintance skipped with a real pad Y hold, from the same start")
	for f: String in game.get_quest_flags().keys():
		game.set_quest_flag(f, before_meet.get(f, false))
	await game.teleport_to_room(CELLS, ^"Arrival")
	for i in 60: await physics_frame
	ck(_state() == "AWAKE", "back at the wake (%s)" % _state())
	started.clear()
	await _step_out()
	await _skip_to("FREE", _pad_y(true), _pad_y(false))
	_same(met, _snap(), "acquaintance")
	ck(started == MEET_TALKS, "skipped: the talk paged through (%s)" % [started])

	print("[6] A flags-only load resumes at the right beat (B53)")
	await _load_with({}, slot_path)
	await _until(func() -> bool: return dm.is_dialogue_active(), 6.0)
	ck(_cells() != null and _state() == "CUTSCENE" and started == ["Lab_Cells_Arrival"], "no flags → the cutscene plays (%s, %s)" % [_state(), started])
	await _play_to("AWAKE")
	await _load_with({"lab_cells_cutscene_complete": true}, slot_path)
	for i in 30: await physics_frame
	_awake_ok(_snap(), "loaded after the cutscene")
	ck(started.is_empty(), "no talk replays (%s)" % [started])
	ck(absf(game.player.global_position.x - (_cells().get_node(^"Arrival") as Node2D).global_position.x) < 2.0, "the hero wakes in his cell (x %.0f)" % game.player.global_position.x)
	var all_flags := {"lab_cells_cutscene_complete": true, "lab_acquaintance_complete": true, "task_malik_escort_taken": true}
	for f in UNLOCKS:
		all_flags[f] = true
	await _load_with(all_flags, slot_path)
	for i in 30: await physics_frame
	_free_ok(_snap(), "loaded after the acquaintance")
	ck(started.is_empty(), "no talk replays (%s)" % [started])

	print("[7] The hero walks out east into the corridors (real move_right)")
	_press(&"move_right")
	await _until(func() -> bool: return game.map != null and game.map.scene_file_path == CORRIDORS, 20.0)
	_press(&"move_right", false)
	ck(game.map != null and game.map.scene_file_path == CORRIDORS, "in the corridors (%s)" % (game.map.scene_file_path if game.map else "null"))

	game.queue_free()
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
