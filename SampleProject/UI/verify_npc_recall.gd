extends SceneTree

## Пункт Quest у сюжетного NPC (design/npc_recall_plan.md; D158, D161, D169): дід у Village.
## Розмова перечитується лише для показу — без DialogueQuest, без dialogue_started/finished.
##   godot --headless --path . --script res://SampleProject/UI/verify_npc_recall.gd

const STORY_NPC := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/story_npc.tscn"

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


func _labels(npc: Node) -> Array:
	return npc.menu_entries().map(func(e): return e.label)


func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)

	print("[1] The old man in the Village carries the main quest (D169)")
	var village: SceneState = (load("res://SampleProject/Maps/Village.tscn") as PackedScene).get_state()
	var found := false
	for i in village.get_node_count():
		var inst: PackedScene = village.get_node_instance(i)
		if inst and inst.resource_path == STORY_NPC:
			var props := {}
			for p in village.get_node_property_count(i):
				props[village.get_node_property_name(i, p)] = village.get_node_property_value(i, p)
			found = props.get("quest_flag") == "village_oldman_complete" and props.get("quest_dialogue") == "OldMan_Decision"
	ck(found, "Village has a StoryNpc on the old man: village_oldman_complete → OldMan_Decision")
	ck(not DqdReader.lines("res://dialogue_quest/OldMan_Decision.dqd").is_empty(), "OldMan_Decision has lines to replay")

	print("[2] Quest appears once the quest is given")
	var npc: Node = load(STORY_NPC).instantiate()
	npc.quest_flag = "verify_recall_given"
	npc.quest_dialogue = "OldMan_Decision"
	game.add_child(npc)
	await process_frame
	ck(_labels(npc).is_empty() and not npc.interactable.enabled, "before: no entries, no prompt")
	game.set_quest_flag("verify_recall_given", true)
	await process_frame
	ck(_labels(npc) == ["Quest"] and npc.interactable.enabled, "after the flag: Quest, prompt on — without re-entering")

	print("[3] Quest replays the talk read-only, then the objective")
	var started := [0]
	var finished := [0]
	dm.dialogue_started.connect(func(_id): started[0] += 1)
	dm.dialogue_finished.connect(func(_id): finished[0] += 1)
	var flags_before: Dictionary = game.quest_flags.duplicate() if "quest_flags" in game else {}
	npc.interactable.interacted.emit()
	await process_frame
	npc.npc_menu.chosen.emit(&"quest")
	await process_frame
	var box: Node = dm.current_dialogue_box
	ck(dm.is_replaying() and dm.is_dialogue_active() and box.visible, "replay shows the dialogue box")
	ck(box.name_text == "Дед", "speaker name from the DialogueQuest characters (%s)" % box.name_text)
	var shown: Array[String] = []
	var typing_holds := true
	for i in 40:
		if not dm.is_replaying():
			break
		shown.append(box.text)
		# D254: поки репліка набирається, «далі» нічого не робить — ні дописати, ні перейти
		root.get_node("DialogueQuest").Inputs.accept_pressed.emit()
		await process_frame
		typing_holds = typing_holds and not box.is_finished() and box.text == shown[-1]
		box.finish()  # тест не чекає набору
		root.get_node("DialogueQuest").Inputs.accept_pressed.emit()  # далі
		await process_frame
	ck(typing_holds, "D254: accept while a line is typing neither completes it nor moves on")
	var expected := DqdReader.lines("res://dialogue_quest/OldMan_Decision.dqd").map(func(l): return l.text)
	ck(shown.slice(0, expected.size()) == expected, "every line, in order (%s)" % str(shown))
	ck(shown.size() == expected.size() + 1 and shown[-1].begins_with("Current objective: "),
			"ends on the current objective (%s)" % (shown[-1] if shown else ""))
	ck(not dm.is_replaying() and not box.visible, "box closes after the last line")
	ck(started[0] == 0 and finished[0] == 0, "no dialogue_started / dialogue_finished — scenes are not re-triggered")
	if "quest_flags" in game:
		var after: Dictionary = game.quest_flags
		ck(after == flags_before, "no quest flag changed")
	var player: Node = get_first_node_in_group(&"player")
	ck(player != null and not player.event, "the player can move again")

	print("[4] E does not open an NPC menu over a running conversation")
	dm.replay("res://dialogue_quest/OldMan_Decision.dqd")
	await process_frame
	npc.interactable.interacted.emit()
	await process_frame
	ck(not npc.npc_menu.visible, "menu stays shut while a dialogue runs")
	for i in 40:
		if not dm.is_replaying():
			break
		box.finish()  # D254: тест не чекає набору репліки
		root.get_node("DialogueQuest").Inputs.accept_pressed.emit()
		await process_frame

	print("[5] The old man's decision names its speaker; no empty portrait frame")
	dm.start_dialogue("res://dialogue_quest/OldMan_Decision.dqd")
	for i in 5: await process_frame
	var name_label: Label = box.get_node(^"%Name")
	ck(name_label.is_visible_in_tree() and name_label.text == "Дед", "the box names the grandfather ('%s')" % name_label.text)
	ck(not box.get_node(^"%PortraitBackground").visible, "a speaker without a portrait shows no portrait frame")
	await _drain(dm)
	_done()


func _done() -> void:
	print("")
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
		for f in fails:
			print("    : " + f)
	quit(0 if fails.is_empty() else 1)
