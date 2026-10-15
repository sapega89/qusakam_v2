extends SceneTree

## Game Menu як одна сцена (D116, design/game_menu_single_scene_plan.md).
##   godot --headless --path . --script res://SampleProject/UI/verify_game_menu.gd
##
## Перевіряє:
##   0. На старті відкрита лише Misc, центр порожній (D151).
##   1. Початковий стан береться зі сцени: Inventory видимий і натиснутий.
##   2. Натискання вкладки (справжній ui_accept) → рівно одна панель видима,
##      рівно одна кнопка натиснута, фокус на ній (B7).
##   3. switch_to_tab() ззовні робить те саме.
##   4. Вкладки не зсуваються при виборі (B38).
##   5. Вказівник ▶ рівно один: за фокусом/мишею, інакше на натиснутій (D118).

const TABS := ["Inventory", "Equipment", "World Map", "Misc", "Journal", "Skills", "Status"]

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	# [0] «сцена окремо (F6), без гри» прибрано разом із запасними шляхами: меню потребує гру.
	await process_frame
	await process_frame
	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	# Вступ Canyon — діалог; під час діалогу меню не відкривається (D136).
	var intro_dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	intro_dm.bubble_time_scale = 0.0  # облачка (D178) без очікування
	for intro_round in 10:
		for i in 200:
			if not intro_dm.is_dialogue_active():
				break
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame

	print("[0] at the very start only Misc is open; the story unlocks the rest")
	var unlock_flags := ["village_abduction_complete", "village_oldman_healed", "village_oldman_gift", "village_left_complete"]
	var flags: Dictionary = game.get_quest_flags().duplicate()
	for f in unlock_flags:
		flags[f] = false
	game.set_quest_flags(flags)
	ui.open_game_menu()
	for i in 16: await process_frame
	var locked_menu: Node = get_first_node_in_group("game_menu")
	var open_tabs: Array = []
	for b in (locked_menu.get_node("%InventoryButton") as Button).button_group.get_buttons():
		if not b.disabled:
			open_tabs.append(b.get_meta("tab"))
		elif b.focus_mode != Control.FOCUS_NONE:
			ck(false, "%s: locked tab takes no focus" % b.get_meta("tab"))
	ck(open_tabs == ["Misc"], "only Misc open at the start %s" % str(open_tabs))
	ck(locked_menu.current_tab_name == "Misc", "opens on Misc (%s)" % locked_menu.current_tab_name)
	ck(_visible_panels(locked_menu.get_node("%ContentRoot")).is_empty(), "centre empty: Settings only after Misc → Settings")
	ck(root.gui_get_focus_owner() == locked_menu.get_node("%MiscButton"), "focus on Misc")
	ui.close_game_menu()
	for i in 16: await process_frame
	for f in unlock_flags:
		flags[f] = true
	game.set_quest_flags(flags)

	ui.open_game_menu()
	for i in 16: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	ck(menu != null, "game menu opens")
	if menu == null:
		_done()
		return
	var content: Node = menu.get_node("%ContentRoot")
	var buttons: Array = (menu.get_node("%InventoryButton") as Button).button_group.get_buttons()

	print("[1] initial state comes from the scene")
	ck(buttons.size() == 7, "7 tab buttons in one ButtonGroup")
	ck(content.get_child_count() == 8, "7 tab panels + the Tutorial list in ContentRoot")
	ck(_visible_panels(content) == ["InventoryComponent"], "only Inventory visible on open")
	ck(_pressed(buttons) == ["InventoryButton"], "only Inventory pressed on open")
	ck(menu.current_tab_name == "Inventory", "current_tab_name read from the scene")
	ck(root.gui_get_focus_owner() == menu.get_node("%InventoryButton"), "focus on the pressed tab")

	print("[2] pressing each tab")
	var xs: Array[float] = []
	for b in buttons:
		var button := b as Button
		var before_panels := _visible_panels(content)
		var before_pressed := _pressed(buttons)
		var before_tab: String = menu.current_tab_name
		button.grab_focus()
		_accept()
		for i in 6: await process_frame
		var tab: String = button.get_meta("tab")
		if tab == "Misc":
			# Misc лише відкриває список пунктів; налаштування — тільки після Settings.
			ck(ui.get_modal_layer().active_modal != null, "Misc: opens the list of items")
			ck(_visible_panels(content) == before_panels, "Misc: centre unchanged, no Settings %s" % str(_visible_panels(content)))
			ck(_pressed(buttons) == before_pressed, "Misc: previous tab stays pressed %s" % str(_pressed(buttons)))
			ck(menu.current_tab_name == before_tab, "Misc: current_tab_name unchanged (%s)" % menu.current_tab_name)
		else:
			var panel: Node = button.get_node(button.get_meta("panel"))
			ck(_visible_panels(content) == [String(panel.name)], "%s: only its panel visible" % tab)
			ck(_pressed(buttons) == [String(button.name)], "%s: only its button pressed %s" % [tab, str(_pressed(buttons))])
			ck(menu.current_tab_name == tab, "%s: current_tab_name" % tab)
			ck(_pointed(buttons) == [String(button.name)], "%s: pointer on it %s" % [tab, str(_pointed(buttons))])
		xs.append(button.global_position.x)
		# Misc відкриває модалку — закриваємо, щоб не заважала наступній вкладці.
		var layer = ui.get_modal_layer()
		if layer and layer.active_modal:
			layer.active_modal.chosen.emit("cancel")
			for i in 6: await process_frame
		ck(root.gui_get_focus_owner() == button, "%s: focus stays on it" % tab)
	ck(xs.min() == xs.max(), "tabs keep one x when selected (B38): %s" % str(xs))

	print("[3] switch_to_tab from code")
	for tab in TABS:
		menu.switch_to_tab(tab)
		await process_frame
		var pressed := _pressed(buttons)
		ck(pressed.size() == 1 and buttons.filter(func(b): return String(b.name) == pressed[0])[0].get_meta("tab") == tab,
				"%s: its button pressed" % tab)
		ck(_visible_panels(content).size() == 1, "%s: one panel visible" % tab)
		ck(_pointed(buttons) == pressed, "%s: pointer on the pressed tab (no double highlight)" % tab)

	print("[4] pointer follows hover, falls back to the pressed tab")
	menu.switch_to_tab("Inventory")
	var inv := menu.get_node("%InventoryButton") as Button
	var skills := menu.get_node("%SkillsButton") as Button
	inv.grab_focus()
	await process_frame
	skills.mouse_entered.emit()
	for i in 3: await process_frame
	ck(_pointed(buttons) == ["SkillsButton"], "hover moves the pointer %s" % str(_pointed(buttons)))
	ck(_pressed(buttons) == ["InventoryButton"], "hover does not switch the tab")
	menu.focus_router.focus_content()
	for i in 3: await process_frame
	ck(_pointed(buttons) == ["InventoryButton"], "focus in content -> pointer back on pressed %s" % str(_pointed(buttons)))

	ui.close_game_menu()
	for i in 6: await process_frame
	_done()


func _accept() -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"ui_accept"
		ev.pressed = down
		root.push_input(ev)


func _visible_panels(content: Node) -> Array:
	return content.get_children().filter(func(c): return c.visible).map(func(c): return String(c.name))


func _pressed(buttons: Array) -> Array:
	return buttons.filter(func(b): return b.button_pressed).map(func(b): return String(b.name))


func _pointed(buttons: Array) -> Array:
	return buttons.filter(func(b): return b.theme_type_variation == &"SidebarTabOn").map(func(b): return String(b.name))


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
