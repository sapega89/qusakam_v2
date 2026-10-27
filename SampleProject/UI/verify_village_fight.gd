extends SceneTree

## Village: прибуття → репліка бандита → бій (Sapega, 2026-10-13: «не зʼявився діалог і ворог,
## гра застопорилась, не можу рухатись»).
## Тригер прибуття міняє стан на STREET_FIGHT І грає ArrivalToVillage; стан запускає свою
## реплiку FightWithBandit. Раніше другий запит ховав живе вікно першого й губився.
## Після бою — до дому діда (ElderDoor): розмова з ним, лікування, рішення, ключ — усередині (D438), вихід — тими
## самими дверима назад, а тоді LeavingVillage.
## D743: бій — звичайний, без тренування; прапорці уроків старого сейва (training_*_done) нічого не міняють.
##   godot --headless --path . --script res://SampleProject/UI/verify_village_fight.gd

const VILLAGE := "res://SampleProject/Maps/Village.tscn"
const HOUSE := "res://SampleProject/Maps/ElderHouse.tscn"

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Один «Enter» у діалозі; повертає, чи діалог ще йде.
func _press(dm: Node) -> void:
	dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
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

## Закриває модалку (подарунок діда, D129) кнопкою у фокусі — як Enter.
func _close_modal(sl: Node) -> void:
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	for i in 30:
		if layer.active_modal:
			layer.active_modal.get_viewport().gui_get_focus_owner().pressed.emit()
			for j in 4: await process_frame
			return
		await process_frame

func _enemy_count(village: Node) -> int:
	var count := 0
	for n in village.find_children("*", "CharacterBody2D", true, false):
		if n.is_in_group(&"enemies"):
			count += 1
	return count

func _enemies_active(village: Node) -> bool:
	for n in village.find_children("*", "CharacterBody2D", true, false):
		if n.is_in_group(&"enemies") and not n.can_process():
			return false
	return true

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
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
	await _drain(dm)  # вступ Canyon

	var flags: Dictionary = game.get_quest_flags().duplicate()
	for f in ["canyon_intro_complete", "canyon_exploration_complete", "canyon_abduction_complete"]:
		flags[f] = true
	flags["training_lesson_attack_done"] = true  # сейв, зроблений посеред старого тренування (D733)
	game.set_quest_flags(flags)
	var started: Array[String] = []
	dm.dialogue_started.connect(func(id: String) -> void: started.append(id.get_file().get_basename()))

	print("[0] Entering the village: no cutscene here any more, the raid is in Canyon")
	await game.teleport_to_room("res://SampleProject/Maps/Village.tscn", ^"Arrival")
	await create_timer(1.0).timeout
	var village: Node = game.map  # після телепорту MetSys підвантажує кімнату вдруге (B51)
	ck(village.get_current_state_name() == "ARRIVAL", "waits for the player in ARRIVAL (%s)" % village.get_current_state_name())
	ck(started.is_empty() and not root.has_node(^"ScreenFade"), "no fade, no lines on entry (%s)" % [started])
	ck(game.get_quest_flag("village_abduction_complete"), "village_abduction_complete marks the visit")
	started.clear()

	print("[1] Entering the arrival trigger")
	game.player.global_position = Vector2(150, 344)
	game.player.velocity = Vector2.ZERO
	for i in 30: await process_frame
	ck(village.get_current_state_name() == "STREET_FIGHT", "state STREET_FIGHT")
	ck(game.get_quest_flag("village_arrival_complete"), "village_arrival_complete set (journal: reached the village center)")
	ck(started == ["ArrivalToVillage"], "the arrival line plays first (%s)" % [started])
	ck(dm.current_dialogue_box.visible, "the dialogue box is VISIBLE while a dialogue runs")
	ck(_enemy_count(village) == 1, "the bandit appears before any line (Sapega, 2026-10-15)")
	ck(not _enemies_active(village), "…and stands still while the player is locked in the dialogue")
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	for i in 4: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "the game menu does not open during a dialogue (B16, D136)")

	print("[2] Arrival line ends → the bandit's taunt, bandit still frozen")
	while started.size() < 2:
		await _press(dm)
		if not dm.is_dialogue_active():
			for i in 20: await process_frame
	ck(started == ["ArrivalToVillage", "FightWithBandit"], "the taunt follows (%s)" % [started])
	ck(dm.current_dialogue_box.visible, "the box is visible during the taunt")
	ck(not _enemies_active(village), "the bandit is still frozen during the taunt")

	print("[3] Taunt ends → the bandit comes alive and the player can move")
	await _drain(dm)
	for i in 30: await process_frame
	ck(_enemy_count(village) == 1, "one bandit (%d)" % _enemy_count(village))
	ck(_enemies_active(village), "the bandit is active")
	ck(not game.player.event, "the player is unlocked")
	ck(not paused, "the game is not paused")
	ck(not village.find_children("*", "Node", true, false).any(func(n: Node) -> bool:
			return n.get_script() != null and String(n.get_script().resource_path).ends_with("CombatTraining.gd")),
			"D743: no combat training in the fight")
	ck(game.current_objective == "Defeat the bandit in the street", "objective: the ordinary fight at once (%s)" % game.current_objective)
	ck(not ResourceLoader.exists("res://SampleProject/Scripts/Gameplay/CombatTraining.gd"), "the training script is gone")

	print("[4] Killing the bandit with real damage finishes the street fight")
	for n in village.find_children("*", "CharacterBody2D", true, false):
		if n.is_in_group(&"enemies") and n.is_alive():
			ck(n.min_health == 0, "the bandit can fall: no training floor on his HP (%d)" % n.min_health)
			n.take_damage(n.Max_Health * 10)
	for i in 20: await process_frame
	ck(game.get_quest_flag("village_fight_complete"), "village_fight_complete set")
	ck(village.get_current_state_name() == "CHECK_HOUSE", "on to the house (%s)" % village.get_current_state_name())

	print("[5] \"Oh no, the house!\" (D140): the arrow leads to his door")
	ck(started.has("Village_AfterFight"), "the after-fight line plays (%s)" % [started])
	ck(game.current_objective == "Check on the house", "objective: Check on the house (%s)" % game.current_objective)
	var elder_door: Area2D = village.get_node(^"ElderDoor")
	ck(game.objective_marker() != null and game.objective_marker().global_position == elder_door.global_position,
			"the objective points at the house door ElderDoor (%s)" % [game.objective_marker()])
	ck(not village.has_node(^"OldManQuest"), "the grandfather is not in the street (D438)")
	await _drain(dm)

	print("[6] Through his door: the old man is inside, heals Kusakam and does not ask to be healed (D252, D261, D438)")
	var sm: Node = sl.get_skill_manager()
	var tray: Node = get_first_node_in_group(&"tip_tray")
	game.player.take_damage(30)
	elder_door.get_node(^"Interactable").interacted.emit()
	for i in 120:
		if game.map.scene_file_path == HOUSE:
			break
		await process_frame
	for i in 20: await process_frame
	var house: Node = game.map
	ck(house.scene_file_path == HOUSE, "ElderDoor → ElderHouse (%s)" % house.scene_file_path.get_file())
	ck(game.player.global_position.distance_to(house.get_node(^"ExitDoor").global_position) < 48.0,
			"the hero stands at the house's door he came in by (%s)" % game.player.global_position)
	ck(house.get_current_state_name() == "OLD_MAN_WAITING", "the old man waits inside (%s)" % house.get_current_state_name())
	ck(game.current_objective == "Talk to the old man" and game.objective_marker() == house.get_node(^"ObjectiveTargets/old_man"),
			"objective: Talk to the old man, the arrow on him (%s)" % game.current_objective)
	game.player.global_position = house.get_node(^"StateChangeTrigger_OldMan").global_position
	game.player.velocity = Vector2.ZERO
	for i in 30: await process_frame
	ck(house.get_current_state_name() == "OLD_MAN_HEALING", "the trigger beside him starts the old man's scene in his house")
	# Українське джерело (DqdReader читає файл мовою гри — тут англійську).
	var healing_source := FileAccess.get_file_as_string("res://dialogue_quest/OldMan_Healing.dqd")
	ck(not healing_source.contains("Длань") and not healing_source.contains("твоя черга"),
			"OldMan_Healing no longer asks Kusakam to heal him (%s)" % [healing_source])
	await _drain(dm)
	for i in 10: await process_frame
	ck(started.has("OldMan_Outside") and started.has("OldMan_Healing"), "meeting and healing lines (%s)" % [started])
	ck(game.player.current_health == game.player.Max_Health, "the old man healed Kusakam to full")
	ck(game.player.get_children().any(func(c: Node) -> bool: return c.scene_file_path.ends_with("HealingPalm.tscn")),
			"the healing light wraps Kusakam on screen, no narration line (D437)")
	ck(sm.is_starting_skill("healing_palm") and sm.get_equipped_skill(0) == "healing_palm",
			"the Village teaches no Healing Palm: it is the starting one in slot 1 (D815, %s)" % [sm.get_equipped_skills()])
	ck(not tray.has("healing_palm"), "no Healing Palm tutorial in the Village (%s)" % [tray.ids()])

	print("[7] Straight on to his decision, the gift and the key")
	ck(not started.has("OldMan_Treated"), "no 'after you healed me' talk (%s)" % [started])
	ck(started.has("OldMan_Decision"), "then the decision and the gift (%s)" % [started])
	ck(game.get_quest_flag("village_oldman_met") and game.get_quest_flag("village_oldman_healed")
			and game.get_quest_flag("village_oldman_complete"), "met → healed → complete flags set, in the house")
	ck(game.get_quest_flag("village_grandfather_key") and sl.get_inventory_manager().get_item_count("grandfather_key") == 1,
			"Grandfather's old key, once")
	ck(house.get_current_state_name() == "DONE" and game.current_objective == "Leave the village"
			and game.objective_marker() == house.get_node(^"ObjectiveTargets/canyon_bridge"),
			"objective: Leave the village, the arrow on the house door (%s)" % game.current_objective)
	ck(house.get_node(^"ObjectiveTargets/canyon_bridge").global_position == house.get_node(^"ExitDoor").global_position,
			"the house's canyon_bridge mark is its door")

	print("[7b] Out through the same door: back at ElderDoor, then leaving the village")
	await _drain(dm)
	await _close_modal(sl)  # «You obtained:» подарунка діда
	house.get_node(^"ExitDoor").get_node(^"Interactable").interacted.emit()
	for i in 120:
		if game.map.scene_file_path == VILLAGE:
			break
		await process_frame
	for i in 20: await process_frame
	village = game.map
	ck(village.scene_file_path == VILLAGE, "ExitDoor → Village (%s)" % village.scene_file_path.get_file())
	ck(game.player.global_position.distance_to(village.get_node(^"ElderDoor").global_position) < 48.0,
			"the hero comes out at ElderDoor, the door he went in by (%s)" % game.player.global_position)
	ck(village.get_current_state_name() == "LEAVING_VILLAGE" and started.has("LeavingVillage"),
			"outside: on to leaving, Kusakam's 'time to go' (%s)" % village.get_current_state_name())
	await _drain(dm)
	for i in 10: await process_frame
	ck(game.get_quest_flag("village_left_complete"), "village_left_complete set (the canyon gate opens on it)")
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
