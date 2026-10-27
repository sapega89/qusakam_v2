extends SceneTree

## Смерть героя (H1, D138): кадри Death 1–4 по черзі раз, 4-й тримається; керування вимкнене, зброї не видно,
## тінь (D788) лежить на підлозі під тілом; Game Over — лише коли поза дограла; респавн (kill) ставить героя на ноги
## й повертає керування. Смерть у повітрі — тіло падає на підлогу під час пози; смерть посеред ривка (D812) — тіло не їде далі.
##   godot --headless --path . --script res://SampleProject/UI/verify_hero_death.gd

const DEATH := "res://SampleProject/Sprites/Player/Death/%d.png"

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

## Проклацує справжній діалог до кінця (як verify_combat_flow).
func _finish_dialogue(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _frame(player: Node) -> int:
	var path: String = (player.get_node(^"Sprite2D") as Sprite2D).texture.resource_path
	for i in range(1, 5):
		if path == DEATH % i:
			return i
	return 0

## Низ колізії героя у світі.
func _feet(player: Node2D) -> float:
	var body: CollisionShape2D = player.get_node(^"CollisionShape2D")
	return body.global_position.y + (body.shape as RectangleShape2D).size.y / 2.0

## Зброю видно: на Pivot (WeaponView) або намальовану в кадрі тіла з бібліотеки зброї (sword/…, BACKLOG 42).
func _weapon_shown(player: Node) -> bool:
	var drawn: bool = String((player.get_node(^"AnimationPlayer") as AnimationPlayer).assigned_animation).contains("/")
	return (player.get_node(^"WeaponMount/Pivot") as Node2D).visible or drawn

func _close_game_over() -> void:
	var screen: Node = get_first_node_in_group(&"game_over_screen")
	screen.get_parent().free()
	paused = false

func _initialize() -> void:
	var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
	rolls.calm()
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 10: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	# Вороги дороги не заважають: смерть від пастки (без джерела)
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Node2D = game.player
	for i in 30: await physics_frame
	var weapon_view: Node2D = player.get_node(^"WeaponMount")
	var shadow: Node2D = player.get_node(^"Shadow")

	print("[1] Death on the floor: frames 1-4 once, frame 4 held, controls off")
	ck(player.is_on_floor() and not player.event, "standing and free before (on floor %s, event %s)" % [player.is_on_floor(), player.event])
	var who: String = sl.get_game_manager().get_active_character().character_id
	sl.get_equipment_manager().equip_item(who, "sword", "iron_sword", sl.get_item_database().get_item("iron_sword"))
	weapon_view.sheathed = false  # зброя в руці, як у бою
	await process_frame
	ck(weapon_view.visible and _weapon_shown(player), "the weapon is drawn before death (in hand %s)" % weapon_view.visible)
	var x0: float = player.global_position.x
	player.take_damage(99999)
	ck(player.is_dead and player.event and player.animation == "Death", "dead: controls off, Death playing (%s)" % player.animation)
	Input.action_press(&"move_right")
	var frames: Array[int] = []
	var shown_at := -1.0
	var weapon_seen := false
	var shadow_ok := true
	var elapsed := 0.0
	while elapsed < 1.5:
		await physics_frame
		await process_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second  # у фізичних кроках, не в годиннику (B186)
		var f := _frame(player)
		if frames.is_empty() or frames[-1] != f:
			frames.append(f)
		weapon_seen = weapon_seen or _weapon_shown(player)
		if shadow.visible and absf(shadow.global_position.y - _feet(player)) > 0.5:
			shadow_ok = false
		if get_first_node_in_group(&"game_over_screen") != null:
			shown_at = elapsed
			break
	Input.action_release(&"move_right")
	ck(frames == [1, 2, 3, 4], "frames in order, once: %s" % [frames])
	ck(_frame(player) == 4, "frame 4 is held under the Game Over screen")
	ck(absf(player.global_position.x - x0) < 0.5, "move_right held: the body did not move (%.1f px)" % (player.global_position.x - x0))
	ck(not weapon_seen, "the weapon is hidden for the whole pose")
	ck(shadow.visible and shadow_ok, "the shadow lies on the floor under the body")
	ck(shown_at >= 0.7 and shown_at < 1.2, "Game Over comes once the pose has played (%.2f s)" % shown_at)
	var anim: AnimationPlayer = player.get_node(^"AnimationPlayer")
	var length: float = anim.get_animation(&"Death").length
	ck(length >= 0.6 and length <= 0.8 and not anim.get_animation(&"Death").loop_mode, "Death lasts %.2f s, no loop" % length)

	print("[2] Respawn: on his feet, in control, the weapon back")
	_close_game_over()
	player.kill()
	for i in 20: await physics_frame
	ck(not player.is_dead and not player.event and player.death_left == 0.0, "alive and free (dead %s, event %s)" % [player.is_dead, player.event])
	ck(player.current_health == player.Max_Health, "full HP (%d/%d)" % [player.current_health, player.Max_Health])
	ck(_frame(player) == 0 and player.animation != "Death", "not lying any more (%s)" % player.animation)
	await process_frame
	ck(_weapon_shown(player), "the weapon is shown again")
	var x1: float = player.global_position.x
	Input.action_press(&"move_right")
	for i in 20: await physics_frame
	Input.action_release(&"move_right")
	ck(player.global_position.x > x1 + 5.0, "walks again (%.1f px)" % (player.global_position.x - x1))

	print("[3] Death in the air: the body falls to the floor during the pose")
	for i in 30: await physics_frame
	player.kill_cooldown = 0.0
	player.global_position.y -= 80.0
	player.velocity = Vector2.ZERO
	await physics_frame
	ck(not player.is_on_floor(), "in the air")
	player.take_damage(99999)
	for i in 120:
		await physics_frame
		if get_first_node_in_group(&"game_over_screen") != null:
			break
	ck(player.is_on_floor() and _frame(player) == 4, "lying on the floor at the end (on floor %s, frame %d)" % [player.is_on_floor(), _frame(player)])
	ck(shadow.visible and absf(shadow.global_position.y - _feet(player)) < 0.5, "the shadow is back under the body")
	_close_game_over()

	print("[4] Death during a dash (D812): the body stops where he died, the dash does not carry it on")
	player.kill()
	for i in 30: await physics_frame
	player.kill_cooldown = 0.0
	var sm: Node = sl.get_skill_manager()
	var cast_move: int = load("res://SampleProject/Scripts/Player/Components/PlayerCombat.gd").State.CAST_MOVE
	sl.get_game_manager().player_state.unlocked_skills.append("dash_strike")
	sm.set_max_sp(1000)
	sm.restore_sp(1000)
	ck(sm.cast_skill("dash_strike") == 0, "Dash Strike starts")
	for i in 60:
		if player.combat.state == cast_move:
			break
		await physics_frame
	ck(player.combat.state == cast_move, "the hero is dashing")
	var x2: float = player.global_position.x
	player.take_damage(99999)
	for i in 120:
		await physics_frame
		if get_first_node_in_group(&"game_over_screen") != null:
			break
	ck(player.is_dead and absf(player.global_position.x - x2) < 2.0, "the body stayed where he died (%.1f px)" % (player.global_position.x - x2))
	_close_game_over()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0 if fails.is_empty() else 1)
