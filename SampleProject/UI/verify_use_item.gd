extends SceneTree

## Випити зілля з інвентаря (D127).
##   godot --headless --path . --script res://SampleProject/UI/verify_use_item.gd
##
## Справжні натискання (push_input), а не виклики функцій:
##   1. Enter на зіллі → фокус на картці партії; приглушено тих, кого лікувати не можна.
##   2. Enter на картці → підтвердження з HP «до → після».
##   3. Use → HP росте, зілля на одне менше, фокус назад в інвентар.
##   3b. Cancel у підтвердженні — назад до вибору персонажа (B46).
##   4. Esc під час вибору — скасування, нічого не витрачено, меню відкрите.
##   5. Повне HP — зілля не витрачається, нижня панель пояснює чому.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _press(action: StringName) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		root.push_input(ev)
		await process_frame
	for i in 4: await process_frame


func _potion_row(inv: Node) -> Control:
	for i in inv.items.size():
		if inv.items[i].get("id", "") == "potion":
			return inv._item_list.get_child(i)
	return null


func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	# Як кнопка New Game: без цього Game.tscn вантажить справжній сейв гравця.
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	# Вступ Canyon — діалог; під час діалогу меню не відкривається (D136).
	var intro_dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for intro_round in 10:
		for i in 200:
			if not intro_dm.is_dialogue_active():
				break
			intro_dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame

	var player: Node = sl.get_game_manager().get_current_player()
	var inventory: Node = sl.get_inventory_manager()
	inventory.add_item("potion", 5)
	player.current_health = 40
	var start_count: int = inventory.get_item_count("potion")

	# Середина гри: Inventory вже відкрита сюжетом (D151).
	game.set_quest_flag("village_oldman_gift", true)
	ui.open_game_menu()
	for i in 16: await process_frame
	var inv: Node = get_first_node_in_group("game_menu").find_child("InventoryComponent", true, false)
	var panel: Node = get_first_node_in_group("ui_party_panel")
	var bar: Node = get_first_node_in_group("ui_bottom_bar")
	ck(inv != null and panel != null, "inventory and party panel present")

	print("[1] Enter on a potion moves focus to the party")
	var row: Control = _potion_row(inv)
	ck(row != null, "potion row listed")
	row.grab_focus()
	await process_frame
	await _press(&"ui_accept")
	var focus: Control = root.gui_get_focus_owner()
	ck(focus != null and focus.name == "Select" and focus.get_parent().get_meta(&"character_id", "") == "player_3",
			"focus on the active character's card (%s)" % (focus.get_path() if focus else "none"))
	var others: Array = panel._visible_cards().filter(func(c): return c.get_meta(&"character_id") != "player_3")
	ck(others.all(func(c): return c.modulate.a < 1.0 and c.get_node("Select").focus_mode == Control.FOCUS_NONE),
			"characters without HP cannot be chosen")
	ck(bar._hint_label.text.begins_with("Choose who drinks"), "bottom bar asks whom (%s)" % bar._hint_label.text)

	print("[2] Enter on the card asks for confirmation")
	await _press(&"ui_accept")
	var modal: Node = ui.get_modal_layer().active_modal
	ck(modal != null, "confirmation open")
	var texts: String = " ".join(modal.find_children("*", "Label", true, false).map(func(l): return l.text)) if modal else ""
	ck(texts.contains("Use Potion?") and texts.contains("HP 40 → 90 / 100"), "says what will happen (%s)" % texts)

	print("[3] Use heals and spends one potion")
	if modal:
		modal.chosen.emit("confirm")
	for i in 8: await process_frame
	ck(player.current_health == 90, "HP 40 → 90 (%d)" % player.current_health)
	ck(inventory.get_item_count("potion") == start_count - 1, "one potion spent")
	var hp_label: Label = panel._visible_cards()[0].get_node("Row/Info/Bars/Hp/Head/Value")
	ck(hp_label.text == "90/100", "party card shows the new HP (%s)" % hp_label.text)
	ck(not panel.is_selecting(), "party cards back to normal")
	var back: Control = root.gui_get_focus_owner()
	ck(back != null and inv.is_ancestor_of(back), "focus back in the inventory (%s)" % (back.get_path() if back else "none"))

	print("[3b] Cancel in the confirmation goes back to choosing whom (B46)")
	row = _potion_row(inv)
	row.grab_focus()
	await process_frame
	await _press(&"ui_accept")
	await _press(&"ui_accept")
	modal = ui.get_modal_layer().active_modal
	ck(modal != null, "confirmation open again")
	if modal:
		modal.chosen.emit("cancel")
	for i in 6: await process_frame
	ck(panel.is_selecting(), "back to choosing a character, not to the item")
	focus = root.gui_get_focus_owner()
	ck(focus != null and focus.name == "Select", "focus on a party card (%s)" % (focus.get_path() if focus else "none"))
	ck(bar._hint_label.text.begins_with("Choose who drinks"), "still asking whom")
	ck(inventory.get_item_count("potion") == start_count - 1, "nothing spent on cancel")
	print("[3d] Card follows HP changes that are not potions (B45)")
	player.heal_damage(-20)
	await process_frame
	var card_now: String = panel._visible_cards()[0].get_node("Row/Info/Bars/Hp/Head/Value").text
	ck(card_now == "%d/100" % player.current_health, "card follows a hit with no inventory change (%s vs %d)" % [card_now, player.current_health])

	print("[3c] After a cancel, drinking again still updates the card (B45)")
	player.current_health = 30
	await _press(&"ui_accept")
	modal = ui.get_modal_layer().active_modal
	if modal:
		modal.chosen.emit("confirm")
	for i in 8: await process_frame
	ck(player.current_health == 80, "HP 30 → 80 (%d)" % player.current_health)
	var card_hp: String = panel._visible_cards()[0].get_node("Row/Info/Bars/Hp/Head/Value").text
	ck(card_hp == "80/100", "party card shows 80/100 (%s)" % card_hp)
	start_count -= 1
	row = _potion_row(inv)
	row.grab_focus()
	await process_frame
	await _press(&"ui_accept")
	await _press(&"ui_cancel")
	ck(not panel.is_selecting(), "Esc on the cards returns to the item list")
	back = root.gui_get_focus_owner()
	ck(back != null and inv.is_ancestor_of(back), "focus back on the items")

	print("[4] Esc while choosing cancels, nothing spent, menu stays")
	row = _potion_row(inv)
	row.grab_focus()
	await process_frame
	await _press(&"ui_accept")
	ck(panel.is_selecting(), "choosing again")
	await _press(&"ui_cancel")
	ck(not panel.is_selecting(), "Esc cancelled the choice")
	ck(get_first_node_in_group("game_menu") != null, "Game Menu still open")
	ck(inventory.get_item_count("potion") == start_count - 1, "nothing spent on cancel")

	print("[5] Full HP: nothing to heal")
	player.current_health = player.Max_Health
	panel.refresh()
	await process_frame
	row = _potion_row(inv)
	row.grab_focus()
	await process_frame
	await _press(&"ui_accept")
	ck(not panel.is_selecting(), "no card to choose at full HP")
	ck(bar._hint_label.text == "Nobody needs healing right now.", "bottom bar explains (%s)" % bar._hint_label.text)
	ck(inventory.get_item_count("potion") == start_count - 1, "potion kept")
	print("[6] An empty potion stack leaves the list")
	inventory.remove_item("potion", inventory.get_item_count("potion"))
	await process_frame
	ck(_potion_row(inv) == null, "no potion row at zero")

	ui.close_game_menu()
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
