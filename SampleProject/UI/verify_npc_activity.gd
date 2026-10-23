extends SceneTree

## BACKLOG 5 (D295): кожен NPC у мапах сам щось робить (цикл дії «work» чергується зі спокоєм «idle»),
## на розмову (E біля нього) перемикається в позу «talk» обличчям до героя, після — знову до дії.
##   godot --headless --path . --script res://SampleProject/UI/verify_npc_activity.gd

const NPC_DIR := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/"
## Сцена NPC → мапа, де він стоїть, і чи з ним говорять.
const NPCS := [
	["blacksmith", "City", true],
	["merchant", "DesertRoad", true],
	["grandfather", "Village", true],
	["oath_priest", "City", true],
	["oath_witch", "City", true],
	["oath_dervish", "City", true],
	["gate_guard", "CityGates", false],
]

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _press(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _stands_in(scene_path: String, map: String) -> bool:
	var state: SceneState = (load("res://SampleProject/Maps/%s.tscn" % map) as PackedScene).get_state()
	return range(state.get_node_count()).any(func(i: int) -> bool:
		return state.get_node_instance(i) != null and state.get_node_instance(i).resource_path == scene_path)


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return


func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var world: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)
	var player: Node2D = world.player
	var far := player.global_position + Vector2(-5000, 0)
	player.global_position = far

	print("[1] Every NPC in the maps has a work loop of 3+ frames")
	var npcs: Array[Node2D] = []
	for i in NPCS.size():
		var path: String = NPC_DIR + NPCS[i][0] + ".tscn"
		ck(_stands_in(path, NPCS[i][1]), "%s stands in the %s" % [NPCS[i][0], NPCS[i][1]])
		var npc: Node2D = load(path).instantiate()
		if npc is NpcBase:
			npc.task_giver = ""  # без Game: завдання живуть у прапорцях гри
			npc.talk_dialogue = "res://dialogue_quest/any.dqd"  # є що відкрити — є меню
		npc.global_position = far + Vector2(400 * (i + 1), 0)
		world.add_child(npc)
		npcs.append(npc)
		var anim: AnimationPlayer = npc.get_node(^"AnimationPlayer")
		var work: Animation = anim.get_animation(&"work")
		var keys: Dictionary = {}
		for k in work.track_get_key_count(0):
			keys[work.track_get_key_value(0, k)] = true
		ck(work.loop_mode == Animation.LOOP_LINEAR and keys.size() >= 3, "%s: looping work of %d distinct frames" % [NPCS[i][0], keys.size()])

	print("[2] Left alone, every NPC falls into its activity within a rest pause and plays the whole loop")
	var seen: Array[Dictionary] = []
	var window := 0.0
	for npc in npcs:
		seen.append({})
		window = maxf(window, npc.get_node(^"Activity").rest_max + (npc.get_node(^"AnimationPlayer") as AnimationPlayer).get_animation(&"work").length)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int((window + 0.5) * 1000.0):  # найдовша пауза + повний цикл дії
		for i in npcs.size():
			var anim: AnimationPlayer = npcs[i].get_node(^"AnimationPlayer")
			if anim.current_animation == "work":
				seen[i][(npcs[i].get_node(^"Sprite2D") as Sprite2D).frame] = true
		await process_frame
	for i in npcs.size():
		ck(seen[i].size() >= 3, "%s: the work loop shows %d distinct frames on screen" % [NPCS[i][0], seen[i].size()])

	print("[3] Talking: E next to the NPC → talk pose facing the hero; menu closed → back to work")
	for i in npcs.size():
		if not NPCS[i][2]:
			continue
		var npc: NpcBase = npcs[i]
		var anim: AnimationPlayer = npc.get_node(^"AnimationPlayer")
		var rest_flip: bool = npc.sprite.flip_h
		player.global_position = npc.global_position + Vector2(-60, 0)  # герой ліворуч
		npc.interactable._on_body_entered(player)
		root.push_input(_press(InteractableComponent.ACTION))
		await process_frame
		await process_frame
		ck(npc.npc_menu.visible and anim.current_animation == "talk", "%s: talk pose while the menu is open (%s)" % [NPCS[i][0], anim.current_animation])
		ck(npc.sprite.flip_h == not npc.profile_faces_left, "%s: talk profile turned to the hero on the left" % NPCS[i][0])
		root.push_input(_press(&"ui_cancel"))
		await process_frame
		await process_frame
		ck(not npc.npc_menu.visible and anim.current_animation == "work", "%s: back to work after the talk (%s)" % [NPCS[i][0], anim.current_animation])
		ck(npc.sprite.flip_h == rest_flip, "%s: faces its scene direction again" % NPCS[i][0])
		npc.interactable._on_body_exited(player)
		player.global_position = far

	print("[4] A conversation next to the NPC (not only its menu) is talking too")
	var grandfather: NpcBase = npcs[2]
	var g_anim: AnimationPlayer = grandfather.get_node(^"AnimationPlayer")
	player.global_position = grandfather.global_position + Vector2(-60, 0)
	grandfather.interactable._on_body_entered(player)
	dm.start_dialogue("res://dialogue_quest/OldMan_Decision.dqd")
	await process_frame
	await process_frame
	ck(g_anim.current_animation == "talk", "grandfather: talk pose while a dialogue runs beside him (%s)" % g_anim.current_animation)
	await _drain(dm)
	await process_frame
	ck(g_anim.current_animation == "work", "grandfather: back to his pipe after the dialogue (%s)" % g_anim.current_animation)

	print("[5] B81: the anvil stands at the forge the whole time, the smith walks out to it without carrying it")
	await world.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 30: await physics_frame
	var city: Node = world.map
	var smith: NpcBase = city.get_node(^"Blacksmith")
	var anvil: Sprite2D = city.get_node(^"Anvil")
	var anvil_at: Vector2 = anvil.global_position
	ck(not smith.is_ancestor_of(anvil) and smith.find_children("*", "Sprite2D", true, false).size() == 1, "the anvil is not part of the smith (only his own sprite moves with him)")
	ck(not smith.visible and anvil.is_visible_in_tree(), "before the meeting: smith inside, anvil already at the forge")
	ck(absf(anvil_at.x - smith.global_position.x) < 1.0, "the anvil stands at his station (x %.0f / %.0f)" % [anvil_at.x, smith.global_position.x])
	player = world.player
	player.global_position = Vector2(840, 360)
	for i in 20: await physics_frame
	var smith_xs: Array[float] = []
	var anvil_moved := false
	Input.action_press(&"move_right")
	for i in 600:
		if smith.visible and (smith.get_node(^"AnimationPlayer") as AnimationPlayer).current_animation == "walk":
			Input.action_release(&"move_right")
			smith_xs.append(smith.global_position.x)
		anvil_moved = anvil_moved or not anvil.global_position.is_equal_approx(anvil_at) or not anvil.is_visible_in_tree()
		if dm.is_dialogue_active():
			break
		await physics_frame
	Input.action_release(&"move_right")
	ck(smith_xs.size() > 10 and absf(smith_xs[-1] - smith_xs[0]) > 50.0, "the smith walks out (%d frames, %.0f px)" % [smith_xs.size(), absf(smith_xs[-1] - smith_xs[0]) if smith_xs.size() > 0 else 0.0])
	ck(not anvil_moved, "the anvil did not move or vanish while he walked")
	ck(absf(smith.global_position.x - anvil_at.x) < 1.0, "he arrives at the anvil (x %.0f)" % smith.global_position.x)
	await _drain(dm)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
