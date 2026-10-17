extends SceneTree

## Бій у реальній фізиці (DesertRoad, 4 вороги): гравець бʼє ворога, вороги наздоганяють і
## бʼють гравця, смерть ворога доходить до кінця (анімація, зникнення, лут, стан).
## Раніше бій не покривав жоден тест — рефакторинг DefaultEnemy / EnemyLogic / EnemyView
## (D131) перевіряти було нічим.
##   godot --headless --path . --script res://SampleProject/UI/verify_combat_flow.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

# Без типів CombatBody2D / EnemyLogic / GameGroups: скрипт тесту компілюється до autoload,
# а ці класи посилаються на EventBus — тип у тесті ламає компіляцію всього ланцюга.
func _enemies(road: Node) -> Array:
	var found: Array = []
	for node in road.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			found.append(node)
	return found

## Проклацує справжній діалог до кінця (accept як Enter / клік у грі).
func _finish_dialogue(dm: Node) -> void:
	# Діалоги йдуть ланцюжком із паузою між ними (черга DialogueManager) — доки не стихне.
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())  # вступ Canyon
	var inv: Node = sl.get_inventory_manager()

	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 10: await process_frame
	var road: Node = game.map
	for i in 6: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())  # репліка перед боєм
	await create_timer(2.5).timeout
	var enemies: Array = _enemies(road)
	ck(enemies.size() == 4, "4 enemies spawned (%d)" % enemies.size())

	print("[1] The player hits an enemy")
	var target = enemies[0]
	var hits: Array = []
	target.damage_token.connect(func(d: int) -> void: hits.append(d))
	var hp_before: int = target.current_health
	var dmg: int = game.player.combat.damage_applier.current_damage
	game.player.global_position = target.global_position + Vector2(-26, 0)
	game.player.velocity = Vector2.ZERO
	await create_timer(0.05).timeout
	game.player.combat.perform_attack(1)
	await create_timer(0.6).timeout
	# B57: хітбокс бив і через DamageApplier, і через Hurtbox ворога — два ушкодження за удар.
	ck(hits == [dmg], "one hit = one damage event of %d (got %s)" % [dmg, hits])
	ck(target.current_health == hp_before - dmg, "enemy lost exactly %d HP (%d → %d)" % [dmg, hp_before, target.current_health])

	print("[1b] An attack facing away misses")
	hits.clear()
	hp_before = target.current_health
	game.player.global_position = target.global_position + Vector2(-26, 0)
	await create_timer(0.05).timeout
	game.player.combat.perform_attack(-1)
	await create_timer(0.6).timeout
	ck(hits.is_empty() and target.current_health == hp_before, "a miss deals no damage (events %s)" % [hits])

	print("[2] Enemies chase and hit the player")
	game.player.current_health = game.player.Max_Health
	var player_hp: int = game.player.current_health
	game.player.global_position = enemies[1].global_position + Vector2(-60, 0)
	await create_timer(4.0).timeout
	ck(game.player.current_health < player_hp, "player lost HP (%d → %d)" % [player_hp, game.player.current_health])
	ck(enemies[1].enemy_logic.current_state != 0 or enemies[2].enemy_logic.current_state != 0, "enemies left IDLE")

	print("[3] Enemy death runs to the end")
	var potions_before: int = inv.get_item_count("potion")
	var coins_before: int = inv.get_item_count("coin")
	game.player.current_health = game.player.Max_Health
	var victim = enemies[1]
	victim.die()
	await create_timer(1.5).timeout
	ck(not victim.visible, "dead enemy is hidden")
	ck(not victim.is_alive(), "dead enemy is not alive")
	ck(inv.get_item_count("potion") + inv.get_item_count("coin") > potions_before + coins_before, "death gave loot (first-kill potions or coins)")

	for enemy in _enemies(road):
		if enemy.is_alive():
			enemy.die()
	await create_timer(1.0).timeout
	ck(game.get_quest_flag("desert_road_fight_complete"), "all dead → fight complete")

	print("[4] The player leaves the tree mid-attack (scene change)")
	var player: Node = game.player
	var combat: Node = player.combat
	await create_timer(combat.attack_cooldown_time).timeout
	combat.perform_attack(1)
	ck(combat.is_attacking, "attack started")
	game.remove_child(player)
	for i in 3: await process_frame
	ck(not combat.is_attacking, "attack ended off-tree, no get_tree() on null")
	game.add_child(player)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
