extends SceneTree

## Inventory actions (BACKLOG 9, D286) with real input — keys, mouse, gamepad:
##   godot --headless --path . --script res://SampleProject/UI/verify_use_item.gd
##   1. Enter on a potion does not drink it (D504: potions are drunk in play, from the quick slot); the bar says so.
##   2. A double click and pad A do not drink it either.
##   3. An ether restores SP.
##   4. A material opens the "Cannot Use" modal; pad B closes it, focus back on the row, nothing spent.
##   5. A weapon, armour and a helmet equip into their slots from the inventory.
##   6. An empty potion stack leaves the list.
##   7. The potion line ascends Lesser < Potion < Medium < Large in heal, price and description (B108, D357).

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _row(inv: Node, id: String) -> Control:
	for i in inv.items.size():
		if inv.items[i].get("id", "") == id:
			return inv._item_list.get_child(i)
	return null


func _focus_row(inv: Node, id: String) -> Control:
	var row: Control = _row(inv, id)
	row.grab_focus()
	await process_frame
	return row


func _initialize() -> void:
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var player: Node = sl.get_game_manager().get_current_player()
	var inventory: Node = sl.get_inventory_manager()
	var sm: Node = sl.get_skill_manager()
	for id in ["potion", "ether", "herb", "iron_sword", "iron_armor", "iron_helmet"]:
		inventory.add_item(id, 3 if id == "potion" else 1)
	player.current_health = 20
	var potions: int = inventory.get_item_count("potion")

	game.set_quest_flag("village_oldman_gift", true)  # Inventory відкрита сюжетом (D151)
	ui.open_game_menu()
	await Kit.frames(self, 16)
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Inventory")
	await Kit.frames(self, 6)
	var inv: Node = menu.find_child("InventoryComponent", true, false)
	var bar: Node = get_first_node_in_group("ui_bottom_bar")

	print("[1] Enter on a potion does not drink it in the paused menu (D504)")
	await _focus_row(inv, "potion")
	await Kit.key(self, KEY_ENTER)
	ck(ui.get_modal_layer().active_modal == null, "no modal")
	ck(player.current_health == 20, "HP stays 20 (%d)" % player.current_health)
	ck(inventory.get_item_count("potion") == potions, "no potion spent")
	var focus: Control = root.gui_get_focus_owner()
	ck(focus == _row(inv, "potion"), "focus stays on the potion row (%s)" % (focus.get_path() if focus else "none"))
	ck(inv._item_list.get_children().filter(func(r: Button) -> bool: return r.button_pressed).size() == 1, "one row selected")
	ck(bar._hint_label.text.begins_with("Drink it in play with the quick slot"), "bottom bar points to the quick slot (%s)" % bar._hint_label.text)

	print("[2] Double click and pad A do not drink it either")
	await Kit.mouse(self, _row(inv, "potion"), true)
	await _focus_row(inv, "potion")
	await Kit.pad(self, JOY_BUTTON_A)
	ck(player.current_health == 20 and inventory.get_item_count("potion") == potions, "HP %d, potions %d" % [player.current_health, inventory.get_item_count("potion")])

	print("[3] Ether restores SP")
	sm.spend_sp(sm.get_current_sp())
	await _focus_row(inv, "ether")
	await Kit.key(self, KEY_ENTER)
	ck(sm.get_current_sp() > 0 and inventory.get_item_count("ether") == 0, "SP restored, ether spent (%d)" % sm.get_current_sp())

	print("[4] A material cannot be used")
	var herb_row: Control = await _focus_row(inv, "herb")
	await Kit.key(self, KEY_ENTER)
	var text: String = Kit.modal_text(self)
	ck(text.contains("Cannot Use") and text.contains("cannot be used"), "modal says so (%s)" % text)
	await Kit.pad(self, JOY_BUTTON_B)
	ck(ui.get_modal_layer().active_modal == null, "pad B closes it")
	ck(get_first_node_in_group("game_menu") != null, "Game Menu still open")
	ck(inventory.get_item_count("herb") == 1, "nothing spent")
	await Kit.frames(self, 2)
	focus = root.gui_get_focus_owner()
	ck(focus != null and inv.is_ancestor_of(focus), "focus back on the list (%s)" % (focus.get_path() if focus else "none"))
	await Kit.mouse(self, herb_row, true)
	ck(Kit.modal_text(self).contains("Cannot Use"), "double click opens it too")
	var ok_button: Button = ui.get_modal_layer().active_modal.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.visible)[0]
	await Kit.mouse(self, ok_button)
	ck(ui.get_modal_layer().active_modal == null, "OK click closes it")
	await Kit.mouse(self, herb_row, true)
	await Kit.key(self, KEY_ENTER)
	ck(ui.get_modal_layer().active_modal == null, "Enter on OK closes it (focus %s)" % root.gui_get_focus_owner())

	print("[5] Weapons and armour equip from the inventory")
	var character: Object = sl.get_game_manager().get_active_character()
	await _focus_row(inv, "iron_sword")
	await Kit.key(self, KEY_ENTER)
	ck(character.equipment.get("sword") is Dictionary and character.equipment["sword"].id == "iron_sword", "sword slot: iron_sword")
	await Kit.mouse(self, _row(inv, "iron_armor"), true)
	ck(character.equipment.get("body") is Dictionary and character.equipment["body"].id == "iron_armor", "body slot: iron_armor")
	await _focus_row(inv, "iron_helmet")
	await Kit.pad(self, JOY_BUTTON_A)
	ck(character.equipment.get("head") is Dictionary and character.equipment["head"].id == "iron_helmet", "head slot: iron_helmet")
	ck(bar._hint_label.text.contains("equipped"), "bottom bar confirms (%s)" % bar._hint_label.text)

	print("[6] An empty stack leaves the list")
	inventory.remove_item("potion", inventory.get_item_count("potion"))
	await process_frame
	ck(_row(inv, "potion") == null, "no potion row at zero")

	print("[7] The potion line ascends (B108, D357)")
	var db: Node = sl.get_item_database()
	var line: Array = ["potion_lesser", "potion", "potion_medium", "hi_potion"].map(func(id: String) -> Dictionary: return db.get_item(id))
	for i in range(1, line.size()):
		var lo: Dictionary = line[i - 1]
		var hi: Dictionary = line[i]
		ck(lo.effect.value < hi.effect.value and lo.buy_price < hi.buy_price and lo.sell_price < hi.sell_price,
				"%s < %s: heal %d < %d, buy %d < %d, sell %d < %d" % [lo.id, hi.id, lo.effect.value, hi.effect.value,
				lo.buy_price, hi.buy_price, lo.sell_price, hi.sell_price])
	for item: Dictionary in line:
		ck(item.description == "Restores %d HP." % item.effect.value, "%s says what it heals (%s)" % [item.id, item.description])
	ck(db.get_item("ether").description == "Restores %d SP." % db.get_item("ether").effect.value, "Ether names SP (B107)")

	ui.close_game_menu()
	await Kit.frames(self, 4)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
