extends SceneTree

## Стартове спорядження новачка (Sapega, 2026-10-12):
## гра починається без зілль, перший убитий ворог дає рівно 5, дід — Copper Sword і Leather Armor, один раз.
##   godot --headless --path . --script res://SampleProject/UI/verify_starter_loot.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Проклацує справжній діалог до кінця — подію dialogue_finished шле сам DialogueManager,
## як у грі. Підробний emit лишав живий діалог і плутав порядок наступних.
func _finish_dialogue(dm: Node) -> void:
	for i in 200:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
		dm.current_dialogue_player.accept()
		await process_frame

func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	# Як кнопка New Game: без цього Game.tscn вантажить справжній сейв гравця.
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var inv: Node = sl.get_inventory_manager()

	print("[1] A fresh game has no potions")
	ck(inv.get_item_count("potion") == 0, "0 potions at start (%d)" % inv.get_item_count("potion"))

	print("[2] The first kill gives 5 potions, later kills give none")
	var spawner: Node = load("res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd").new()
	spawner._on_enemy_died(Node.new())
	ck(inv.get_item_count("potion") == 5, "5 potions after the first kill (%d)" % inv.get_item_count("potion"))
	spawner._on_enemy_died(Node.new())
	ck(inv.get_item_count("potion") == 5, "still 5 after a second kill (%d)" % inv.get_item_count("potion"))

	print("[2b] Random potions are rare (D261): about 1 kill in 10, not every enemy")
	var loot: Node = root.get_node("GameManager/LootSystem")
	ck(is_equal_approx(loot.potion_drop_chance, 0.1), "potion drop chance 10%% (%.2f)" % loot.potion_drop_chance)
	loot.rng.seed = 259
	var potions_before: int = inv.get_item_count("potion")
	for i in 1000:
		loot._on_enemy_died("verify", Vector2.ZERO)
	var dropped: int = inv.get_item_count("potion") - potions_before
	ck(dropped > 60 and dropped < 140, "1000 kills drop ~100 potions, not 1000 (%d)" % dropped)
	inv.remove_item("potion", dropped)

	print("[3] The old man's gift arrives once")
	# Справжня кімната: подарунок показує підказку через дерево, а голий скрипт села без кімнати не стартує
	var village: Node = load("res://SampleProject/Maps/Village.tscn").instantiate()
	game.add_child(village)
	village._give_oldman_gift()
	village._give_oldman_gift()
	ck(inv.get_item_count("copper_sword") == 1, "one Copper Sword (%d)" % inv.get_item_count("copper_sword"))
	ck(inv.get_item_count("leather_armor") == 1, "one Leather Armor (%d)" % inv.get_item_count("leather_armor"))
	var hint: TutorialHintDisplay = root.get_tree().get_first_node_in_group(&"tutorial_hint_display")
	ck(hint.current_hint == "oldman_gift", "the gift hint tells how to equip it (%s)" % hint.current_hint)

	spawner.free()
	village.free()

	print("[4] The old man's talks play in turn, and the gift comes after the last")
	var flags: Dictionary = game.get_quest_flags().duplicate()
	for f in ["village_oldman_met", "village_oldman_healed", "village_oldman_complete", "village_left_complete", "village_oldman_gift"]:
		flags.erase(f)
	flags["village_fight_complete"] = true
	game.set_quest_flags(flags)
	inv.remove_item("copper_sword", 1)
	inv.remove_item("leather_armor", 1)
	var started: Array[String] = []
	var swords_at_start: Dictionary = {}  # розмова → скільки мечів було, коли вона почалась
	# Лише розмови Village: Canyon (стартова кімната) паралельно грає свій вступ.
	sl.get_dialogue_manager().dialogue_started.connect(func(id: String) -> void:
		var talk := id.get_file().get_basename()
		if talk.begins_with("OldMan_") or talk == "LeavingVillage":
			started.append(talk)
			swords_at_start[talk] = inv.get_item_count("copper_sword"))
	# Стартова кімната (Canyon) грає вступ ланцюжком (Intro → StartMonologue); активний діалог
	# не перебивається (D131) — проклацуємо, доки нового не стартує кілька кадрів поспіль.
	var dm: Node = sl.get_dialogue_manager()
	for round in 10:
		await _finish_dialogue(dm)
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			break
	# Справжня кімната (з EnemySpawner), а не голий скрипт — у грі Village без неї не буває.
	var v2: Node = load("res://SampleProject/Maps/Village.tscn").instantiate()
	root.add_child(v2)
	for i in 4: await process_frame
	ck(v2.get_current_state_name() == "OLD_MAN_OUTSIDE", "waits for the player at the tree (%s)" % v2.get_current_state_name())
	v2.change_state_by_name("OLD_MAN_HEALING")  # що робить тригер
	for i in 4: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	for i in 4: await process_frame
	# D261: дід лікування не просить — після OldMan_Healing одразу рішення й подарунок.
	ck(started == ["OldMan_Outside", "OldMan_Healing", "OldMan_Decision", "LeavingVillage"], "talks in order, once each, no heal request (%s)" % [started])
	ck(swords_at_start.get("OldMan_Decision", -1) == 0, "no gift before the last talk starts")
	ck(swords_at_start.get("LeavingVillage", -1) == 1, "gift is there once the last talk is over")
	ck(game.get_quest_flag("village_oldman_met") and game.get_quest_flag("village_oldman_healed") and game.get_quest_flag("village_oldman_complete"), "met → healed → complete flags set")
	ck(inv.get_item_count("copper_sword") == 1 and inv.get_item_count("leather_armor") == 1, "gift arrives after the last talk")
	ck(v2.get_current_state_name() == "LEAVING_VILLAGE", "then on to leaving (%s)" % v2.get_current_state_name())
	v2.queue_free()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
