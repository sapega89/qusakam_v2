extends SceneTree

## Каст кожної навички (BACKLOG 21, D271) у справжній фізиці DesertRoad: клавіша слота хотбару → замах
## (поза героя, ефект «charge», casting_skill) → вивільнення (поза, ефект «release», ушкодження / лікування,
## SP і кулдаун). Удар по героєві під час замаху (D259, D269): ефекту немає, SP витрачено, кулдаун іде.
##   godot --headless --path . --script res://SampleProject/UI/verify_skill_casts.gd

const SkillCastFX := preload("res://SampleProject/Scripts/FX/SkillCastFX.gd")

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _finish_dialogue(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

## Натиснути дію так, як це робить клавіша чи кнопка геймпада (→ _unhandled_input хотбару).
func _tap(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await physics_frame

var game: Node
var eb: Node
var hero: Node
var sm: Node
var em: Node
var target: Node

func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	game.set_quest_flag("desert_road_monologue_complete", true)
	game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	hero = game.player
	sm = sl.get_skill_manager()
	em = sl.get_equipment_manager()
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.set_physics_process(false)
			node.detection_area.monitoring = false
			node.poise_max = 99
			node.poise = 99
			node.Max_Health = 9999
			node.current_health = 9999
			if target == null:
				target = node
			else:
				node.global_position.x += 2000  # лише одна ціль перед героєм
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 6:
		xp.add_xp(1000)
	for id in ["healing_palm", "fire_strike", "electric_strike"]:
		ck(sm.unlock_skill(id) == 0 and sm.get_slot_of_skill(id) >= 0, "%s learned and on the hotbar (slot %d)" % [id, sm.get_slot_of_skill(id)])
	var who: String = sl.get_game_manager().get_active_character().character_id
	var items: Node = sl.get_item_database()
	em.equip_item(who, "sword", "iron_sword", items.get_item("iron_sword"))
	em.equip_item(who, "mace", "iron_mace", items.get_item("iron_mace"))

	print("[1] Every hotbar slot has a keyboard and a pad binding (BACKLOG 24)")
	for i in range(1, 5):
		var kinds: Array = InputMap.action_get_events(StringName("skill_slot_%d" % i)).map(func(e: InputEvent) -> String: return e.get_class())
		ck("InputEventKey" in kinds and ("InputEventJoypadButton" in kinds or "InputEventJoypadMotion" in kinds),
				"skill_slot_%d: %s" % [i, kinds])

	print("[2] A strike with nobody in front does not start a cast")
	await _hold_weapon("sword")
	await _place(400)
	await _tap(_slot_action("fire_strike"))
	ck(hero.combat.state == hero.combat.State.READY and hero.combat.casting_skill == "", "no target: no wind-up")

	await _cast("healing_palm", "", "CastPalm")
	await _cast("fire_strike", "sword", "CastFire")
	await _cast("electric_strike", "mace", "CastStorm")

	await _interrupt("healing_palm", "")
	await _interrupt("fire_strike", "sword")
	await _interrupt("electric_strike", "mace")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

func _slot_action(id: String) -> StringName:
	return StringName("skill_slot_%d" % (sm.get_slot_of_skill(id) + 1))

func _hold_weapon(slot: String) -> void:
	for i in 4:
		if em.get_weapon_in_hand() == slot or slot == "":
			return
		await _tap(&"weapon_next")
	ck(em.get_weapon_in_hand() == slot, "%s in hand" % slot)

func _place(dx: float) -> void:
	hero.global_position = target.global_position + Vector2(-dx, 0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	await physics_frame
	await physics_frame

func _fx() -> Node:
	for child in hero.get_children():
		if child.get_script() == SkillCastFX:
			return child
	return null

func _reset(hurt: bool) -> void:
	await create_timer(1.2).timeout  # i-frames і збій попереднього кроку минули
	sm.clear_cooldowns()
	sm.restore_sp(999)
	target.current_health = 9999
	hero.current_health = hero.Max_Health - (50 if hurt else 0)

## Каст до кінця: замах (поза, ефект, нічого не витрачено) → вивільнення (поза, ефект, ушкодження / лікування).
func _cast(id: String, weapon: String, pose: String) -> void:
	var definition: Object = sm.skill_database.get_skill(id)
	print("[3] %s: wind-up %.2f s, release %.2f s, pose %s" % [id, definition.cast_windup, definition.cast_release, pose])
	await _hold_weapon(weapon)
	await _reset(definition.heal > 0)
	await _place(40)
	var sp0: int = sm.get_current_sp()
	var hp0: int = hero.current_health
	await _tap(_slot_action(id))
	var fx: Node = _fx()
	ck(hero.combat.state == hero.combat.State.CAST_WINDUP and hero.combat.casting_skill == id, "%s: the wind-up runs (state %d)" % [id, hero.combat.state])
	ck(hero.animation == pose + "Windup" and hero.get_node("AnimationPlayer").current_animation == pose + "Windup", "%s: wind-up pose %s" % [id, hero.animation])
	ck(fx != null and fx.get_node("AnimationPlayer").current_animation == "charge", "%s: the charge effect plays" % id)
	ck(sm.get_current_sp() == sp0 and not sm.is_skill_on_cooldown(id) and target.current_health == 9999 and hero.current_health == hp0,
			"%s: nothing spent or applied during the wind-up" % id)
	ck(hero.mover.locked, "%s: the hero stands while casting" % id)
	await _tap(_slot_action(id))
	ck(hero.combat.casting_skill == id, "%s: a second press does not restart the cast" % id)
	await create_timer(definition.cast_windup).timeout
	ck(hero.combat.state == hero.combat.State.CAST_RELEASE and hero.animation == pose + "Release", "%s: release pose %s" % [id, hero.animation])
	ck(is_instance_valid(fx) and fx.get_node("AnimationPlayer").current_animation == "release", "%s: the release effect plays" % id)
	ck(sm.get_current_sp() == sp0 - definition.sp_cost and sm.is_skill_on_cooldown(id), "%s: SP %d → %d, cooldown running" % [id, sp0, sm.get_current_sp()])
	if definition.damage > 0:
		ck(target.current_health < 9999, "%s: the enemy in front is hit (%d)" % [id, 9999 - target.current_health])
	if definition.heal > 0:
		ck(hero.current_health > hp0, "%s: the hero is healed (%d → %d)" % [id, hp0, hero.current_health])
	await create_timer(definition.cast_release + 0.9).timeout
	ck(hero.combat.state == hero.combat.State.READY and not is_instance_valid(fx), "%s: back to ready, the effect is gone" % id)

## Удар під час замаху (D259): збій, ефекту немає, SP витрачено, кулдаун іде.
func _interrupt(id: String, weapon: String) -> void:
	var definition: Object = sm.skill_database.get_skill(id)
	print("[4] %s interrupted by a hit during the wind-up (D259)" % id)
	await _hold_weapon(weapon)
	await _reset(definition.heal > 0)
	await _place(40)
	var sp0: int = sm.get_current_sp()
	var interrupted: Array = []
	var record := func(skill: String) -> void: interrupted.append(skill)
	eb.skill_interrupted.connect(record)
	await _tap(_slot_action(id))
	var fx: Node = _fx()
	ck(hero.combat.casting_skill == id and fx != null, "%s: the cast started" % id)
	await create_timer(definition.cast_windup * 0.5).timeout
	hero.take_damage(5, target)
	var hp_after_hit: int = hero.current_health
	await physics_frame
	ck(hero.combat.is_staggered() and hero.combat.casting_skill == "" and interrupted == [id], "%s: staggered, cast interrupted" % id)
	ck(sm.get_current_sp() == sp0 - definition.sp_cost and sm.is_skill_on_cooldown(id), "%s: SP %d → %d, cooldown running" % [id, sp0, sm.get_current_sp()])
	ck(not is_instance_valid(fx), "%s: the effect is gone" % id)
	await create_timer(definition.cast_windup + definition.cast_release).timeout
	ck(target.current_health == 9999 and hero.current_health == hp_after_hit, "%s: no damage and no heal" % id)
	eb.skill_interrupted.disconnect(record)
