extends SceneTree

## Equipment slot picker (BACKLOG 11, D288) with real input:
##   godot --headless --path . --script res://SampleProject/UI/verify_equip_picker.gd
##   1. A mouse click on the SWORDS slot opens a window listing only the swords in the bag.
##   2. A click on a row equips it; the window closes, focus back on the slot.
##   3. Pad A on the slot reopens it: the worn sword is marked "Equipped", Unequip is offered; D-pad + A picks another.
##   4. Enter on the slot, B closes without changes; Unequip empties the slot.
##   5. A slot with nothing fitting says so; Esc closes.

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _picker() -> Node:
	return root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal


func _rows() -> Array:
	var p: Node = _picker()
	return p._list.get_children() if p else []


func _worn(character: Object, slot: String) -> String:
	var item: Variant = character.equipment.get(slot)
	return String(item.id) if item is Dictionary else ""


func _initialize() -> void:
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var inventory: Node = sl.get_inventory_manager()
	for id in ["iron_sword", "copper_sword", "iron_dagger", "herb"]:
		inventory.add_item(id, 1)
	var character: Object = sl.get_game_manager().get_active_character()
	for slot in ["sword", "head"]:
		if _worn(character, slot) != "":
			sl.get_equipment_manager().unequip_item(String(character.character_id), slot)
	game.set_quest_flag("village_oldman_gift", true)
	sl.get_ui_manager().open_game_menu()
	await Kit.frames(self, 16)
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Equipment")
	await Kit.frames(self, 6)
	var eq: Node = menu.find_child("EquipmentComponent", true, false)
	var sword_slot: Button = eq._slot_rows["sword"]

	print("[1] Click on a slot opens the picker with the fitting items only")
	await Kit.mouse(self, sword_slot)
	ck(_picker() != null and _picker().has_method("show_slot"), "picker window open")
	var names: Array = _rows().map(func(r: Node) -> String: return r._name_label.text)
	names.sort()
	ck(names == ["Copper Sword", "Iron Sword"], "only the swords (%s)" % [names])
	ck(not _picker()._unequip.visible, "empty slot: no Unequip")
	var focus: Control = root.gui_get_focus_owner()
	ck(focus != null and focus in _rows(), "focus on the first row")

	print("[2] A click on a row equips it")
	var iron: Control = _rows().filter(func(r: Node) -> bool: return r._name_label.text == "Iron Sword")[0]
	await Kit.mouse(self, iron)
	ck(_picker() == null, "window closed")
	ck(_worn(character, "sword") == "iron_sword", "sword slot: iron_sword (%s)" % _worn(character, "sword"))
	ck(sword_slot.get_node("Row/ItemName").text == "Iron Sword", "slot row shows it")
	await Kit.frames(self, 2)
	ck(root.gui_get_focus_owner() == sword_slot, "focus back on the slot")

	print("[3] Pad A reopens; worn item marked; D-pad + A picks another")
	await Kit.pad(self, JOY_BUTTON_A)
	ck(_picker() != null, "pad A opens the picker")
	var marked: Array = _rows().filter(func(r: Node) -> bool: return r._sub_label.visible and r._sub_label.text == "Equipped")
	ck(marked.size() == 1 and marked[0]._name_label.text == "Iron Sword", "the worn sword is marked Equipped")
	ck(_picker()._unequip.visible, "Unequip offered")
	var copper_index: int = _rows().find(_rows().filter(func(r: Node) -> bool: return r._name_label.text == "Copper Sword")[0])
	for i in copper_index:
		await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	await Kit.pad(self, JOY_BUTTON_A)
	ck(_picker() == null and _worn(character, "sword") == "copper_sword", "D-pad + A: copper_sword (%s)" % _worn(character, "sword"))

	print("[4] Enter opens, B cancels; Unequip empties the slot")
	sword_slot.grab_focus()
	await process_frame
	await Kit.key(self, KEY_ENTER)
	ck(_picker() != null, "Enter opens the picker")
	await Kit.pad(self, JOY_BUTTON_B)
	ck(_picker() == null and _worn(character, "sword") == "copper_sword", "B closes, nothing changed")
	ck(get_first_node_in_group("game_menu") != null, "Game Menu still open")
	await Kit.frames(self, 2)
	await Kit.key(self, KEY_ENTER)
	await Kit.mouse(self, _picker()._unequip)
	ck(_picker() == null and _worn(character, "sword") == "", "Unequip empties the slot")

	print("[5] Nothing fits: the window says so")
	await Kit.mouse(self, eq._slot_rows["head"])
	ck(_picker() != null and _picker()._empty.visible and _rows().is_empty(), "empty message for HEAD")
	ck(root.gui_get_focus_owner() == _picker()._cancel, "focus on Cancel")
	await Kit.key(self, KEY_ESCAPE)
	ck(_picker() == null and get_first_node_in_group("game_menu") != null, "Esc closes only the picker")

	sl.get_ui_manager().close_game_menu()
	await Kit.frames(self, 4)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
