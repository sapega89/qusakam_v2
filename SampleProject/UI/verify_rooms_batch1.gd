extends SceneTree

## Бічні кімнати D643 (branch batch 1) справжнім вводом:
##   godot --headless --path . --script res://SampleProject/UI/verify_rooms_batch1.gd
##   1. Дані: кожна кімната на карті MetSys і рівно в одній локації, брами в gates.json, розписи в journal_stories.
##   2. Печера ящурів: вхід у каньйоні (E) → герой у намальованому отворі печери, вихід — ним же назад до входу; ґрати святилища без ключа — репліка, герой стоїть; дідова розмова дає ключ
##      один раз; E відмикає (ключ витрачено); розпис → журнал; скриня → Deep Gourd Amulet.
##   3. Розпис дракона: двері за брилою на плато не відповідають, легкий удар брилу лише хитає, важкий — розбиває;
##      E — у печерку; розпис → журнал; скриня → Jackal Tooth Amulet.
##   4. Табір бандитів: двері табору на дорозі без ключа — репліка (D723); громило-одинак (Fight_LoneElite) дає
##      ключ табору, E ним відмикає двері (ключ витрачено) → табір; ворота з дороги біля медитації зачинені (репліка); частокіл без ключа
##      не пускає; бій → Stockade Key один раз (двічі після повернення ворогів); частокіл відмикається; скриня з
##      награбованим + Breaker's Ring; задні ворота зсередини → дорога біля медитації, і тепер з дороги вони ведуть у табір.
##   5. Меса: дорога (E) → низ; стрибками по уступах нагору; скриня → Iron Halberd + Sand Runner's Ring; грифи (D558).
##   6. Льох під брамою: двері зачинені (репліка); вартовий говорить лише після бою біля брами; розмова → двері
##      відчинені; кажани: спершу один, далі троє (D582); скриня → Hermit's Amulet.
##   7. Сейв → завантаження: скрині відкриті, ґрати відчинені, брила розбита, двері табору, шорткат і льох відчинені, обидва
##      розписи в журналі, ключів немає.
## Пише лише в user://verify_rooms_batch1/.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const JournalRecords = preload("res://SampleProject/Scripts/Systems/journal_records.gd")
const LocationDB = preload("res://SampleProject/Scripts/Systems/LocationDB.gd")
const MAPS := "res://SampleProject/Maps/%s.tscn"
const GATES := "res://SampleProject/Resources/Data/gates.json"
const ROOMS := {
	"LizardCave": "canyon_of_whispers", "DragonMural": "canyon_of_whispers", "BanditCamp": "canyon_of_whispers",
	"MesaClimb": "canyon_of_whispers", "GatehouseCellar": "city",
}
const TEST_DIR := "user://verify_rooms_batch1/"
const TEST_SLOT := 1

var fails: Array[String] = []
var sl: Node
var dm: Node
var game: Node
var inventory: Node
var started: Array[String] = []
## Charms.gd знає автолоади, тож вантажиться вже з ними (preload у SceneTree-скрипті не компілюється).
var Charms: GDScript

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _boot() -> Node:
	var g: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 60: await physics_frame
	return g


func _room(room: String, at: NodePath) -> void:
	await game.teleport_to_room(MAPS % room, at)
	for i in 20: await physics_frame
	await Kit.drain(self)


## Де стати, щоб брама запропонувала «Open»: її Area — біля ближньої грані арки, тіло брами — на всю її ширину.
func _open_spot(gate: Node) -> float:
	return gate.get_node(^"Area/CollisionShape2D").global_position.x


func _stand(at: Vector2) -> void:
	game.player.set_movement_enabled(true)
	game.place_player(at)
	game.player.velocity = Vector2.ZERO
	for i in 30: await physics_frame


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


## E біля дверей; чекає, поки кімната зміниться.
func _enter(door: String, expect_room: String) -> void:
	var node: Node = game.map.get_node(door)
	await _stand(node.global_position)
	ck(node.get_node("Interactable").player_nearby, "%s offers \"%s\"" % [door, node.get_node("Interactable").action_text])
	await Kit.key(self, KEY_E)
	for i in 120:
		if game.map.scene_file_path == MAPS % expect_room:
			break
		await physics_frame
	for i in 20: await physics_frame
	await Kit.drain(self)
	ck(game.map.scene_file_path == MAPS % expect_room, "%s leads into %s (now %s)" % [door, expect_room, game.map.scene_file_path.get_file()])


## E біля скрині; повертає, що прибуло в торбу.
func _open_chest(chest_path: String, items: Dictionary, charm: String) -> void:
	var chest: Node = game.map.get_node(chest_path)
	await _stand(chest.global_position + Vector2(-40, -40))
	ck(chest.get_node("Interactable").player_nearby, "%s offers \"Open\"" % chest_path)
	var before := {}
	for id: String in items: before[id] = inventory.get_item_count(id)
	await Kit.key(self, KEY_E)
	await create_timer(2.2).timeout
	await _close_modal()
	ck(chest.is_open, "%s is open" % chest_path)
	for id: String in items:
		ck(inventory.get_item_count(id) == before[id] + items[id], "%s: %s × %d in the bag" % [chest_path, id, items[id]])
	ck(Charms.owned().has(charm), "%s: the charm %s is owned" % [chest_path, charm])


func _read(note_path: String, story_id: String, title: String) -> void:
	var note: Node = game.map.get_node(note_path)
	await _stand(Vector2(note.global_position.x, game.player.global_position.y))
	ck(note.get_node("Interactable").player_nearby, "%s offers \"Read\"" % note_path)
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 6)
	ck(Kit.modal_text(self).contains(title), "the modal shows «%s»" % title)
	await _close_modal()
	ck(JournalRecords.stories().map(func(s: Dictionary) -> String: return s.id).has(story_id), "the journal keeps %s" % story_id)


## Добиває бій кімнати: ставить героя в тригер, вбиває всіх, хто встав, доки бій не добито.
func _win(spawner_name: String) -> void:
	var spawner: Node = game.map.get_node(spawner_name)
	game.player.global_position = Vector2(spawner.trigger_area.global_position.x, game.player.global_position.y)
	for round in 12:
		# Тут кімната, а не бій: вороги тепер справді б'ють (D775), поки скрипт їх добиває, — герой не має загинути
		game.player.current_health = game.player.Max_Health
		await create_timer(1.5).timeout
		for enemy in spawner.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive()):
			enemy.die()
		await create_timer(0.5).timeout
		if spawner.fight_cleared() and spawner.get_alive_enemies_count() == 0:
			break
	await _close_modal()
	ck(spawner.fight_cleared(), "%s is won" % spawner_name)


func _kinds(spawner_name: String) -> Array:
	return game.map.get_node(spawner_name).get_children().filter(func(n: Node) -> bool: return n.get(&"enemy_type") != null) \
			.map(func(p: Node) -> String: return p.enemy_type)


## Стоїть на уступі [param ledge] (верх уступу вище за ноги, на підлозі).
func _on_ledge(ledge: Node2D) -> bool:
	var feet: float = game.player.global_position.y
	return game.player.is_on_floor() and feet < ledge.global_position.y and feet > ledge.global_position.y - 60.0


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
	inventory = sl.get_inventory_manager()
	Charms = load("res://SampleProject/Scripts/Systems/Charms.gd")
	var metsys: Node = root.get_node("MetSys")

	print("[1] Data: the rooms on the map, in their locations; the gates; the story pieces")
	for room: String in ROOMS:
		ck(not metsys.map_data.get_cells_assigned_to(room + ".tscn").is_empty(), "%s has cells on the MetSys map" % room)
		ck(LocationDB.of_room(room) == ROOMS[room], "%s is in %s (%s)" % [room, ROOMS[room], LocationDB.of_room(room)])
	var gates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATES)).gates
	ck(gates.lizard_shrine.key == "grandfather_key" and gates.camp_stockade.key == "camp_key"
			and gates.camp_shortcut.flag == "bandit_camp_shortcut" and gates.gatehouse_cellar.flag == "gatehouse_cellar_allowed",
			"gates.json: the shrine and the stockade open with keys, the shortcut and the cellar with flags")
	ck(not JournalRecords.story("lizard_shrine_mural").is_empty() and not JournalRecords.story("dragon_mural").is_empty(),
			"journal_stories.json has both murals")

	set_meta("start_new_game", true)
	game = await _boot()
	await Kit.drain(self)
	var player: CharacterBody2D = game.player

	print("[2] Lizard Cave: the cave by the bridge, the shrine behind Grandfather's key")
	await _room("Canyon", ^"Arrival")
	await _enter("LizardCaveDoor", "LizardCave")
	var cave_exit: Node2D = game.map.get_node("ExitDoor")
	# Sapega 2026-10-26: зайшов отвором — виходиш ним; отвір печери намальовано на x ≈ 320, біля святилища на x 96 — ні.
	ck(cave_exit.position.x == 320.0 and game.map.get_node("Arrival").position == cave_exit.position,
			"the cave's exit stands in the painted cave opening (x %.0f), the Arrival with it" % cave_exit.position.x)
	ck(player.global_position.distance_to(cave_exit.global_position) < 48.0,
			"the hero arrives at that opening, the door he came by (%s)" % player.global_position)
	var shrine: Node = game.map.get_node("Gate_Shrine")
	ck(_kinds("Fight_CaveLizards") == ["fast", "fast"], "a few small enemies in the open part (%s)" % [_kinds("Fight_CaveLizards")])
	await _stand(Vector2(1100, 380))
	await _hold(&"move_right", 0.8)
	for i in 10: await physics_frame
	ck(player.global_position.x < shrine.global_position.x and not shrine.is_open, "the shrine bars stop the hero (x %.0f)" % player.global_position.x)
	ck(shrine.get_node("Area/Interactable").player_nearby, "the bars offer \"Open\"")
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 10)
	ck(started.has("Gate_LizardShrine_Locked") and not shrine.is_open, "no key: Kusakam's line, the bars stay shut")
	await Kit.drain(self)
	await _room("ElderHouse", ^"ExitDoor")  # дід у своєму домі (D438), розмова — ElderHouse.gd
	game.map._complete_quest_for_dialogue("OldMan_Decision")
	await Kit.frames(self, 6)
	await _close_modal()
	game.map._complete_quest_for_dialogue("OldMan_Decision")
	await Kit.frames(self, 6)
	await _close_modal()
	ck(inventory.get_item_count("grandfather_key") == 1, "Grandfather's decision talk gives the old key once (%d)" % inventory.get_item_count("grandfather_key"))
	await _room("LizardCave", ^"ExitDoor")
	shrine = game.map.get_node("Gate_Shrine")
	await _stand(Vector2(_open_spot(shrine), 380))
	await Kit.key(self, KEY_E)
	await create_timer(0.6).timeout
	ck(shrine.is_open and shrine.get_node("Body/CollisionShape2D").disabled, "with the key, E unlocks the shrine")
	ck(inventory.get_item_count("grandfather_key") == 0, "the key is used up")
	await _read("ShamanMural", "lizard_shrine_mural", "The shamans' mural")
	await _open_chest("Chest_Shrine", {}, "deep_gourd_amulet")
	await _room("LizardCave", ^"ExitDoor")
	ck(game.map.get_node("Gate_Shrine").is_open and game.map.get_node("Chest_Shrine").is_open, "a room reload: the bars open, the chest open")
	await _enter("ExitDoor", "Canyon")
	ck(player.global_position.distance_to(game.map.get_node("LizardCaveDoor").global_position) < 48.0,
			"out of the cave: back at the cave mouth in the Canyon (%s)" % player.global_position)

	print("[3] Dragon Mural: the boulder on the plateau hides the way in")
	var door: Node = game.map.get_node("DragonMuralDoor")
	var wall: Node = game.map.get_node("Wall_Mural")
	await _stand(door.global_position + Vector2(-20, 0))
	ck(not door.get_node("Interactable").enabled, "the door behind the boulder offers nothing")
	ck(player.global_position.x > 1400.0, "the boulder stands in the background: the hero walks up to it (x %.0f)" % player.global_position.x)
	player.combat.perform_attack(1)
	await create_timer(0.8).timeout
	ck(not wall.is_broken and not door.get_node("Interactable").enabled, "a light blow only shakes it")
	player.combat.heavy_attack(1)
	await create_timer(1.5).timeout
	ck(wall.is_broken and door.get_node("Interactable").enabled, "a heavy blow breaks it, the crack offers \"Enter\"")
	await _enter("DragonMuralDoor", "DragonMural")
	await _read("DragonMural", "dragon_mural", "The dragon on the wall")
	await _open_chest("Chest_Mural", {}, "jackal_tooth_amulet")
	await _enter("ExitDoor", "Canyon")
	ck(game.map.get_node_or_null("Wall_Mural") == null and game.map.get_node("DragonMuralDoor/Interactable").enabled,
			"back in the canyon: the boulder stays broken, the way stays open")

	print("[4] Bandit Camp: the fight, the stockade key, the loot, the shortcut")
	game.set_quest_flag("desert_road_fight_complete", true)
	await _room("DesertRoad", ^"Arrival_Start")
	var shortcut: Node = game.map.get_node("CampShortcutDoor")
	await _stand(shortcut.global_position)
	started.clear()
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 20)
	ck(started.has("Gate_CampShortcut_Locked") and game.map.scene_file_path == MAPS % "DesertRoad",
			"the camp gate by the meditation spot is barred from inside (%s)" % [started])
	await Kit.drain(self)
	var camp_door: Node = game.map.get_node("BanditCampDoor")
	ck(camp_door.gate_id == "camp_door" and not camp_door.is_open(), "D723: the camp door is shut before the lone brute")
	await _stand(camp_door.global_position)
	started.clear()
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 20)
	ck(started.has("Gate_CampDoor_Locked") and game.map.scene_file_path == MAPS % "DesertRoad",
			"no key: Kusakam says the door needs a key, the hero stays on the road (%s)" % [started])
	await Kit.drain(self)
	var lone: Node = game.map.get_node("Fight_LoneElite")
	ck(lone.reward == {"bandit_camp_key": 1}, "the lone brute's fight carries the camp key")
	player.Max_Health = 99999  # тест дверей, не бою
	player.current_health = player.Max_Health
	await _win("Fight_LoneElite")
	ck(inventory.get_item_count("bandit_camp_key") == 1, "the brute drops the camp key (%d)" % inventory.get_item_count("bandit_camp_key"))
	await _enter("BanditCampDoor", "BanditCamp")
	ck(inventory.get_item_count("bandit_camp_key") == 0, "the key opens the camp door and is used up")
	var kinds := _kinds("Fight_Camp")
	ck(kinds.size() >= 5 and game.map.get_node("Fight_Camp/BigSlot_BanditBrute_1").big_kind == "bandit_brute",
			"a hard group fight with an elite (%s)" % [kinds])
	var stockade: Node = game.map.get_node("Gate_Stockade")
	await _stand(Vector2(1220, 380))
	await _hold(&"move_right", 0.6)
	ck(player.global_position.x < stockade.global_position.x and not stockade.is_open, "the stockade stops the hero (x %.0f)" % player.global_position.x)
	await Kit.drain(self)
	for round in 2:
		await _win("Fight_Camp")
		ck(inventory.get_item_count("camp_key") == 1, "after win %d: one stockade key (%d)" % [round + 1, inventory.get_item_count("camp_key")])
		game.reset_ordinary_fights()  # вороги повертаються, як після медитації (D492)
		await _room("BanditCamp", ^"ExitDoor")
	await _win("Fight_Camp")
	stockade = game.map.get_node("Gate_Stockade")
	await _stand(Vector2(_open_spot(stockade), 380))
	await Kit.key(self, KEY_E)
	await create_timer(0.6).timeout
	ck(stockade.is_open and inventory.get_item_count("camp_key") == 0, "the key unlocks the stockade and is used up")
	await _open_chest("Chest_Loot", {"potion_lesser": 2, "herb": 3, "leather": 2}, "breaker_ring")
	await _enter("ShortcutDoor", "DesertRoad")
	ck(game.get_quest_flag("bandit_camp_shortcut") and player.global_position.distance_to(game.map.get_node("CampShortcutDoor").global_position) < 60.0,
			"the back gate opens the shortcut: out by the meditation spot (%s)" % player.global_position)
	await _enter("CampShortcutDoor", "BanditCamp")
	ck(player.global_position.x > 1500.0, "from the road the gate now leads into the camp, behind the stockade (x %.0f)" % player.global_position.x)
	await _enter("ExitDoor", "DesertRoad")

	print("[5] Mesa Climb: up the ledges to the chest; vultures overhead")
	await _enter("MesaClimbDoor", "MesaClimb")
	ck(_kinds("Fight_Vultures") == ["vulture", "vulture"], "vultures circle the mesa (%s)" % [_kinds("Fight_Vultures")])
	# Підйом, а не бій: грифів перевіряє verify_fliers. Двері стоять у зоні бою — грифи вже злетіли, і пікірування
	# збивало героя з уступу біля скрині (залежно від таймінгу), тож прибираємо їх.
	var vultures: Node = game.map.get_node("Fight_Vultures")
	vultures.trigger_area.monitoring = false
	for enemy: Node in vultures.spawned_enemies:
		enemy.queue_free()
	var ledges: Array = game.map.get_node("Ledges").get_children()
	var at: Node2D = null
	for ledge: Node2D in ledges:
		# Від краю, що перекриває наступний уступ, — прямо вгору крізь односторонній уступ.
		var shape: RectangleShape2D = ledge.get_node("CollisionShape2D").shape
		var x0: float = ledge.global_position.x - shape.size.x / 2.0
		var x1: float = ledge.global_position.x + shape.size.x / 2.0
		var from := player.global_position.x
		var target := clampf(from, x0 + 14.0, x1 - 14.0)
		var dir: StringName = &"move_right" if target > from else &"move_left"
		Input.action_press(dir)
		for i in 240:
			if absf(player.global_position.x - target) < 8.0:
				break
			await physics_frame
		Input.action_release(dir)
		for i in 10: await physics_frame
		Input.action_press(&"jump")
		await create_timer(0.35).timeout
		Input.action_release(&"jump")
		for i in 90: await physics_frame
		if not _on_ledge(ledge):
			ck(false, "the jump onto %s (hero %s)" % [ledge.name, player.global_position])
			break
		at = ledge
	ck(at != null and at.name == "Ledge_Top", "jumped from ledge to ledge up to the top (%s)" % [at.name if at else "-"])
	await _open_chest("Chest_Mesa", {"iron_halberd": 1}, "sand_runner_ring")
	await _room("MesaClimb", ^"ExitDoor")
	await _enter("ExitDoor", "DesertRoad")

	print("[6] Gatehouse Cellar: the guard's talk opens it; the bats live here")
	await _room("CityGates", ^"Arrival")
	var talk: Node = game.map.get_node("CellarTalk")
	ck(not talk.get_node("Interactable").enabled, "before the fight at the gates the guard has nothing to say")
	var cellar: Node = game.map.get_node("CellarDoor")
	await _stand(cellar.global_position)
	started.clear()
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 20)
	ck(started.has("Gate_GatehouseCellar_Locked") and game.map.scene_file_path == MAPS % "CityGates", "the cellar is shut without leave")
	await Kit.drain(self)
	game.set_quest_flag("city_gates_after_fight_complete", true)
	await Kit.frames(self, 4)
	await _stand(talk.global_position)
	ck(talk.get_node("Interactable").enabled and talk.get_node("Interactable").player_nearby, "after the fight the guard offers \"Talk\"")
	await Kit.key(self, KEY_E)
	await Kit.frames(self, 10)
	ck(started.has("CityGates_Cellar_Guard"), "the guard's talk plays")
	await Kit.drain(self)
	await Kit.frames(self, 6)
	ck(game.get_quest_flag("gatehouse_cellar_allowed"), "the talk lets the hero down")
	await _enter("CellarDoor", "GatehouseCellar")
	ck(_kinds("Fight_LoneBat") == ["bat"] and _kinds("Fight_Bats") == ["bat", "bat", "bat"], "first one bat, then three (D582)")
	await _win("Fight_LoneBat")
	await _win("Fight_Bats")
	await _open_chest("Chest_Cellar", {"potion": 1}, "hermit_amulet")

	print("[7] Save → load")
	ck(game.save_game(), "saved to slot %d" % TEST_SLOT)
	game.queue_free()
	for i in 4: await process_frame
	set_meta("start_new_game", false)
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	game = await _boot()
	await Kit.drain(self)
	ck(game.map.scene_file_path == MAPS % "GatehouseCellar" and game.map.get_node("Chest_Cellar").is_open, "loaded in the cellar, its chest open")
	ck(JournalRecords.stories().size() == 2, "both murals are in the journal (%d)" % JournalRecords.stories().size())
	ck(["deep_gourd_amulet", "jackal_tooth_amulet", "breaker_ring", "sand_runner_ring", "hermit_amulet"].all(
			func(c: String) -> bool: return Charms.owned().has(c)), "the five charms are kept")
	ck(inventory.get_item_count("grandfather_key") == 0 and inventory.get_item_count("camp_key") == 0, "no keys left")
	await _room("LizardCave", ^"ExitDoor")
	ck(game.map.get_node("Gate_Shrine").is_open and game.map.get_node("Chest_Shrine").is_open, "the shrine stays open, its chest empty")
	await _room("BanditCamp", ^"ExitDoor")
	ck(game.map.get_node("Gate_Stockade").is_open and game.map.get_node("Chest_Loot").is_open, "the stockade stays open, the loot taken")
	await _room("MesaClimb", ^"ExitDoor")
	ck(game.map.get_node("Chest_Mesa").is_open, "the mesa chest stays open")
	await _room("Canyon", ^"Arrival")
	ck(game.map.get_node_or_null("Wall_Mural") == null and game.map.get_node("DragonMuralDoor/Interactable").enabled, "the boulder stays broken")
	await _room("DragonMural", ^"ExitDoor")
	ck(game.map.get_node("Chest_Mural").is_open, "the mural chest stays open")
	await _room("DesertRoad", ^"Arrival_Start")
	ck(game.map.get_node("BanditCampDoor").is_open() and inventory.get_item_count("bandit_camp_key") == 0,
			"the camp door stays open, its key gone")
	ck(game.map.get_node("CampShortcutDoor").is_open(), "the camp shortcut stays open")
	await _room("CityGates", ^"Arrival")
	ck(game.map.get_node("CellarDoor").is_open(), "the cellar stays open")
	_finish()


func _finish() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
