extends SceneTree

## Бої в нових кімнатах світу (rooms-finish, D844; Scripts/Tools/build_world_rooms.py → LIVING) у справжній грі:
##   1. Ворогів немає, поки герой не зайде в зону бою; тоді зʼявляються саме ті, що в таблиці, і наземні стоять на
##      підлозі (жоден не падає крізь неї).
##   2. Гурт — щонайбільше три (D817/D831), рівень ворога скейлиться від героя з зсувом зони (D840/D857).
##   3. Перемога платить досвід ворогів + win_xp бою; виграний бій не вертається, поки не було медитації (D492).
##   godot --headless --path . --script res://SampleProject/UI/verify_world_fights.gd
## Пише лише в user://verify_world_fights/.

const MAPS := "res://SampleProject/Maps/%s.tscn"
const TEST_DIR := "user://verify_world_fights/"
const Kit = preload("res://SampleProject/UI/input_kit.gd")
## Кімната → {бій: типи ворогів}.
const FIGHTS := {
	"CanyonFloor": {"Fight_CanyonFloor": ["fast", "vulture"]},
	"LizardCaves": {"Fight_Bats": ["bat", "bat"], "Fight_Scorpion": ["tank"]},
	"MesaTop": {"Fight_Lookout": ["archer", "melee"]},
	"Dunes": {"Fight_Dunes": ["melee", "fast"]},
	"Aqueduct": {"Fight_Aqueduct": ["archer", "fast"]},
	"OldRuins": {"Fight_Ruins": ["melee", "shield", "fast"]},
	"Cistern": {"Fight_Bats": ["bat", "bat"]},
	"AlchemistCorridor": {"Fight_Corridor": ["shield", "fast"]},
	"CollapsedDrain": {"Fight_Drain": ["tank", "fast"]},
}

var fails: Array[String] = []
## EnemyScaling зчитує автозавантаження — тож load() після старту, не preload.
var Scaling: Script


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _alive(spawner: Node) -> Array:
	return spawner.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"enemies") and n.is_alive())


func _initialize() -> void:
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false
	save_system.settings_module.settings.hints = false
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(1)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = await Kit.boot(self)
	Scaling = load("res://SampleProject/Scripts/Gameplay/EnemyScaling.gd")
	var player: CharacterBody2D = game.player
	player.min_health = 1  # тут лише хто й де зʼявляється, не виживання героя
	var xp: Node = sl.get_xp_manager()
	for room: String in FIGHTS:
		await game.teleport_to_room(MAPS % room, ^"Arrival")
		for i in 20: await physics_frame
		print("[%s]" % room)
		for fight: String in FIGHTS[room]:
			var spawner: Node = game.map.get_node(fight)
			var want: Array = FIGHTS[room][fight]
			ck(_alive(spawner).is_empty(), "%s: nobody before the hero comes" % fight)
			ck(want.size() <= 3, "%s: at most three (D817): %s" % [fight, want])
			var zone: Area2D = spawner.trigger_area
			player.global_position = Vector2(zone.global_position.x, zone.global_position.y + 100.0)
			player.velocity = Vector2.ZERO
			await create_timer(2.5).timeout
			var alive: Array = _alive(spawner)
			var types: Array = spawner.spawn_points.map(func(p: Node) -> String: return p.enemy_type)
			ck(alive.size() == want.size() and types == want, "%s: %s came (%d alive, points %s)" % [fight, want, alive.size(), types])
			var zone_offset: int = Scaling.zone_offset(room)
			for enemy: Node in alive:
				var level: int = Scaling.scaled_level(spawner.enemy_level, zone_offset, xp.current_level, "ordinary")
				ck(not enemy.elite and enemy.scaled_level == level, "%s: %s, an ordinary enemy, at level %d (room %d, zone %+d)" % [fight, enemy.name, enemy.scaled_level, spawner.enemy_level, zone_offset])
				if enemy.flying:
					continue
				for i in 30:
					if enemy.is_on_floor():
						break
					await physics_frame
				ck(enemy.is_on_floor() and enemy.global_position.y < zone.global_position.y + 300.0,
						"%s: %s stands on the floor (y %.0f)" % [fight, enemy.name, enemy.global_position.y])
			var gained: Array[int] = [0]
			var count_xp := func(amount: int, _total: int) -> void: gained[0] += amount
			xp.xp_gained.connect(count_xp)
			var due: int = spawner.win_xp
			for enemy: Node in alive:
				due += enemy.xp_reward
				enemy.die()
			for i in 6: await physics_frame
			xp.xp_gained.disconnect(count_xp)
			ck(_alive(spawner).is_empty() and gained[0] == due, "%s: won, +%d XP (expected %d, win_xp %d)" % [fight, gained[0], due, spawner.win_xp])
			player.global_position = Vector2(zone.global_position.x + 40.0, zone.global_position.y + 100.0)
			await create_timer(1.5).timeout
			ck(_alive(spawner).is_empty(), "%s: a won fight stays won" % fight)
	game.queue_free()
	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
