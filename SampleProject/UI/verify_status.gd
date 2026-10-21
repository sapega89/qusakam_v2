extends SceneTree

## Самоперевірка екрана Status (Phase 5.2).
##
## Запуск:
##   godot --headless --path . --script res://SampleProject/UI/verify_status.gd

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _initialize() -> void:
	await process_frame; await process_frame
	# Меню існує лише в запущеній грі (Game, гравець, нижня панель) — тест відкриває його там само.
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var boot_game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(boot_game)
	current_scene = boot_game
	for i in 40: await process_frame
	# Вступ Canyon — діалог; під час діалогу меню не відкривається (D136).
	var intro_dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for intro_round in 10:
		for i in 200:
			if not intro_dm.is_dialogue_active():
				break
			intro_dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var gm: Node = sl.get_game_manager()
	sl.get_xp_manager().add_xp(250)

	print("[1] open Status")
	ui.open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Status")
	for i in 8: await process_frame
	var st: Node = menu.find_child("StatsComponent", true, false)
	ck(st != null, "StatsComponent present")
	if st == null: _done(); return
	ck(st.visible, "Status visible after tab switch")
	ck(st.game_manager != null, "Status has a valid game_manager")

	print("[2] real data, no fabrication")
	var ch = gm.get_active_character()
	# B55: нова гра грає за Кусакама (player_3), не за Астрита.
	ck(sl.get_character_manager().get_active_character_id() == "player_3", "new game's active character is player_3 (%s)" % sl.get_character_manager().get_active_character_id())
	ck(String(ch.name) == "Кусакам" and ch.class_id == "wizard", "active character is Kusakam, wizard (%s, %s)" % [ch.name, ch.class_id])
	ck(gm.player_state.character_id == "player_3" and gm.player_state.class_id == "wizard", "player_state follows Kusakam (%s, %s)" % [gm.player_state.character_id, gm.player_state.class_id])
	var first_card: Control = get_first_node_in_group("ui_party_panel")._cards.get_child(0)
	ck(first_card.get_meta(&"character_id") == "player_3" and first_card.get_node(^"Row/Info/Head/Name").text == "Кусакам",
			"first party card is Kusakam (%s)" % first_card.get_node(^"Row/Info/Head/Name").text)
	ck(st._name_label.text == String(ch.name), "name from CharacterManager (%s)" % st._name_label.text)
	ck(st._level_label.text == "Lv.%d" % sl.get_xp_manager().get_level(), "level from XPManager (%s)" % st._level_label.text)
	ck(st._next_level_value.text.ends_with("EXP"), "EXP to next level shown (%s)" % st._next_level_value.text)
	var sm: Node = sl.get_skill_manager()
	ck(st._jp_value.text == "%d JP" % sm.get_job_points(), "JP Obtained from SkillManager (D11: %s)" % st._jp_value.text)
	var sp_meter: Control = st._sp_meter
	ck(sp_meter.get_node("Head/Value").text == str(sm.get_current_sp()), "Max SP meter current (D12: %s)" % sp_meter.get_node("Head/Value").text)
	ck(sp_meter.get_node("Head/Max").text == " / %d" % sm.get_max_sp(), "Max SP meter max (D12: %s)" % sp_meter.get_node("Head/Max").text)
	ck(is_equal_approx(sp_meter.get_node("Bar").value, float(sm.get_current_sp())), "Max SP bar filled to current")

	print("[3] attributes come from StatCalculator")
	ck(st._left_attrs.get_child_count() == 4, "4 left attribute rows")
	ck(st._right_attrs.get_child_count() == 4, "4 right attribute rows")
	var hp_txt: String = st._hp_meter.get_node("Head/Value").text
	ck(hp_txt != st.PLACEHOLDER, "Max HP has a real value (%s)" % hp_txt)
	# D199: Phys. Atk. — сила й спорядження плюс бонус рівня, те саме число, що й удар гравця.
	var expected: int = StatCalculator.calculate_physical_damage(ch.attributes, ch.get_equipment_stats()) + sl.get_xp_manager().get_damage_bonus()
	var shown: String = st._left_attrs.get_child(0).get_child(0).get_child(2).text
	ck(shown == str(expected), "Phys. Atk. matches StatCalculator (%s == %d)" % [shown, expected])

	print("[3b] attribute points (D335): unspent in the header, spent per attribute")
	var attrs: Node = sl.get_attribute_manager()
	ck(st._attr_points_value.text == str(attrs.get_unspent()), "unspent attribute points shown (%s)" % st._attr_points_value.text)
	ck(st._point_attrs.get_children().map(func(p): return p.get_child(0).text) == ["Strength", "Agility", "Vitality", "Wisdom"], "four attributes from data")
	var body: Control = st.get_node(^"Columns/Center/Body")
	ck(body.get_combined_minimum_size().y <= st.size.y, "Status still fits its height (%d of %d)" % [body.get_combined_minimum_size().y, st.size.y])

	print("[4] live refresh")
	var before: String = st._level_label.text
	sl.get_xp_manager().add_xp(100000)
	for i in 4: await process_frame
	ck(st._level_label.text != before, "level_up refreshes the screen (%s -> %s)" % [before, st._level_label.text])
	ck(st._jp_value.text == "%d JP" % sm.get_job_points(), "JP follows level-up live (%s)" % st._jp_value.text)
	ck(st._attr_points_value.text == str(attrs.get_unspent()) and attrs.get_unspent() >= 5, "attribute points follow level-up live (%s)" % st._attr_points_value.text)
	var atk_before: String = st._left_attrs.get_child(0).get_child(0).get_child(2).text
	ck(attrs.spend({"strength": 2, "wisdom": 1}) == 0, "spent 2 Strength, 1 Wisdom")
	for i in 2: await process_frame
	ck(st._point_attrs.get_node(^"strength/Value").text == "2" and st._point_attrs.get_node(^"wisdom/Value").text == "1", "the spent points show per attribute")
	ck(int(st._left_attrs.get_child(0).get_child(0).get_child(2).text) == int(atk_before) + 2, "Phys. Atk. +2 from Strength (%s → %s)" % [atk_before, st._left_attrs.get_child(0).get_child(0).get_child(2).text])

	print("[5] party panel swap")
	var party: Node = get_first_node_in_group("ui_party_column")
	ck(party != null, "party column reachable")
	ck(party != null and not party.visible, "party column hidden while Status is open")
	# Час гри береться зі слота; раніше мітка лишалась "00:00:00" назавжди (set_playtime ніхто не кликав).
	sl.get_save_system()._session_base_playtime_sec = 3725.0
	var party_panel: Node = get_first_node_in_group("ui_party_panel")
	party_panel.refresh()
	ck(party_panel._playtime_value.text.begins_with("01:02:"), "party panel shows the slot's real play time (%s)" % party_panel._playtime_value.text)
	menu.switch_to_tab("Inventory")
	for i in 6: await process_frame
	ck(party != null and party.visible, "party column restored when leaving Status")

	print("[6] back / close")
	ui.close_game_menu()
	for i in 6: await process_frame
	ck(get_first_node_in_group("game_menu") == null, "menu closes from Status flow")
	ck(not paused, "game unpauses")
	_done()

func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
