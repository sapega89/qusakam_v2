extends SceneTree

## Village: прибуття → репліка бандита → бій (Sapega, 2026-10-13: «не зʼявився діалог і ворог,
## гра застопорилась, не можу рухатись»).
## Тригер прибуття міняє стан на STREET_FIGHT І грає ArrivalToVillage; стан запускає свою
## реплiку FightWithBandit. Раніше другий запит ховав живе вікно першого й губився.
##   godot --headless --path . --script res://SampleProject/UI/verify_village_fight.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Один «Enter» у діалозі; повертає, чи діалог ще йде.
func _press(dm: Node) -> void:
	dm.current_dialogue_player.accept()
	for i in 6: await process_frame

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			await _press(dm)
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _enemy_count(village: Node) -> int:
	var count := 0
	for n in village.find_children("*", "CharacterBody2D", true, false):
		if n.is_in_group(&"enemies"):
			count += 1
	return count

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)  # вступ Canyon

	var flags: Dictionary = game.get_quest_flags().duplicate()
	for f in ["canyon_intro_complete", "canyon_exploration_complete", "canyon_abduction_complete"]:
		flags[f] = true
	game.set_quest_flags(flags)
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))

	print("[0] The abduction: fade to black, lines over black, light again (D140)")
	game.teleport_to_room("res://SampleProject/Maps/Village.tscn", ^"Arrival")
	await create_timer(1.0).timeout
	var village: Node = game.map  # після телепорту MetSys підвантажує кімнату вдруге (B51)
	ck(village.get_current_state_name() == "ABDUCTION_CUTSCENE", "starts with the abduction")
	ck(root.has_node(^"ScreenFade") and root.get_node(^"ScreenFade").get_child(0).color.a > 0.9, "the screen is black")
	ck(started == ["VillageAbduction"], "abduction lines over black (%s)" % [started])
	await _drain(dm)
	await create_timer(1.0).timeout
	ck(not root.has_node(^"ScreenFade"), "the fade is gone afterwards")
	ck(village.get_current_state_name() == "ARRIVAL", "waits for the player in ARRIVAL")
	started.clear()

	print("[1] Entering the arrival trigger")
	game.player.global_position = Vector2(150, 344)
	game.player.velocity = Vector2.ZERO
	for i in 30: await process_frame
	ck(village.get_current_state_name() == "STREET_FIGHT", "state STREET_FIGHT")
	ck(game.get_quest_flag("village_arrival_complete"), "village_arrival_complete set (journal: reached the village center)")
	ck(started == ["ArrivalToVillage"], "the arrival line plays first (%s)" % [started])
	ck(dm.current_dialogue_box.visible, "the dialogue box is VISIBLE while a dialogue runs")
	ck(_enemy_count(village) == 0, "no enemy while the player is locked in the dialogue")
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	for i in 4: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "the game menu does not open during a dialogue (B16, D136)")

	print("[2] Arrival line ends → the bandit's taunt, still no enemy")
	while started.size() < 2:
		await _press(dm)
		if not dm.is_dialogue_active():
			for i in 20: await process_frame
	ck(started == ["ArrivalToVillage", "FightWithBandit"], "the taunt follows (%s)" % [started])
	ck(dm.current_dialogue_box.visible, "the box is visible during the taunt")
	ck(_enemy_count(village) == 0, "still no enemy during the taunt")

	print("[3] Taunt ends → the bandit appears and the player can move")
	await _drain(dm)
	for i in 30: await process_frame
	ck(_enemy_count(village) == 1, "the bandit appears (%d)" % _enemy_count(village))
	ck(not game.player.event, "the player is unlocked")
	ck(not paused, "the game is not paused")

	print("[4] Killing the bandit finishes the street fight")
	for n in village.find_children("*", "CharacterBody2D", true, false):
		if n.is_in_group(&"enemies") and n.is_alive():
			n.die()
	for i in 20: await process_frame
	ck(game.get_quest_flag("village_fight_complete"), "village_fight_complete set")
	ck(village.get_current_state_name() == "OLD_MAN_OUTSIDE", "on to the old man (%s)" % village.get_current_state_name())

	print("[5] \"Oh no, the house!\" (D140)")
	ck(started.has("Village_AfterFight"), "the after-fight line plays (%s)" % [started])
	ck(game.current_objective == "Check on the house", "objective: Check on the house (%s)" % game.current_objective)
	await _drain(dm)

	print("[6] The old man heals Kusakam and teaches Healing Palm")
	var sm: Node = sl.get_skill_manager()
	ck(not sm.is_unlocked("healing_palm"), "Healing Palm is not known before the old man")
	game.player.take_damage(30)
	game.player.global_position = Vector2(1582, 344)
	game.player.velocity = Vector2.ZERO
	for i in 30: await process_frame
	ck(village.get_current_state_name() == "OLD_MAN_HEALING", "the tree trigger starts the old man's scene")
	await _drain(dm)
	for i in 10: await process_frame
	ck(started.has("OldMan_Outside") and started.has("OldMan_Healing"), "meeting and healing lines (%s)" % [started])
	ck(game.player.current_health == game.player.Max_Health, "the old man healed Kusakam to full")
	ck(village.get_current_state_name() == "OLD_MAN_TREATMENT", "now it is Kusakam's turn (%s)" % village.get_current_state_name())
	ck(sm.is_unlocked("healing_palm") and sm.get_equipped_skill(0) == "healing_palm", "Healing Palm learned, on hotbar slot 1")
	var hint: Node = get_first_node_in_group("tutorial_hint_display")
	ck(hint.visible and hint.hint_label.text.begins_with("Your grandfather is dying"), "tutorial: your grandfather is dying — use Healing Palm (D148)")
	ck(game.current_objective.begins_with("Heal the old man"), "objective: heal the old man (%s)" % game.current_objective)

	print("[7] The player presses 1 next to the old man (D145)")
	# Як у грі: герой стоїть НА ЗЕМЛІ поруч із дідом (центр ~23 px нижче за діда), а не на його рівні.
	game.player.global_position = Vector2(1600, 300)
	for i in 60: await physics_frame
	ck(game.player.is_on_floor(), "Kusakam stands on the ground next to him (y=%.0f)" % game.player.global_position.y)
	for down in [true, false]:
		var key := InputEventAction.new()
		key.action = &"skill_slot_1"
		key.pressed = down
		root.push_input(key)
		await process_frame
	for i in 10: await process_frame
	ck(game.get_quest_flag("village_oldman_treated"), "the old man is healed — village_oldman_treated")
	ck(not hint.is_showing, "the tutorial hint goes away once he is healed")
	ck(started.has("OldMan_Treated"), "his thanks play (%s)" % [started])
	await _drain(dm)
	for i in 10: await process_frame
	ck(started.has("OldMan_Decision"), "then the decision and the gift")
	print("[8] The Skills tab lists Kusakam's skills")
	ui.open_game_menu()
	for i in 16: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Skills")
	for i in 8: await process_frame
	var skills_tab: Node = menu.find_child("SkillsComponent", true, false)
	ck(skills_tab._rows.has("healing_palm") and skills_tab._rows.has("fire_strike"), "Healing Palm and the strikes are listed (%s)" % [skills_tab._rows.keys()])
	ui.close_game_menu()
	ck(sl.get_inventory_manager().get_item_count("copper_sword") >= 1, "the gift arrives")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
