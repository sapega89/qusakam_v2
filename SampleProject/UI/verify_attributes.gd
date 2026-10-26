extends SceneTree

## Очки атрибутів (BACKLOG 44, D335): 5 за рівень, що дає очко (attributes.json), збереження, скидання (D282),
## і вкладення на екрані Status (D741) тим самим «вибрати → Accept» (D330) — мишею, клавішами й геймпадом.
##   godot --headless --path . --script res://SampleProject/UI/verify_attributes.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _mouse(node: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var vp: Viewport = node.get_viewport()
	var pos: Vector2 = node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame

func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)  # headless скидає вікно до 64×64, а миша клікає в координатах 1920×1080
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	var gm: Node = sl.get_game_manager()
	var sm: Node = sl.get_skill_manager()
	var xp: Node = sl.get_xp_manager()
	var attrs: Node = sl.get_attribute_manager()
	var AR = load("res://SampleProject/Scripts/Managers/Gameplay/AttributeManager.gd").Result

	print("[1] Data: four attributes, 5 points per level")
	ck(attrs.attribute_ids() == ["strength", "agility", "vitality", "wisdom"], "Strength, Agility, Vitality, Wisdom from attributes.json (%s)" % [attrs.attribute_ids()])
	ck(attrs.points_per_level == 5, "5 points per level")
	ck(xp.get_level() == 1 and attrs.get_unspent() == 0 and attrs.spent_total() == 0, "a new hero has none")
	var jp: int = sm.get_job_points()
	xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	ck(attrs.get_unspent() == 5, "level 2 gives 5 attribute points (%d)" % attrs.get_unspent())
	ck(sm.get_job_points() == jp + 1, "and still 1 skill point (D279)")
	while xp.get_level() < 4:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	ck(attrs.get_unspent() == 15, "level 4: 15 points")

	print("[2] What one point gives")
	var player: Node = gm.get_current_player()
	var atk: int = gm.calculate_physical_damage()
	var hp: int = gm.calculate_max_health()
	var crit: float = gm.calculate_critical_chance()
	var dodge: float = gm.calculate_dodge_chance()
	var speed: float = gm.calculate_attack_speed()
	var max_sp: int = sm.get_max_sp()
	ck(attrs.spend({"strength": 3}) == AR.OK, "spend 3 on Strength")
	ck(gm.calculate_physical_damage() == atk + 3 and player.combat.hit_damage() == atk + 3, "Strength: +1 Phys. Atk. per point, the hit too (%d → %d)" % [atk, gm.calculate_physical_damage()])
	ck(attrs.spend({"vitality": 5}) == AR.OK, "spend 5 on Vitality")
	await process_frame
	ck(gm.calculate_max_health() == hp + 20 and player.Max_Health == hp + 20, "Vitality: +4 Max HP per point, the hero's bar too (%d → %d)" % [hp, player.Max_Health])
	ck(attrs.spend({"agility": 2, "wisdom": 5}) == AR.OK, "spend 2 on Agility and 5 on Wisdom at once")
	ck(is_equal_approx(gm.calculate_critical_chance(), crit + 0.008), "Agility: +0.4 %% crit per point (%.3f)" % gm.calculate_critical_chance())
	ck(is_equal_approx(gm.calculate_dodge_chance(), dodge + 0.006), "Agility: +0.3 % evasion per point")
	ck(is_equal_approx(gm.calculate_attack_speed(), speed + 0.01), "Agility: +0.5 % speed per point")
	ck(sm.get_max_sp() == max_sp + 10, "Wisdom: +2 Max SP per point (%d → %d)" % [max_sp, sm.get_max_sp()])
	sm.unlock_skill("healing_palm")  # ранг 1 — інакше scaled рахує ранг 0
	ck(sm.scaled("healing_palm", 40) == 42, "Wisdom: +1 %% skill power per point (heal 40 → %d)" % sm.scaled("healing_palm", 40))
	ck(is_equal_approx(attrs.bonus("sp_per_hit"), 0.25), "Wisdom: +0.05 SP per hit per point (D504)")
	ck(attrs.get_unspent() == 0, "all 15 spent")
	ck(attrs.spend({"strength": 1}) == AR.NOT_ENOUGH_POINTS, "no more points: refused")
	ck(attrs.spend({"luck": 1}) == AR.UNKNOWN_ATTRIBUTE, "an unknown attribute: refused")

	print("[3] Save and load (PlayerDataModule)")
	var pdm = root.get_node("SaveSystem").player_data_module
	var snap: Dictionary = pdm.save()
	ck(snap.has("attributes") and snap.has("attribute_points"), "saved")
	attrs.reset()
	ck(attrs.spent_total() == 0 and attrs.get_unspent() == 15, "reset returns all 15")
	pdm.load_data(snap)
	ck(attrs.get_points("strength") == 3 and attrs.get_points("vitality") == 5 and attrs.get_points("agility") == 2 and attrs.get_points("wisdom") == 5 and attrs.get_unspent() == 0, "loaded back: 3 / 2 / 5 / 5, none unspent")
	ck(gm.calculate_physical_damage() == atk + 3, "the bonus is back after the load")
	var old: Dictionary = snap.duplicate(true)
	old.erase("attributes")
	old.erase("attribute_points")
	pdm.load_data(old)
	ck(attrs.spent_total() == 0 and attrs.get_unspent() == 15, "a save from before attributes: 5 × (level − 1) unspent (%d)" % attrs.get_unspent())

	await _screen(sl, gm, sm, attrs)

	sl.get_ui_manager().close_game_menu()
	for i in 6: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)


## Екран Status: рядки атрибутів у тому ж «вибрати → Accept» (D330, D331), поруч зі статами (D741).
func _screen(sl: Node, gm: Node, sm: Node, attrs: Node) -> void:
	print("[4] The Status screen: + / − are pending until Accept")
	sl.get_ui_manager().open_game_menu()
	for i in 14: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Status")
	for i in 8: await process_frame
	var ui: Node = menu.find_child("StatsComponent", true, false)
	ck(ui._attr_rows_box.is_visible_in_tree(), "the attribute rows are on Status (D741)")
	var rows: Dictionary = ui._attribute_rows
	ck(rows.keys() == attrs.attribute_ids(), "four attribute rows from data")
	ck(ui._attr_points_value.text == "15", "15 points to spend shown (%s)" % ui._attr_points_value.text)

	await _mouse(rows["strength"].get_node(^"Plus"))
	await _mouse(rows["strength"].get_node(^"Plus"))
	ck(attrs.get_points("strength") == 0 and ui.plan.attribute_points("strength") == 2, "mouse: two + clicks are pending, nothing spent")
	ck(rows["strength"].get_node(^"Value").text == "0 +2", "the row shows the pending +2 (%s)" % rows["strength"].get_node(^"Value").text)
	ck(ui._attr_points_value.text == "13", "points left after the pending picks: 13")
	await _mouse(rows["strength"].get_node(^"Minus"))
	ck(ui.plan.attribute_points("strength") == 1, "mouse: − takes one back")

	print("[5] Keyboard and gamepad on the rows")
	rows["vitality"].get_node(^"Plus").grab_focus()
	await process_frame
	await _pad(JOY_BUTTON_A)
	await _key(KEY_ENTER)
	ck(ui.plan.attribute_points("vitality") == 2, "pad A and Enter on + pick Vitality twice")
	await _pad(JOY_BUTTON_X)
	ck(ui.plan.attribute_points("vitality") == 1, "pad X takes one back")
	await _key(KEY_BACKSPACE)
	ck(ui.plan.attribute_points("vitality") == 0, "Backspace takes one back")
	await _pad(JOY_BUTTON_A)
	for i in 20:
		await _pad(JOY_BUTTON_A)
	ck(ui.plan.attribute_points("vitality") == 14 and ui._attr_points_value.text == "0", "cannot pick more than the points left (14 + 1 Strength)")

	print("[6] Esc drops the pending picks, Accept spends")
	await _key(KEY_ESCAPE)
	await process_frame
	ck(ui.plan.is_empty() and attrs.spent_total() == 0 and ui.is_visible_in_tree(), "Esc drops everything pending, the screen stays open")
	await _mouse(rows["wisdom"].get_node(^"Plus"))
	await _mouse(rows["agility"].get_node(^"Plus"))
	var hp_before: int = gm.calculate_max_health()
	await _pad(JOY_BUTTON_Y)
	for i in 2: await process_frame
	ck(attrs.get_points("wisdom") == 1 and attrs.get_points("agility") == 1 and attrs.get_unspent() == 13, "pad Y accepts: Wisdom 1, Agility 1, 13 left")
	ck(ui.plan.is_empty() and rows["wisdom"].get_node(^"Value").text == "1", "the plan is empty after Accept, the row shows 1")
	ck(gm.calculate_max_health() == hp_before, "Vitality untouched")
	await _mouse(rows["vitality"].get_node(^"Plus"))
	await _mouse(ui._accept_button)
	for i in 2: await process_frame
	ck(attrs.get_points("vitality") == 1 and gm.calculate_max_health() == hp_before + 4, "the Accept button spends with the mouse (+4 HP)")
	await _mouse(rows["strength"].get_node(^"Plus"))
	await _key(KEY_F)
	for i in 2: await process_frame
	ck(attrs.get_points("strength") == 1, "key F accepts")
