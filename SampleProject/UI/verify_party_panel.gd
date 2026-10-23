extends SceneTree

## The Game Menu shows only who is in the party (BACKLOG 10, D287), real input:
##   godot --headless --path . --script res://SampleProject/UI/verify_party_panel.gd
##   1. Pad Start opens the menu at the start of the game: one card, Kusakam, with real HP / SP.
##   2. A companion joins (Status card clicked with the mouse): back on Inventory there are two cards,
##      the companion with her portrait and no invented HP.
##   3. Sent to camp again (Enter on her Status card): one card.

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _cards() -> Array:
	return get_first_node_in_group("ui_party_panel")._cards.get_children().filter(func(c: Control) -> bool: return c.visible)


func _names() -> Array:
	return _cards().map(func(c: Control) -> String: return c.get_node(^"Row/Info/Head/Name").text)


func _initialize() -> void:
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var cm: Node = sl.get_companion_manager()
	game.set_quest_flag("village_oldman_gift", true)
	game.set_quest_flag("village_oldman_healed", true)

	print("[1] Party of one")
	await Kit.pad(self, JOY_BUTTON_START)
	await Kit.frames(self, 14)
	var menu: Node = get_first_node_in_group("game_menu")
	ck(menu != null, "pad Start opens the Game Menu")
	menu.switch_to_tab("Inventory")
	await Kit.frames(self, 4)
	ck(_names() == ["Kusakam"], "only Kusakam (%s)" % [_names()])
	var hp: String = _cards()[0].get_node(^"Row/Info/Bars/Hp/Head/Value").text
	ck(hp == "100/100", "his real HP (%s)" % hp)

	print("[2] A companion joins the party")
	game.set_quest_flag(cm.UNLOCK_FLAGS["alisia"], true)
	menu.switch_to_tab("Status")
	await Kit.frames(self, 8)
	var card: Control = menu.find_child("CompanionCards", true, false).get_children().filter(func(c: Control) -> bool: return c.visible)[0]
	await Kit.mouse(self, card.get_node(^"Select"))
	ck(cm.get_party() == ["alisia"], "Status click put her in the party (%s)" % [cm.get_party()])
	menu.switch_to_tab("Inventory")
	await Kit.frames(self, 6)
	ck(_names() == ["Kusakam", "Alisia"], "Kusakam and Alisia (%s)" % [_names()])
	var art: TextureRect = _cards()[1].get_node(^"Row/PortraitFrame/Art")
	ck(art.visible and art.texture != null, "her portrait")
	ck(_cards()[1].get_node(^"Row/Info/Bars/Hp/Head/Value").text == "—/—", "no invented HP for an assist")
	ck(_cards()[0].get_node(^"Row/PortraitFrame/Art").texture == load("res://SampleProject/Sprites/Player/portrait.tres"), "hero card shows Kusakam's dialogue portrait (B129)")

	print("[3] Back to camp")
	menu.switch_to_tab("Status")
	await Kit.frames(self, 8)
	card.get_node(^"Select").grab_focus()
	await process_frame
	await Kit.key(self, KEY_ENTER)
	ck(cm.get_party().is_empty(), "Enter sent her to camp")
	menu.switch_to_tab("Inventory")
	await Kit.frames(self, 6)
	ck(_names() == ["Kusakam"], "one card again (%s)" % [_names()])

	sl.get_ui_manager().close_game_menu()
	await Kit.frames(self, 4)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
