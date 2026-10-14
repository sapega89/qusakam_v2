extends SceneTree

## Зачарування, slice 1 (design/enchanting_plan.md): D94 два однакові → +1, D163 кап +20,
## D164 ціна росте з рівнем. Рівень живе в id ("iron_dagger+2").
##   godot --headless --path . --script res://SampleProject/UI/verify_enchanting.gd

var fails: Array[String] = []
var inv: Node
var db: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _set_count(id: String, n: int) -> void:
	var have: int = inv.get_item_count(id)
	if have > n:
		inv.remove_item(id, have - n)
	elif have < n:
		inv.add_item(id, n - have)


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return


func _modal() -> Control:
	return root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal


func _press_modal(result: String) -> void:
	var modal := _modal()
	if result == "confirm":
		modal.confirmed.emit()
	else:
		modal.cancelled.emit()
	for i in 4: await process_frame


func _initialize() -> void:
	await process_frame
	await process_frame
	# Модалки екрана живуть у UIManager запущеної гри — як у verify_crafting.
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	inv = sl.get_inventory_manager()
	db = sl.get_item_database()
	var service = load("res://SampleProject/Scripts/Crafting/enchanting_service.gd").new()
	var R = service.Result

	print("[1] +N ids resolve from the base item")
	var base: Dictionary = db.get_item("iron_dagger")
	var plus2: Dictionary = db.get_item("iron_dagger+2")
	ck(plus2.name == "Iron Dagger +2" and plus2.id == "iron_dagger+2", "name and id carry the level")
	ck(plus2.stats.attack == base.stats.attack + 2, "weapon: attack +1 per level (D94)")
	ck(db.get_item("iron_helmet+3").stats.defense == db.get_item("iron_helmet").stats.defense + 3,
			"armour: defense +1 per level (D94)")
	ck(db.get_item("iron_dagger").stats.attack == base.stats.attack, "base item untouched")
	ck(db.get_item("iron_dagger+21").is_empty() and db.get_item("iron_dagger+0").is_empty()
			and db.get_item("iron_dagger+02").is_empty() and db.get_item("iron_dagger+x").is_empty(),
			"no level above +20 (D163), no malformed ids")
	ck(db.get_item("potion+1").is_empty() and not db.is_enchantable("iron_ore"), "only weapons and armour")

	print("[2] Two identical → one a level up, gold grows with the level (D164)")
	_set_count("coin", 1000)
	_set_count("iron_dagger", 2)
	_set_count("iron_dagger+1", 0)
	ck(service.cost("iron_dagger+1") == 2 * service.cost("iron_dagger"), "+2 costs twice what +1 costs")
	var price: int = service.cost("iron_dagger")
	ck(service.enchant("iron_dagger") == R.OK, "enchant two daggers")
	ck(inv.get_item_count("iron_dagger") == 0 and inv.get_item_count("iron_dagger+1") == 1, "2 × iron_dagger → 1 × +1")
	ck(inv.get_item_count("coin") == 1000 - price, "charged %d gold" % price)
	ck(service.enchant("iron_dagger+1") == R.NOT_ENOUGH_ITEMS, "one +1 is not enough")
	_set_count("iron_dagger", 1)
	ck(service.check("iron_dagger+1") == R.NOT_ENOUGH_ITEMS, "+1 does not pair with a plain dagger")
	_set_count("iron_dagger+1", 2)
	_set_count("coin", 0)
	ck(service.enchant("iron_dagger+1") == R.NOT_ENOUGH_GOLD and inv.get_item_count("iron_dagger+1") == 2,
			"no gold → nothing taken")
	_set_count("coin", 100000)
	_set_count("iron_dagger+20", 2)
	ck(service.check("iron_dagger+20") == R.MAX_LEVEL, "+20 is the cap")
	ck(service.check("potion") == R.NOT_ENCHANTABLE, "potions cannot be enchanted")
	_set_count("iron_dagger", 1)
	ck(service.candidates().has("iron_dagger+1") and not service.candidates().has("iron_dagger+20")
			and not service.candidates().has("iron_dagger"), "candidates: a pair, enchantable, below the cap")

	print("[3] An equipped +N applies its stat")
	var hero := GameCharacter.new()
	hero.equipment = {"weapon": {"id": "iron_dagger+3"}}
	ck(hero.get_equipment_stats().attack == base.stats.attack + 3, "equipment stats read the +3")

	print("[4] Enchant screen at the Blacksmith (slice 2)")
	var smith: Blacksmith = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/blacksmith.tscn").instantiate()
	game.add_child(smith)
	await process_frame
	ck(smith.menu_entries().map(func(e): return e.label).has("Enchant"), "Blacksmith offers Enchant (D115)")
	for id in ["iron_dagger+1", "iron_dagger+20"]:
		_set_count(id, 0)
	_set_count("iron_dagger", 2)
	_set_count("iron_helmet", 1)
	_set_count("coin", 100)
	smith.npc_menu.chosen.emit(&"enchant")
	for i in 6: await process_frame
	var menu: Control = smith.screen_instance
	ck(smith.is_screen_open and menu != null and paused, "Enchant opens the screen under pause")
	var rows: Array = menu.get_rows()
	var ids: Array = rows.map(func(r): return r.data.id)
	ck(ids == ["iron_dagger"], "lists only what can be enchanted now — one helmet is not listed: %s" % str(ids))
	var dagger_row = rows.filter(func(r): return r.data.id == "iron_dagger")[0]
	ck(dagger_row.get_node("%DetailLabel").text.contains("Iron Dagger +1"), "row shows the result")
	dagger_row.row_activated.emit(dagger_row.data)
	for i in 4: await process_frame
	ck(_modal() != null and _modal().title_label.text == "Enchant Iron Dagger?", "\"Enchant Iron Dagger?\"")
	await _press_modal("confirm")
	ck(inv.get_item_count("iron_dagger+1") == 1 and inv.get_item_count("iron_dagger") == 0, "enchanted through the UI")
	ck(menu.get_rows().is_empty() and menu._empty.visible, "after it the list is empty and says so")
	var esc_key := InputEventKey.new()
	esc_key.keycode = KEY_ESCAPE
	esc_key.physical_keycode = KEY_ESCAPE
	esc_key.pressed = true
	root.push_input(esc_key)  # справжній шлях клавіші: каркас BaseMenu отримує її першим
	for i in 4: await process_frame
	ck(not smith.is_screen_open and not paused, "a real Esc key closes the screen, game resumes")

	for id in ["iron_dagger", "iron_dagger+1", "iron_dagger+20", "iron_helmet", "coin"]:
		_set_count(id, 0)
	_done()


func _done() -> void:
	print("")
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
		for f in fails:
			print("    : " + f)
	quit(0 if fails.is_empty() else 1)
