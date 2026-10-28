extends SceneTree

## Брами всередині локації (D562, D619) у справжній грі:
##   godot --headless --path . --script res://SampleProject/UI/verify_gates.gd
##   1. Дані: кожна брама gates.json відчиняється рівно одним — ключем (key_item з items.json) або прапорцем; її репліка
##      є українською й англійською; кожен LockedDoor у кімнатах називає відому браму, і кожну браму десь поставлено.
##   2. Ключ (схованка на вежі DesertRoad): без ключа ґрати тримають героя, скриня за ними недосяжна, E — репліка
##      Gate_TowerStash_Locked. Бій каравану, добитий уперше, дає Bandit Key (один раз: повернення ворогів його не
##      повторює). З ключем E відмикає ґрати, ключ іде з інвентаря; кімната знову — ґрати відчинені.
##   3. Прапорець (ляда горища в ElderHouse): до розмови з дідом герой лізе драбиною й упирається в ляду, E — репліка
##      Gate_ElderAttic_Locked; дід каже про горище в OldMan_Decision, і його прапорець village_oldman_complete
##      відчиняє ляду одразу; герой вилазить на горище.
##   4. Сейв → завантаження: ґрати й ляда відчинені, ключ не повертається.
##   5. D722: скриню старого грифа на дорозі (за караваном) стереже бій без зони: повз неї герой іде спокійно; E будить
##      грифа — він сам, старий гриф рівня 4; поки він живий, скриня не відчиняється; після нього — відчиняється.
##   6. D724: у Лабораторії, на схід від драбини (дорога далі — на захід), зона будить баштового вартового — сам;
##      скриня за ним відчиняється лише після нього. Обидва бої звичайні (D492): повернення ворогів скриню не закриває.
##   7. D723: двері табору бандитів на дорозі — ключова брама camp_door. Сейв, де героя в таборі не було, — двері
##      зачинені; старий сейв, зроблений у таборі (до D723), — двері відчинені без ключа.
## Пише лише в user://verify_gates/.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const ELDER := "res://SampleProject/Maps/ElderHouse.tscn"
const LAB_MIDDLE := "res://SampleProject/Maps/LabMiddleFloor.tscn"
const LAB_POCKET := "res://SampleProject/Maps/LabGuardPocket.tscn"
const CAMP := "res://SampleProject/Maps/BanditCamp.tscn"
const GATES := "res://SampleProject/Resources/Data/gates.json"
const ITEMS := "res://SampleProject/Resources/Data/items.json"
const LOCKED_DOOR := "res://SampleProject/Objects/LockedDoor.tscn"
const ROOM_DOOR := "res://SampleProject/Scenes/Gameplay/Objects/room_door.tscn"
const TEST_DIR := "user://verify_gates/"
const TEST_SLOT := 1
## Верх вежі ліворуч від ґрат (Ledge_TowerTop, верх y 158); центр героя — на 24 px вище ніг.
const TOWER_TOP := Vector2(2316.0, 134.0)

var fails: Array[String] = []
var sl: Node
var dm: Node
var started: Array[String] = []

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


func _close_modal() -> void:
	var layer: Node = sl.get_ui_manager().get_modal_layer()
	for i in 30:
		if layer.active_modal:
			layer.active_modal.get_viewport().gui_get_focus_owner().pressed.emit()
			await Kit.frames(self, 4)
			return
		await process_frame


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await create_timer(seconds).timeout
	Input.action_release(action)


func _gate_doors() -> Array:
	var out: Array = []
	for file in DirAccess.get_files_at("res://SampleProject/Maps"):
		if not file.ends_with(".tscn"):
			continue
		var state: SceneState = (load("res://SampleProject/Maps/" + file) as PackedScene).get_state()
		for i in state.get_node_count():
			var inst: PackedScene = state.get_node_instance(i)
			if inst and inst.resource_path in [LOCKED_DOOR, ROOM_DOOR]:  # D643: брама прапорця буває й на RoomDoor
				for p in state.get_node_property_count(i):
					if state.get_node_property_name(i, p) == &"gate_id":
						out.append(state.get_node_property_value(i, p))
	return out


func _initialize() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	sl = root.get_node("ServiceLocator")
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.hints = false  # D746: no «?» tips in this run
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	dm.dialogue_started.connect(func(path: String) -> void: started.append(path.get_file().get_basename()))
	var inventory: Node = sl.get_inventory_manager()

	print("[1] Gate data")
	var gates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATES)).gates
	var items := {}
	for item: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(ITEMS)).items:
		items[item.id] = item
	for id: String in gates:
		var gate: Dictionary = gates[id]
		ck(gate.has("key") != gate.has("flag"), "%s opens with exactly one of key / flag" % id)
		if gate.has("key"):
			ck(items.has(gate.key) and items[gate.key].type == "key_item", "%s: its key %s is a key_item" % [id, gate.key])
		ck(FileAccess.file_exists("res://dialogue_quest/%s.dqd" % gate.locked_dialogue)
				and FileAccess.file_exists("res://dialogue_quest/en/%s.dqd" % gate.locked_dialogue),
				"%s: its locked line %s is in uk and en" % [id, gate.locked_dialogue])
	var placed := _gate_doors()
	ck(placed.all(func(id: String) -> bool: return gates.has(id)), "every LockedDoor / gated RoomDoor in the rooms names a known gate (%s)" % [placed])
	ck(gates.keys().all(func(id: String) -> bool: return placed.has(id)), "every gate stands in a room")

	set_meta("start_new_game", true)
	var game: Node = await _boot()
	await Kit.drain(self)
	game.set_quest_flag("desert_road_fight_complete", true)

	print("[2] The watchtower stash opens with the bandit key")
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	var cage: Node = game.map.get_node("Cage_TowerStash")
	var chest: Node = game.map.get_node("Chest_TowerStash")
	await _stand(game, TOWER_TOP)
	ck(not cage.is_open and not cage.get_node("Body/CollisionShape2D").disabled, "the cage starts closed and solid")
	await _hold(&"move_right", 0.6)
	for i in 10: await physics_frame
	ck(game.player.global_position.x < 2340.0, "the bars stop the hero (x %.0f)" % game.player.global_position.x)
	ck(not chest.get_node("Interactable").player_nearby, "the chest behind the bars is out of reach")
	ck(cage.get_node("Area/Interactable").player_nearby, "the cage offers \"Open\"")
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 10)
	ck(started.has("Gate_TowerStash_Locked") and not cage.is_open, "no key: Kusakam's line, the cage stays shut (%s)" % [started])
	await Kit.drain(self)

	var caravan: Node = game.map.get_node("Fight_Caravan")
	ck(caravan.reward == {"bandit_key": 1}, "the caravan fight carries the bandit key")
	# Тест брам, не бою: у каравані тепер еліта (броньований скорпіон, D652), і за 4 с серед п'ятьох ворогів герой падав
	game.player.Max_Health = 99999
	game.player.current_health = game.player.Max_Health
	game.player.min_health = 1  # D754: бої важчі; Max_Health скидає refresh_max_health, а min_health — ні
	for round in 2:
		game.player.global_position = Vector2(caravan.trigger_area.global_position.x, 200.0)
		await create_timer(4.0).timeout
		for enemy in caravan.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive()):
			enemy.die()
		await create_timer(1.0).timeout
		await _close_modal()
		ck(inventory.get_item_count("bandit_key") == 1, "after win %d: one bandit key (%d)" % [round + 1, inventory.get_item_count("bandit_key")])
		game.reset_ordinary_fights()  # вороги повертаються, як після медитації (D492)
		await game.teleport_to_room(ROAD, ^"Arrival_Start")
		for i in 20: await physics_frame
		caravan = game.map.get_node("Fight_Caravan")

	cage = game.map.get_node("Cage_TowerStash")
	chest = game.map.get_node("Chest_TowerStash")
	await _stand(game, TOWER_TOP)
	await Kit.key(self, KEY_E)
	await create_timer(0.6).timeout
	ck(cage.is_open and cage.get_node("Body/CollisionShape2D").disabled, "with the key, E unlocks the cage")
	ck(inventory.get_item_count("bandit_key") == 0, "the key is used up")
	await _hold(&"move_right", 0.5)
	for i in 10: await physics_frame
	ck(chest.get_node("Interactable").player_nearby, "the hero walks up to the chest (x %.0f)" % game.player.global_position.x)
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	ck(game.map.get_node("Cage_TowerStash").is_open, "a room reload keeps the cage open")

	print("[3] The attic hatch opens on Grandfather's flag")
	ck(FileAccess.get_file_as_string("res://dialogue_quest/OldMan_Decision.dqd").contains("горище")
			and FileAccess.get_file_as_string("res://dialogue_quest/en/OldMan_Decision.dqd").contains("attic"),
			"Grandfather's decision talk tells Kusakam about the attic (uk, en)")
	game.set_quest_flag("village_oldman_complete", false)
	await game.teleport_to_room(ELDER, ^"Arrival")
	for i in 20: await physics_frame
	var hatch: Node = game.map.get_node("Attic/Hatch_Attic")
	ck(not hatch.is_open, "before the talk the hatch is shut")
	await _stand(game, Vector2(hatch.global_position.x, 840.0))
	await _hold(&"move_up", 3.5)
	for i in 10: await physics_frame
	ck(game.player.global_position.y > 480.0, "the hero climbs and bumps the hatch (y %.0f)" % game.player.global_position.y)
	ck(hatch.get_node("Area/Interactable").player_nearby, "the hatch is in reach from the ladder")
	started.clear()
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 10)
	ck(started.has("Gate_ElderAttic_Locked"), "E on the shut hatch: Kusakam's line (%s)" % [started])
	await Kit.drain(self)
	game.set_quest_flag("village_oldman_complete", true)  # те, що ставить кінець OldMan_Decision (ElderHouse.gd)
	await Kit.frames(self, 30)
	ck(hatch.is_open and hatch.get_node("Body/CollisionShape2D").disabled, "the flag opens the hatch at once")
	await _stand(game, Vector2(hatch.global_position.x, 600.0))
	await _hold(&"move_up", 3.0)
	for i in 30: await physics_frame
	ck(game.player.global_position.y < 448.0 and game.player.is_on_floor(), "the hero climbs into the attic (y %.0f)" % game.player.global_position.y)

	print("[4] Save → load keeps both open")
	ck(game.save_game(), "saved to slot %d" % TEST_SLOT)
	game.queue_free()
	for i in 4: await process_frame
	set_meta("start_new_game", false)
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	game = await _boot()
	ck(game.map.scene_file_path == ELDER and game.map.get_node("Attic/Hatch_Attic").is_open, "loaded in ElderHouse, the hatch open")
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	ck(game.map.get_node("Cage_TowerStash").is_open, "the cage still open")
	ck(inventory.get_item_count("bandit_key") == 0, "the key does not come back")

	game.player.Max_Health = 99999
	game.player.current_health = game.player.Max_Health
	print("[5] D722: the old vulture's chest on the road")
	var vulture_fight: Node = game.map.get_node("Fight_OldVulture")
	var vulture_chest: Node = game.map.get_node("Chest_OldVulture")
	ck(vulture_fight.trigger_area == null and vulture_fight.respawns and vulture_fight.enemy_level == 4,
			"an ordinary fight (D492) at level 4, the hero's after the Caravan (D642), with no zone on the road")
	ck(vulture_fight.spawn_points.size() == 1 and vulture_fight.spawn_points[0].kind() == "old_vulture",
			"its one point is the old vulture (%s)" % [vulture_fight.spawn_points.map(func(p: Node) -> String: return p.kind())])
	ck(vulture_chest.position.x > game.map.get_node("Fight_Caravan/Fight_CaravanTrigger").position.x
			and vulture_chest.get_node(vulture_chest.guard) == vulture_fight, "the chest stands after the Caravan, guarded by it")
	await _stand(game, vulture_chest.global_position + Vector2(-260, -40))
	await _hold(&"move_right", 1.2)
	for i in 10: await physics_frame
	ck(game.player.global_position.x > vulture_chest.global_position.x + 40.0 and not vulture_fight.fight_in_progress(),
			"walking by the chest does not wake the vulture (x %.0f)" % game.player.global_position.x)
	await _guarded_chest(game, vulture_chest, vulture_fight, "enemy_old_vulture.tscn", {"potion_lesser": 2, "mana_crystal": 2})

	print("[6] D724: the tower shield guard's chest in the Laboratory — his alcove east of the middle floor (v3, D865)")
	await game.teleport_to_room(LAB_MIDDLE, ^"StairsDoor")
	for i in 20: await physics_frame
	var stairs_door: Node2D = game.map.get_node("StairsDoor")
	ck(game.map.get_node("Fight_Cursed/Trigger").global_position.x < stairs_door.global_position.x,
			"off the way up: from the stairs' door the way on goes west")
	Input.action_press(&"move_right")
	for i in 600:
		await physics_frame
		if game.map.scene_file_path == LAB_POCKET:
			break
	Input.action_release(&"move_right")
	for i in 10: await physics_frame
	ck(game.map.scene_file_path == LAB_POCKET, "east of the stairs' door, through the room's edge: the guard's alcove")
	var guard_fight: Node = game.map.get_node("Fight_TowerGuard")
	var guard_chest: Node = game.map.get_node("Chest_TowerGuard")
	ck(guard_fight.respawns and guard_fight.enemy_level == 9 and guard_fight.spawn_points.size() == 1
			and guard_fight.spawn_points[0].kind() == "tower_shield_guard", "an ordinary level-9 fight, one tower shield guard")
	ck(guard_chest.global_position.x > guard_fight.trigger_area.global_position.x, "the chest lies behind the guard's zone")
	ck(guard_chest.get_node(guard_chest.guard) == guard_fight, "the chest is guarded by that fight")
	ck(not guard_fight.fight_in_progress(), "in the alcove's mouth: no fight yet")
	Input.action_press(&"move_right")
	for i in 300:
		await physics_frame
		if game.player.global_position.x > guard_fight.trigger_area.global_position.x + 40.0:
			break
	Input.action_release(&"move_right")
	for i in 30: await physics_frame
	ck(guard_fight.fight_in_progress() and guard_fight.get_alive_enemies_count() == 1, "stepping east wakes the guard, alone")
	await _guarded_chest(game, guard_chest, guard_fight, "enemy_tower_shield_guard.tscn", {"hi_potion": 1, "silver_ingot": 2})

	print("[7] D723: the camp door, and old saves made in the camp")
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	ck(game.map.get_node("BanditCampDoor").gate_id == "camp_door" and not game.map.get_node("BanditCampDoor").is_open(),
			"a save that never entered the camp: its door is locked")
	await game.teleport_to_room(CAMP, ^"ExitDoor")  # сейв, зроблений у таборі до D723
	for i in 20: await physics_frame
	ck(game.save_game(), "saved in the camp")
	game.queue_free()
	for i in 4: await process_frame
	game = await _boot()
	ck(game.map.scene_file_path == CAMP, "loaded in the camp")
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	ck(game.map.get_node("BanditCampDoor").is_open() and inventory.get_item_count("bandit_camp_key") == 0,
			"the old save keeps the camp door open, without a key")
	ck(game.map.get_node("Chest_OldVulture").is_open, "the vulture's chest stays open")
	await game.teleport_to_room(LAB_POCKET, ^"Chest_TowerGuard")
	for i in 20: await physics_frame
	ck(game.map.get_node("Chest_TowerGuard").is_open, "the guard's chest stays open")
	_finish()


## Скриня під вартою: поки вартовий живий, E її не відчиняє (на дорозі E його й будить); після нього — відчиняє;
## повернення ворогів (D492) її не закриває.
func _guarded_chest(game: Node, chest: Node, fight: Node, scene: String, items: Dictionary) -> void:
	var inventory: Node = sl.get_inventory_manager()
	# Вартовий, якого вже розбудили, карає героя, що щойно «приземлився» біля скрині (D775), і відкидає його від неї —
	# поки перевіряємо підказку, він стоїть.
	for enemy: Node in fight.spawned_enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await _stand(game, chest.global_position + Vector2(-40, -40))
	ck(chest.get_node("Interactable").player_nearby, "%s offers \"Open\"" % chest.name)
	for enemy: Node in fight.spawned_enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
	await Kit.key(self, KEY_E)
	for i in 30: await physics_frame
	var alive: Array = fight.spawned_enemies.filter(func(e: Node) -> bool: return is_instance_valid(e) and e.is_alive())
	ck(alive.size() == 1 and alive[0].scene_file_path.ends_with(scene) and alive[0].level == fight.enemy_level,
			"%s: one enemy, %s, level %d (%s)" % [chest.name, scene, fight.enemy_level, alive.map(func(e: Node) -> String: return e.scene_file_path.get_file())])
	ck(not chest.is_open, "%s stays shut while its guard lives" % chest.name)
	await Kit.key(self, KEY_E)
	for i in 10: await physics_frame
	ck(not chest.is_open and fight.get_alive_enemies_count() == 1, "%s: E again — still shut, no second guard" % chest.name)
	for enemy: Node in alive:
		enemy.die()
	await create_timer(1.5).timeout
	ck(fight.fight_cleared(), "%s: the guard is beaten" % chest.name)
	var before := {}
	for id: String in items: before[id] = inventory.get_item_count(id)
	await _stand(game, chest.global_position + Vector2(-40, -40))
	await Kit.key(self, KEY_E)
	await create_timer(2.2).timeout
	await _close_modal()
	ck(chest.is_open, "%s opens after its guard" % chest.name)
	for id: String in items:
		ck(inventory.get_item_count(id) == before[id] + items[id], "%s: %s × %d" % [chest.name, id, items[id]])
	game.reset_ordinary_fights()  # вороги повертаються, як після медитації (D492)
	ck(fight.fight_won() and chest.is_open, "%s: the fight's return does not shut the chest" % chest.name)


func _finish() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
