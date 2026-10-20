extends SceneTree

## Завдання коваля (D175): Quest → «Шолом» → показати шолом → 88 золота → «Зачарування» →
## два мечі → меч +1 → плата за зачарування назад.
##   godot --headless --path . --script res://SampleProject/UI/verify_tasks.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> Array[String]:
	var shown: Array[String] = []
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			if dm.current_dialogue_box and dm.current_dialogue_box.visible:
				shown.append(dm.current_dialogue_box.text)
			if dm.is_replaying():
				var inputs: Object = root.get_node("DialogueQuest").Inputs
				dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
				inputs.accept_pressed.emit()
			else:
				dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
				dm.current_dialogue_player.accept()
			for f in 6: await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			break
	return shown

func _labels(npc: Node) -> Array:
	return npc.menu_entries().map(func(e): return e.label)

func _choose_quest(npc: Node, dm: Node) -> Array[String]:
	npc.interactable.interacted.emit()
	await process_frame
	npc.npc_menu.chosen.emit(&"task")
	await process_frame
	return await _drain(dm)

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
	var inv: Node = sl.get_inventory_manager()
	var smith: Node = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/blacksmith.tscn").instantiate()
	game.add_child(smith)
	await process_frame

	print("[1] Quest sits between Talk and Craft (Figma 176:1357)")
	ck(_labels(smith) == ["Quest", "Craft", "Enchant"], "entries %s" % str(_labels(smith)))

	print("[2] Helmet: taken, reminded, turned in")
	smith.interactable.interacted.emit()
	await process_frame
	smith.npc_menu.chosen.emit(&"task")
	for i in 10: await process_frame
	ck(dm.current_dialogue_box.name_text == "Коваль", "the Blacksmith speaks (%s)" % dm.current_dialogue_box.name_text)
	await _drain(dm)
	ck(game.get_quest_flag("task_smith_helmet_taken") and not game.get_quest_flag("task_smith_helmet_done"), "task_smith_helmet active")
	var shown := await _choose_quest(smith, dm)
	ck(not shown.is_empty() and shown[-1].begins_with("Current task: Craft an Iron Helmet"), "no helmet → reminder ends on the task (%s)" % (shown[-1] if shown else ""))
	ck(game.get_quest_flag("task_smith_helmet_taken") and not game.get_quest_flag("task_smith_helmet_done"), "still active without a helmet")
	inv.add_item("iron_helmet", 1)
	var coins: int = inv.get_item_count("coin")
	await _choose_quest(smith, dm)
	ck(game.get_quest_flag("task_smith_helmet_done"), "helmet shown → done")
	ck(inv.get_item_count("coin") - coins == 88, "88 gold back (%d)" % (inv.get_item_count("coin") - coins))
	ck(inv.get_item_count("iron_helmet") == 1, "the helmet stays with the player")

	print("[3] Enchant: two swords, enchant them, show the +1")
	ck(_labels(smith).has("Quest"), "Quest still there — the next task opened")
	var swords: int = inv.get_item_count("iron_sword")
	await _choose_quest(smith, dm)
	ck(inv.get_item_count("iron_sword") - swords == 2, "two Iron Swords given")
	var ench: RefCounted = load("res://SampleProject/Scripts/Crafting/enchanting_service.gd").new()
	inv.add_item("coin", ench.cost("iron_sword"))
	ck(ench.enchant("iron_sword") == 0, "the two swords enchant into one")
	coins = inv.get_item_count("coin")
	await _choose_quest(smith, dm)
	ck(game.get_quest_flag("task_smith_enchant_done"), "sword +1 shown → done")
	ck(inv.get_item_count("coin") - coins == ench.cost("iron_sword"), "the enchanting fee comes back (%d)" % (inv.get_item_count("coin") - coins))
	ck(inv.get_item_count("iron_sword+1") == 1, "the +1 sword stays with the player")
	ck(not _labels(smith).has("Quest"), "no tasks left → no Quest")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
