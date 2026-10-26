extends SceneTree

## Гілки з секретами (D583, D620, D621) справжнім вводом:
##   godot --headless --path . --script res://SampleProject/UI/verify_branches.gd
##   1. Дах крамниці на DesertRoad: ↑ драбиною на дах, E — трави (Herb × 2) у торбі.
##   2. Брила на даху: легкий удар (PlayerCombat) її лише хитає, важкий розбиває; за нею злиток (Iron Ingot), E — у торбі.
##      Кімната знову — брили й підібраного немає.
##   3. Вежа: ↑ драбиною на верх вежі, до ґрат схованки (саму схованку — verify_gates).
##   4. Горище діда (ElderHouse): після розмови — драбина за килимом, на горищі E на записах — модалка з текстом
##      «Дідові записи» і запис у журналі (player_state.journal.stories); E — мале зілля (Lesser Potion).
##   5. Сейв → завантаження: запис у журналі лишається, зілля не повертається.
## Пише лише в user://verify_branches/.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")
const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const ELDER := "res://SampleProject/Maps/ElderHouse.tscn"
const TEST_DIR := "user://verify_branches/"
const TEST_SLOT := 1

var fails: Array[String] = []
var sl: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _boot() -> Node:
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	return game


func _stand(game: Node, at: Vector2) -> void:
	game.place_player(at)
	game.player.velocity = Vector2.ZERO
	for i in 20: await physics_frame


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await create_timer(seconds).timeout
	Input.action_release(action)


func _close_modal() -> void:
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	for i in 30:
		if layer.active_modal:
			layer.active_modal.get_viewport().gui_get_focus_owner().pressed.emit()
			await Kit.frames(self, 4)
			return
		await process_frame


func _initialize() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	sl = root.get_node("ServiceLocator")
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.hints = false  # D728: no «?» tips in this run
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var inventory: Node = sl.get_inventory_manager()
	var layer: Node = sl.get_ui_manager().get_modal_layer()

	set_meta("start_new_game", true)
	var game: Node = await _boot()
	await Kit.drain(self)
	game.set_quest_flag("desert_road_fight_complete", true)
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	var player: CharacterBody2D = game.player

	print("[1] Up the ladder onto the shop roof: the herbs")
	var ladder: Node2D = game.map.get_node("Ladder_Shop")
	await _stand(game, Vector2(ladder.global_position.x, 360.0))
	await _hold(&"move_up", 2.5)
	for i in 20: await physics_frame
	ck(player.is_on_floor() and player.global_position.y < 153.0, "the hero stands on the roof (%.0f, %.0f)" % [player.global_position.x, player.global_position.y])
	await _hold(&"move_left", 0.35)
	for i in 20: await physics_frame
	var herbs: Node = game.map.get_node("Pickup_ShopRoof")
	ck(herbs.get_node("Interactable").player_nearby, "the herbs offer \"Pick up\" (x %.0f)" % player.global_position.x)
	var before_herb: int = inventory.get_item_count("herb")
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 6)
	ck(inventory.get_item_count("herb") == before_herb + 2, "Herb × 2 in the bag (%d → %d)" % [before_herb, inventory.get_item_count("herb")])
	await _close_modal()

	print("[2] The boulder on the roof: a heavy blow breaks it, the ingot behind it")
	var rubble: Node = game.map.get_node("Rubble_ShopRoof")
	var ingot: Node = game.map.get_node("Pickup_ShopRoofRubble")
	await _hold(&"move_left", 0.6)
	for i in 10: await physics_frame
	ck(player.global_position.x > 1330.0 and not ingot.get_node("Interactable").player_nearby,
			"the boulder stops the hero, the ingot is out of reach (x %.0f)" % player.global_position.x)
	player.combat.perform_attack(-1)  # як verify_combat_player: удар прямо в PlayerCombat, далі — справжня фізика
	await create_timer(0.8).timeout
	ck(not rubble.is_broken, "a light blow only shakes it")
	player.combat.heavy_attack(-1)
	await create_timer(1.5).timeout
	ck(rubble.is_broken and rubble.get_node("CollisionShape2D").disabled, "a heavy blow breaks it")
	await _hold(&"move_left", 0.5)
	for i in 10: await physics_frame
	ck(ingot.get_node("Interactable").player_nearby, "the ingot is in reach now (x %.0f)" % player.global_position.x)
	var before_ingot: int = inventory.get_item_count("iron_ingot")
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 6)
	ck(inventory.get_item_count("iron_ingot") == before_ingot + 1, "Iron Ingot in the bag (%d → %d)" % [before_ingot, inventory.get_item_count("iron_ingot")])
	await _close_modal()
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	ck(game.map.get_node_or_null("Rubble_ShopRoof") == null and game.map.get_node_or_null("Pickup_ShopRoofRubble") == null
			and game.map.get_node_or_null("Pickup_ShopRoof") == null, "a room reload: the boulder and both pickups are gone")

	print("[3] Up the ladder onto the watchtower")
	ladder = game.map.get_node("Ladder_Tower")
	await _stand(game, Vector2(ladder.global_position.x, 360.0))
	await _hold(&"move_up", 2.5)
	for i in 20: await physics_frame
	ck(player.is_on_floor() and player.global_position.y < 158.0, "the hero stands on the tower top (%.0f, %.0f)" % [player.global_position.x, player.global_position.y])
	ck(game.map.get_node("Cage_TowerStash/Area/Interactable").player_nearby, "beside the barred stash")

	print("[4] Grandfather's attic: his notes and a small potion")
	game.set_quest_flag("village_oldman_complete", true)
	await game.teleport_to_room(ELDER, ^"Arrival")
	for i in 20: await physics_frame
	ladder = game.map.get_node("Attic/Ladder_Attic")
	await _stand(game, Vector2(ladder.global_position.x, 840.0))
	await _hold(&"move_up", 3.5)
	for i in 20: await physics_frame
	ck(player.is_on_floor() and player.global_position.y < 448.0, "up the ladder behind the rug, into the attic (y %.0f)" % player.global_position.y)
	await _hold(&"move_right", 0.9)
	for i in 20: await physics_frame
	var notes: Node = game.map.get_node("Attic/GrandfatherNotes")
	ck(notes.get_node("Interactable").player_nearby and notes.get_node("Interactable").get_prompt().action_text == "Read",
			"the notes offer \"Read\" (x %.0f)" % player.global_position.x)
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 6)
	var text := Kit.modal_text(self)
	ck(text.contains("Grandfather's notes") and text.contains("The barrier is growing quiet"), "the modal shows the notes (%s…)" % text.left(60))
	ck(JournalRecords.stories().map(func(s: Dictionary) -> String: return s.id) == ["grandfather_notes"], "the journal keeps them")
	await _close_modal()
	await _hold(&"move_left", 2.0)
	for i in 20: await physics_frame
	var potion: Node = game.map.get_node("Attic/Pickup_AtticPotion")
	ck(potion.get_node("Interactable").player_nearby, "the potion offers \"Pick up\" (x %.0f)" % player.global_position.x)
	var before_potion: int = inventory.get_item_count("potion_lesser")
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 6)
	ck(inventory.get_item_count("potion_lesser") == before_potion + 1, "Lesser Potion in the bag")
	await _close_modal()

	print("[5] Save → load")
	ck(game.save_game(), "saved to slot %d" % TEST_SLOT)
	game.queue_free()
	for i in 4: await process_frame
	set_meta("start_new_game", false)
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	game = await _boot()
	ck(game.map.get_node_or_null("Attic/Pickup_AtticPotion") == null, "the potion does not come back")
	ck(JournalRecords.stories().size() == 1, "the notes are still in the journal")
	ck(layer.active_modal == null, "no modal left open")
	_finish()


func _finish() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
