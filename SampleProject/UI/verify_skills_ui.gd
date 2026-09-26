extends SceneTree

## Самоперевірка екрана Skills (Phase 5.6).
##   godot --headless --path . --script res://SampleProject/UI/verify_skills_ui.gd
##
## ⚠️ ФІКСТУРИ ТІЛЬКИ ДЛЯ ТЕСТІВ/QA. Вводяться через SkillDatabase.load_from_array()
## і ніколи не потрапляють у продакшн: skills.json лишається порожнім.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Покриває стани з брифу: learned / affordable / not-affordable /
## prerequisite-locked / level-locked / active+SP / passive / cooldown.
const FIXTURES := [
	{"id": "ta_learned", "name": "Test Skill A", "description": "Already learned.",
	 "class_id": "champion", "skill_type": "active", "jp_cost": 10, "sp_cost": 4, "cooldown": 1.5},
	{"id": "tb_afford", "name": "Test Skill B", "description": "Affordable now.",
	 "class_id": "champion", "skill_type": "active", "jp_cost": 30, "sp_cost": 6},
	{"id": "tc_expensive", "name": "Test Skill C", "description": "Too expensive.",
	 "class_id": "champion", "skill_type": "active", "jp_cost": 9000, "sp_cost": 8},
	{"id": "td_prereq", "name": "Test Skill D", "description": "Needs C first.",
	 "class_id": "champion", "skill_type": "active", "jp_cost": 20,
	 "prerequisites": ["tc_expensive"]},
	{"id": "te_level", "name": "Test Skill E", "description": "High level gate.",
	 "class_id": "champion", "skill_type": "passive", "jp_cost": 5, "required_level": 99},
	{"id": "tf_passive", "name": "Test Skill F", "description": "Passive support.",
	 "class_id": "champion", "skill_type": "passive", "jp_cost": 15},
	{"id": "tg_sub", "name": "Test Skill G", "description": "Secondary tree.",
	 "subclass_id": "paladin", "skill_type": "active", "jp_cost": 25, "sp_cost": 3},
	{"id": "th_sub_passive", "name": "Test Skill H", "description": "Secondary passive.",
	 "subclass_id": "paladin", "skill_type": "passive", "jp_cost": 12},
]

func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var gm: Node = sl.get_game_manager()
	var db: Node = root.get_node_or_null("SkillDatabase")
	var sm: Node = sl.get_skill_manager()
	var R = load("res://SampleProject/Scripts/Managers/Gameplay/SkillManager.gd").Result

	print("[1] production empty state does not crash")
	ck(db.skills.is_empty(), "production skills.json is empty")
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Skills")
	for i in 8: await process_frame
	var ui: Node = menu.find_child("SkillsComponent", true, false)
	ck(ui != null, "SkillsComponent present")
	if ui == null:
		_done()
		return
	ck(ui.is_visible_in_tree(), "Skills screen opens via tab")
	ck(ui._empty_label.visible, "honest empty state shown")
	ck(not ui._columns.visible, "columns hidden when no skills")
	ck(ui._jp_value.text.ends_with("JP"), "real JP still displayed (%s)" % ui._jp_value.text)

	print("[2] populated (test fixtures)")
	db.load_from_array(FIXTURES)
	sm.skill_database = db
	gm.player_state["unlocked_skills"] = ["ta_learned"]
	gm.player_state["job_points"] = 50
	sm.set_max_sp(40)
	sm.restore_sp(25)
	ui.update_display()
	for i in 3: await process_frame
	ck(ui._columns.visible, "columns shown when skills exist")
	ck(not ui._empty_label.visible, "empty state hidden")
	ck(ui._rows.size() == 8, "8 rows generated from data (%d)" % ui._rows.size())
	ck(ui._primary_column.get_child_count() > 0, "primary column populated")
	ck(ui._secondary_column.get_child_count() > 0, "secondary column populated")

	print("[3] data-driven, not hardcoded")
	var scene_text: String = FileAccess.open(
		"res://SampleProject/Scenes/Menus/Game/skills_component.tscn", FileAccess.READ).get_as_text()
	var leaked := false
	for fixture in FIXTURES:
		if scene_text.find(String(fixture["name"])) != -1:
			leaked = true
	ck(not leaked, "no fixture names hardcoded in the .tscn")
	var extended: Array = FIXTURES.duplicate()
	extended.append({"id": "tz_new", "name": "Test Skill Z",
		"class_id": "champion", "skill_type": "active", "jp_cost": 1})
	db.load_from_array(extended)
	ui.update_display()
	for i in 2: await process_frame
	ck(ui._rows.has("tz_new"), "a new skill appears without editing the scene")
	db.load_from_array(FIXTURES)
	ui.update_display()
	for i in 2: await process_frame

	print("[4] row states reflect SkillManager verdicts")
	ck(sm.is_unlocked("ta_learned"), "learned skill is unlocked")
	ck(sm.can_unlock("tb_afford") == R.OK, "affordable skill can unlock")
	ck(sm.can_unlock("tc_expensive") == R.NOT_ENOUGH_JP, "expensive skill blocked by JP")
	ck(sm.can_unlock("td_prereq") == R.MISSING_PREREQUISITE, "prerequisite gate reported")
	ck(sm.can_unlock("te_level") == R.LEVEL_TOO_LOW, "level gate reported")
	var hidden_row: Button = ui._rows["td_prereq"]
	ck(hidden_row.get_node("Row/SkillName").text == ui.UNKNOWN_NAME, "prereq-locked row renders ???")
	var learned_row: Button = ui._rows["ta_learned"]
	ck(learned_row.get_node("Row/SkillName").text == "Test Skill A", "learned row shows its name")

	print("[5] selection + details (keyboard parity)")
	var bar: Node = get_first_node_in_group("ui_bottom_bar")
	ui._rows["tb_afford"].grab_focus()
	for i in 3: await process_frame
	ck(ui._selected_id == "tb_afford", "focus selects the row")
	ck(bar._hint_label.text.find("Test Skill B") >= 0, "details published on focus, not just click")
	ck(bar._hint_label.text.find("30 JP") >= 0, "JP cost shown in details")
	ck(bar._hint_label.text.find("6 SP") >= 0, "SP cost shown in details")
	ui._on_row_selected("tc_expensive")
	await process_frame
	ck(bar._hint_label.text.find("Not enough JP") >= 0, "reason comes from SkillManager")
	ui._on_row_selected("te_level")
	await process_frame
	ck(bar._hint_label.text.find("Level too low") >= 0, "level reason surfaced")

	print("[6] unlock through the UI")
	var jp_before: int = sm.get_job_points()
	ui._on_row_selected("tb_afford")
	var verdict: int = ui.try_unlock_selected()
	for i in 3: await process_frame
	ck(verdict == R.OK, "unlock succeeds via UI")
	ck(sm.is_unlocked("tb_afford"), "skill recorded as unlocked")
	ck(sm.get_job_points() == jp_before - 30, "exact JP deducted (%d)" % sm.get_job_points())
	ck(ui._jp_value.text == "%d JP" % sm.get_job_points(), "JP display refreshed immediately")
	ck(ui.try_unlock_selected() == R.ALREADY_UNLOCKED, "duplicate unlock refused through UI")
	ck(sm.get_job_points() == jp_before - 30, "refused duplicate charged nothing")

	print("[7] UI never writes state directly")
	var src: String = FileAccess.open(
		"res://SampleProject/Scripts/Menus/Game/skills_component.gd", FileAccess.READ).get_as_text()
	ck(src.find("player_state[") == -1, "no direct player_state writes")
	ck(src.find("unlocked_skills") == -1, "UI does not touch unlocked_skills")

	print("[8] live event refresh")
	sm.add_job_points(500)
	await process_frame
	ck(ui._jp_value.text == "%d JP" % sm.get_job_points(), "job_points_changed refreshes JP")
	sm.spend_sp(5)
	await process_frame
	ck(ui._sp_value.text == "%d / %d" % [sm.get_current_sp(), sm.get_max_sp()], "sp_changed refreshes SP")

	print("[9] save/load preserves presentation")
	var pdm = root.get_node("SaveSystem").player_data_module
	var snap: Dictionary = pdm.save()
	gm.player_state["unlocked_skills"] = []
	pdm.load_data(snap)
	ui.update_display()
	for i in 2: await process_frame
	ck(sm.is_unlocked("tb_afford"), "unlocked skill survives save/load")
	ck(ui._rows.has("tb_afford"), "row still rendered after reload")

	print("[10] navigation + unaffected systems")
	ck(not ("abilities" in gm.player_state), "traversal Player.abilities unaffected")
	menu.switch_to_tab("Inventory")
	for i in 5: await process_frame
	ck(not ui.is_visible_in_tree(), "leaving Skills hides it")
	var party: Node = get_first_node_in_group("ui_party_panel")
	ck(party != null and party.visible, "party panel restored on leave")
	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "menu closes")
	ck(not paused, "game unpauses")
	_done()

func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
