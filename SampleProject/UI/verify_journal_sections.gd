extends SceneTree

## Journal sections — Quests, Characters, Bestiary (BACKLOG 13, D290), real input:
##   godot --headless --path . --script res://SampleProject/UI/verify_journal_sections.gd
##   1. The Journal opens on Quests (tab pressed, current objective shown); Characters is empty at the start.
##   2. A talk with the grandfather → Characters lists "Дед" with his role (mouse click on the tab).
##   3. A bandit killed and a jackal seen → Bestiary (pad RB / key E) shows both, kills counted.
##   4. Q / LB go back; Enter on a tab selects it; D-pad up from the first row reaches the tabs.
##   5. The records are saved with the player; every DialogueQuest character is in the codex or not_listed.

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _rows(journal: Node) -> Array:
	return journal._entry_list.get_children().filter(func(r: Control) -> bool: return r.visible).map(func(r: Button) -> String: return r.text)


func _open_journal(sl: Node) -> Node:
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 14)
	var menu: Node = get_first_node_in_group("game_menu")
	await Kit.mouse(self, menu.get_node("%JournalButton"))
	await Kit.frames(self, 6)
	return menu.find_child("JournalComponent", true, false)


func _spawn(game: Node, kind: String) -> Node:
	var enemy: Node = load("res://SampleProject/Scenes/Characters/Enemies/%s.tscn" % ("default_enemy" if kind == "melee" else "enemy_" + kind)).instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
	enemy.position = game.player.position + Vector2(600, -40)
	game.map.add_child(enemy)
	return enemy


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: banners, no pause
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	game.set_quest_flag("village_abduction_complete", true)  # Journal відкрита сюжетом (D151)

	print("[1] Quests first; Characters empty at the start")
	var journal: Node = await _open_journal(sl)
	ck(journal.is_visible_in_tree() and journal.section == "quests" and journal.get_node("%QuestsTab").button_pressed, "opens on Quests")
	ck(journal._heading.text == "Quests" and not _rows(journal).is_empty(), "quest list shown (%s)" % [_rows(journal)])
	await Kit.mouse(self, journal.get_node("%CharactersTab"))
	ck(journal.section == "characters" and journal.get_node("%CharactersTab").button_pressed, "mouse click → Characters")
	ck(journal._empty_state.visible and journal._empty_state.text == "You have not met anyone yet.", "nobody met yet (Kusakam's own lines do not count)")
	ck(not journal._objective_panel.visible, "no quest objective on Characters")
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 6)

	print("[2] Talking to the grandfather records him")
	sl.get_dialogue_manager().start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	await Kit.frames(self, 4)
	await Kit.drain(self)
	journal = await _open_journal(sl)
	await Kit.mouse(self, journal.get_node("%CharactersTab"))
	ck(_rows(journal) == ["Дед"], "Characters: the grandfather (%s)" % [_rows(journal)])
	ck(journal._detail_state.text == "KUSAKAM'S GRANDFATHER" and journal._detail_description.text.contains("lizardfolk"), "his role and text (%s)" % journal._detail_state.text)
	ck(journal._list_header.text == "PEOPLE MET", "list caption (%s)" % journal._list_header.text)
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 6)

	print("[3] Bestiary: met and killed")
	var bandit: Node = _spawn(game, "melee")
	_spawn(game, "fast")
	await Kit.frames(self, 4)
	bandit.take_damage(99999)
	await Kit.frames(self, 4)
	journal = await _open_journal(sl)
	await Kit.pad(self, JOY_BUTTON_RIGHT_SHOULDER)
	ck(journal.section == "characters", "pad RB → Characters")
	await Kit.key(self, KEY_E)
	ck(journal.section == "bestiary" and journal._heading.text == "Bestiary", "key E → Bestiary")
	ck(_rows(journal) == ["Desert Bandit", "Jackal"], "both enemies listed (%s)" % [_rows(journal)])
	ck(journal._detail_state.text == "DEFEATED: 1", "the bandit: defeated 1 (%s)" % journal._detail_state.text)
	var jackal_row: Control = journal._entry_list.get_children().filter(func(r: Control) -> bool: return r.visible)[1]
	await Kit.mouse(self, jackal_row)
	ck(journal._detail_title.text == "Jackal" and journal._detail_state.text == "NOT YET DEFEATED", "the jackal: not yet defeated (%s)" % journal._detail_state.text)

	print("[4] Back with Q / LB; Enter on a tab; D-pad up reaches the tabs")
	await Kit.key(self, KEY_Q)
	ck(journal.section == "characters", "key Q → Characters")
	await Kit.pad(self, JOY_BUTTON_LEFT_SHOULDER)
	ck(journal.section == "quests", "pad LB → Quests")
	var first_row: Control = journal._entry_list.get_children().filter(func(r: Control) -> bool: return r.visible and r.focus_mode != Control.FOCUS_NONE)[0]
	first_row.grab_focus()
	await process_frame
	for i in 3:
		if root.gui_get_focus_owner() in [journal.get_node("%QuestsTab"), journal.get_node("%CharactersTab"), journal.get_node("%BestiaryTab")]:
			break
		await Kit.pad(self, JOY_BUTTON_DPAD_UP)
	var tab: Control = root.gui_get_focus_owner()
	ck(tab != null and tab.get_parent().name == "SectionTabs", "D-pad up from the list reaches the tabs (%s)" % (tab.name if tab else "none"))
	journal.get_node("%BestiaryTab").grab_focus()
	await process_frame
	await Kit.key(self, KEY_ENTER)
	ck(journal.section == "bestiary", "Enter on the Bestiary tab selects it")

	print("[5] Saved; every speaker accounted for")
	var saved: Dictionary = root.get_node("SaveSystem").player_data_module.save()
	ck(saved.journal.people == ["GRANDFATHER"] and int(saved.journal.enemies.melee) == 1 and int(saved.journal.enemies.fast) == 0,
			"journal saved with the player (%s)" % [saved.journal])
	var codex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/journal_people.json"))
	var listed: Array = codex.people.map(func(p: Dictionary) -> String: return p.id) + codex.not_listed
	var missing: Array = root.get_node("DialogueQuest").CharacterDB.get_character_registry().keys().filter(func(id: String) -> bool: return not id in listed)
	ck(missing.is_empty(), "every DialogueQuest character has a codex entry or is not_listed (missing %s)" % [missing])

	sl.get_ui_manager().close_game_menu()
	await Kit.frames(self, 4)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
