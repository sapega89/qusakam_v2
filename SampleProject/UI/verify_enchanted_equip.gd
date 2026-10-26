extends SceneTree

## B142: зачарована зброя («iron_sword+1») валила гру, щойно її вдягали. WeaponView вантажив
## Assets/Weapons/iron_sword+1.png — такого файла нема, текстура null, і .get_width() падав.
## Тут кожен зачаровуваний предмет на +1..+ENCHANT_MAX_LEVEL вдягається, зброя дістається й б'є,
## а сейв → завантаження повертає вдягнене зачарування.
## Пише лише в user://verify_enchanted_equip/ (set_save_dir) — справжні сейви не чіпає.
##   godot --headless --path . --script res://SampleProject/UI/verify_enchanted_equip.gd

const TEST_DIR := "user://verify_enchanted_equip/"
const TEST_SLOT := 1
const SLOT_RULES := preload("res://SampleProject/Scripts/Systems/InventorySlotRules.gd")

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _boot() -> Node:
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	return game

func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.hints = false  # D728: no «?» tips in this run
	save_system.set_save_dir(TEST_DIR)
	ck(save_system.get_slot_path(TEST_SLOT).begins_with(TEST_DIR), "tests write only to %s" % TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	set_meta("start_new_game", true)
	var game: Node = await _boot()
	var db: Node = sl.get_item_database()
	var em: Node = sl.get_equipment_manager()
	var gm: Node = sl.get_game_manager()
	var hero: String = gm.get_active_character().character_id
	var weapon_view: Node = game.player.get_node(^"WeaponMount")

	print("[1] Every enchantable item equips at +1..+%d; a weapon is drawn and swings" % db.ENCHANT_MAX_LEVEL)
	var enchantable: Array = db.get_all_items().filter(func(id: String) -> bool: return db.is_enchantable(id))
	ck(enchantable.size() >= 10, "enchantable items found (%d)" % enchantable.size())
	for base in enchantable:
		var slot: String = SLOT_RULES.default_slot(db.get_item(base))
		var bad_levels: Array[int] = []
		for level in range(1, db.ENCHANT_MAX_LEVEL + 1):
			var id: String = db.enchanted_id(base, level)
			var data: Dictionary = db.get_item(id)
			em.equip_item(hero, slot, id, data)
			await process_frame
			var ok: bool = gm.player_state.equipment[slot].id == id
			if db.get_item(base).type == "weapon":
				ok = ok and em.get_weapon_in_hand() == slot and em.get_weapon_item_in_hand().id == id
				ok = ok and (weapon_view.sprite.texture != null or weapon_view._category in weapon_view.DRAWN_ONLY)
			if not ok:
				bad_levels.append(level)
		if db.get_item(base).type == "weapon":
			game.player.combat.perform_attack(1)
			await create_timer(0.9).timeout
		ck(bad_levels.is_empty(), "%s +1..+%d equips (and draws) in slot %s (bad levels %s)" % [base, db.ENCHANT_MAX_LEVEL, slot, bad_levels])
		em.unequip_item(hero, slot)
		await process_frame

	print("[2] An enchanted weapon and armour survive save → load")
	em.equip_item(hero, "sword", "iron_sword+1", db.get_item("iron_sword+1"))
	em.equip_item(hero, "body", "iron_armor+3", db.get_item("iron_armor+3"))
	await process_frame
	ck(game.save_game(), "save_game() wrote slot %d" % TEST_SLOT)
	game.queue_free()
	for i in 4: await process_frame
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	set_meta("start_new_game", false)
	game = await _boot()
	var equipment: Dictionary = gm.player_state.equipment
	ck(equipment.sword != null and equipment.sword.id == "iron_sword+1", "the Iron Sword +1 is still equipped (%s)" % [equipment.sword])
	ck(equipment.body != null and equipment.body.id == "iron_armor+3", "the Iron Armor +3 is still equipped (%s)" % [equipment.body])
	ck(em.get_weapon_item_in_hand().get("id", "") == "iron_sword+1", "the Iron Sword +1 is in hand (%s)" % em.get_weapon_in_hand())
	game.player.combat.perform_attack(1)
	await create_timer(0.9).timeout
	ck(game.player.get_node(^"WeaponMount").sprite.texture != null, "the loaded sword has its sprite")

	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
