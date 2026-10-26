extends SceneTree

## BACKLOG 35 (Q48): репліка NPC мимохідь — у D263-облачку над NPC, не у вікні діалогу;
## розмова, яку почав гравець (Talk у меню NPC), лишається у вікні й закриває облачко.
##   godot --headless --path . --script res://SampleProject/UI/verify_npc_chatter.gd

const NPC_SCENE := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/merchant.tscn"
## Чернетки реплік мимохідь (D571) — тест бере ковалеві.
const CHATTER := "res://dialogue_quest/Smith_Chatter.dqd"
const NPC_DIR := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/"
## D571: хто з NPC що каже мимохідь — сцена NPC (або екземпляр у мапі) → .dqd.
const WIRED := {
	"blacksmith.tscn": "Smith_Chatter.dqd",
	"oath_priest.tscn": "City_Oath_Priest_Chatter.dqd",
	"oath_witch.tscn": "City_Oath_Witch_Chatter.dqd",
	"oath_dervish.tscn": "City_Oath_Dervish_Chatter.dqd",
}
const ROAD_MAP := "res://SampleProject/Maps/DesertRoad.tscn"
const ROAD_CHATTER := "DesertRoad_Merchant_Chatter.dqd"
## Вартовий брами (не NpcBase, GateGuard.gd): лівий біля Міської брами, коли бій і розмова позаду (cloud/loose-ends).
const GUARD_SCENE := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/gate_guard.tscn"
const GATES_MAP := "res://SampleProject/Maps/CityGates.tscn"
const GUARD_CHATTER := "CityGates_Guard_Chatter.dqd"
const GUARD_FLAG := "city_gates_after_fight_complete"
## Написані, але ще не підключені: на базарі NPC немає, чекає на арт (звіти cloud/text-1, cloud/loose-ends).
const UNWIRED := ["City_Market_Chatter.dqd"]
const TALK := "res://dialogue_quest/OldMan_Decision.dqd"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


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


func _press(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _clouds(node: Node) -> int:
	var n := 0
	for child in node.get_children():
		if child.get_script() == preload("res://SampleProject/UI/Components/speech_bubble.gd"):
			n += 1
	return n


func _spawn(world: Node, at: Vector2) -> NpcBase:
	var npc: NpcBase = load(NPC_SCENE).instantiate()
	npc.task_giver = ""  # без Game: завдання живуть у прапорцях гри
	npc.shown_with_flag = ""
	npc.gone_with_flag = ""
	npc.talk_dialogue = TALK
	npc.chatter_dialogue = CHATTER
	npc.global_position = at
	world.add_child(npc)
	return npc


func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	var sl: Node = root.get_node("ServiceLocator")
	var dm: Node = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	var world: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 40: await process_frame
	await _drain(dm)
	# Репліка мимохідь живе seconds_for() — тест має її побачити, тож час справжній.
	dm.bubble_time_scale = 1.0
	var player: Node2D = world.player
	var far := player.global_position + Vector2(-5000, 0)
	player.global_position = far
	var npc := _spawn(world, far + Vector2(600, 0))
	await process_frame

	var first: String = dm._stage_tag.sub(dm.DQD_READER.lines(CHATTER)[0].text, "")

	print("[1] The hero walks up: the NPC's line shows in a cloud over its head")
	ck(dm.chatter_bubble(npc) == null, "no cloud while the hero is far away")
	player.global_position = npc.global_position + Vector2(-60, 0)
	npc.interactable._on_body_entered(player)
	await process_frame
	await process_frame
	var bubble: Node2D = dm.chatter_bubble(npc)
	ck(bubble != null and bubble.get_parent() == npc, "a speech cloud is a child of the NPC")
	if bubble == null:
		_done()
		return
	ck(bubble.visible, "the cloud is visible")
	ck(bubble._label.text == first, "it shows the first line (%s)" % bubble._label.text)
	ck(bubble.position == npc.chatter_anchor() and bubble.position.y < 0.0, "the tail sits above the NPC's sprite (%s)" % str(bubble.position))
	ck(bubble.global_position.y < npc.sprite.global_position.y, "the cloud is over the NPC's head, not at its feet")
	ck(not dm.is_dialogue_active(), "chatter is not a dialogue")
	ck(not dm.current_dialogue_box.visible, "the dialogue box stays closed")
	ck(_clouds(player) == 0, "no cloud over the hero")

	print("[2] Said once per visit: stepping out and back does not repeat it")
	npc.interactable._on_body_exited(player)
	dm.end_chatter(npc)
	await process_frame
	npc.interactable._on_body_entered(player)
	await process_frame
	ck(dm.chatter_bubble(npc) == null, "no second cloud")
	ck(_clouds(npc) == 0, "the old cloud is gone")

	print("[3] A talk the player starts uses the dialogue box and closes the cloud")
	var other := _spawn(world, far + Vector2(1400, 0))
	await process_frame
	player.global_position = other.global_position + Vector2(-60, 0)
	other.interactable._on_body_entered(player)
	await process_frame
	await process_frame
	ck(dm.chatter_bubble(other) != null, "second NPC chatters as the hero comes")
	ck(other.npc_menu.visible, "the menu opens by itself alongside the cloud, no E (D454)")
	ck(dm.chatter_bubble(other) != null, "the open menu does not end the chatter (D454)")
	other.npc_menu.chosen.emit(&"talk")
	await process_frame
	await process_frame
	ck(dm.is_dialogue_active(), "Talk starts a dialogue")
	ck(dm.current_dialogue_box.visible, "Talk is shown in the dialogue box")
	await process_frame
	ck(_clouds(other) == 0, "no cloud over the NPC during the talk: picking an entry ends the chatter")

	print("[4] No chatter while a dialogue runs; it comes on the next approach")
	var third := _spawn(world, far + Vector2(2200, 0))
	await process_frame
	player.global_position = third.global_position + Vector2(-60, 0)
	third.interactable._on_body_entered(player)
	await process_frame
	ck(dm.chatter_bubble(third) == null, "the NPC keeps quiet during a dialogue")
	await _drain(dm)
	third.interactable._on_body_exited(player)
	third.interactable._on_body_entered(player)
	await process_frame
	await process_frame
	ck(dm.chatter_bubble(third) != null, "after the dialogue the NPC says its line")

	print("[5] A story dialogue starting closes chatter clouds")
	dm.start_dialogue(TALK)
	await process_frame
	await process_frame
	ck(dm.chatter_bubble(third) == null and _clouds(third) == 0, "the story talk takes over")
	ck(dm.current_dialogue_box.visible, "and it is in the box")
	await _drain(dm)

	print("[6] An NPC without chatter lines stays silent")
	var silent := _spawn(world, far + Vector2(3000, 0))
	silent.chatter_dialogue = ""
	await process_frame
	player.global_position = silent.global_position + Vector2(-60, 0)
	silent.interactable._on_body_entered(player)
	await process_frame
	ck(dm.chatter_bubble(silent) == null, "no cloud")

	print("[7] The chatter cloud ends by itself after its lines")
	dm.bubble_time_scale = 0.0
	var quick := _spawn(world, far + Vector2(3800, 0))
	await process_frame
	player.global_position = quick.global_position + Vector2(-60, 0)
	quick.interactable._on_body_entered(player)
	for i in 10 * dm.DQD_READER.lines(CHATTER).size() + 10:
		await process_frame
	ck(dm.chatter_bubble(quick) == null and _clouds(quick) == 0, "cloud removed after the last line")

	print("[8] D571: the draft lines are wired to their NPCs, 2-3 short lines each, marked as drafts")
	for scene: String in WIRED:
		var keeper: NpcBase = load(NPC_DIR + scene).instantiate()
		ck(keeper.chatter_dialogue == DialoguePaths.ROOT + WIRED[scene], "%s chatters %s (%s)" % [scene, WIRED[scene], keeper.chatter_dialogue])
		keeper.free()
	ck(_map_chatter(ROAD_MAP, ^"Merchant") == DialoguePaths.ROOT + ROAD_CHATTER, "the caravan merchant on the Desert Road chatters " + ROAD_CHATTER)
	var files: Array = WIRED.values() + [ROAD_CHATTER, GUARD_CHATTER] + UNWIRED
	for file: String in files:
		_check_draft(file)

	print("[9] D571: the City Gates guard says his lines in passing once the gate fight is over")
	ck(_map_chatter(GATES_MAP, ^"GuardLeft") == DialoguePaths.ROOT + GUARD_CHATTER, "the left gate guard chatters " + GUARD_CHATTER)
	ck(_map_value(GATES_MAP, ^"GuardLeft", &"chatter_with_flag") == GUARD_FLAG, "only after " + GUARD_FLAG)
	ck(_map_chatter(GATES_MAP, ^"GuardRight") == "", "the right guard stays quiet (one cloud, not the same lines twice)")
	ck(_map_value(GATES_MAP, ^"GuardLeft", &"scale") == null and _map_value(GATES_MAP, ^"GuardRight", &"scale") == null,
			"the guards face left through flip_h, not a mirrored root (the cloud's text is not mirrored)")
	ck(_map_value(GATES_MAP, ^"GuardLeft/Sprite2D", &"flip_h") == true and _map_value(GATES_MAP, ^"GuardRight/Sprite2D", &"flip_h") == true,
			"both still look left, as before")
	dm.bubble_time_scale = 1.0
	var game: Node = world
	game.set_quest_flag(GUARD_FLAG, false)
	var guard: Node2D = load(GUARD_SCENE).instantiate()
	guard.chatter_dialogue = DialoguePaths.ROOT + GUARD_CHATTER
	guard.chatter_with_flag = GUARD_FLAG
	world.add_child(guard)
	guard.global_position = far + Vector2(4400, 0)
	await process_frame
	player.global_position = guard.global_position + Vector2(-40, 0)
	guard.chatter_zone.body_entered.emit(player)
	await process_frame
	ck(dm.chatter_bubble(guard) == null, "before the fight is over: no cloud")
	game.set_quest_flag(GUARD_FLAG, true)
	guard.chatter_zone.body_entered.emit(player)
	await process_frame
	var guard_bubble: Node2D = dm.chatter_bubble(guard)
	ck(guard_bubble != null and guard_bubble.get_parent() == guard, "after it: a cloud over the guard")
	ck(guard_bubble != null and guard_bubble.position == guard.chatter_anchor() and guard_bubble.position.y < 0.0, "the tail sits above his sprite")
	ck(guard_bubble != null and guard_bubble._label.text == dm._stage_tag.sub(DqdReader.lines(DialoguePaths.ROOT + GUARD_CHATTER)[0].text, ""), "his first draft line")
	ck(not dm.is_dialogue_active(), "chatter is not a dialogue")
	dm.end_chatter(guard)
	guard.chatter_zone.body_entered.emit(player)
	await process_frame
	ck(dm.chatter_bubble(guard) == null, "once per room: walking past again says nothing")
	var mute: Node2D = load(GUARD_SCENE).instantiate()
	world.add_child(mute)
	mute.global_position = far + Vector2(4800, 0)
	mute.chatter_zone.body_entered.emit(player)
	await process_frame
	ck(dm.chatter_bubble(mute) == null, "a guard without lines (the City's) stays quiet")
	game.set_quest_flag(GUARD_FLAG, false)
	_done()


## Властивість [param prop] вузла [param node] у мапі [param map] (null — не задано в мапі).
func _map_value(map: String, node: NodePath, prop: StringName) -> Variant:
	var state: SceneState = (load(map) as PackedScene).get_state()
	for i in state.get_node_count():
		if state.get_node_path(i) != NodePath("./" + String(node)):
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == prop:
				return state.get_node_property_value(i, p)
	return null


## chatter_dialogue екземпляра [param node] у мапі [param map] (без запуску мапи).
func _map_chatter(map: String, node: NodePath) -> String:
	var state: SceneState = (load(map) as PackedScene).get_state()
	for i in state.get_node_count():
		if state.get_node_path(i) != NodePath("./" + String(node)):
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"chatter_dialogue":
				return state.get_node_property_value(i, p)
	return ""


## 2-3 репліки по одному мовцю, коротко (облачко, не вікно), обидві мови позначені чернеткою.
func _check_draft(file: String) -> void:
	var path := DialoguePaths.ROOT + file
	var twin := DialoguePaths.ROOT + DialoguePaths.EN_DIR + file
	var lines: Array[Dictionary] = DqdReader.lines(path)
	var speakers: Dictionary = {}
	var longest := 0
	for line in lines:
		speakers[line.speaker] = true
		longest = maxi(longest, String(line.text).length())
	ck(lines.size() >= 2 and lines.size() <= 3 and speakers.size() == 1 and longest <= 90,
			"%s: %d lines by %s, longest %d chars" % [file, lines.size(), str(speakers.keys()), longest])
	ck(FileAccess.get_file_as_string(path).begins_with("// [ЧЕРНЕТКА] D571")
			and FileAccess.get_file_as_string(twin).begins_with("// [DRAFT] D571"), "%s is marked [ЧЕРНЕТКА] / [DRAFT]" % file)


func _done() -> void:
	print("RESULT: %s" % ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0 if fails.is_empty() else 1)
