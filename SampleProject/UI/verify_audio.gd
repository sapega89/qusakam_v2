extends SceneTree

## Звук (BACKLOG 26, design/audio_plan.md, D274–D278): кожна подія грає свій звук на своїй шині.
## Дії героя — справжнім вводом (Input.parse_input_event), удари по героєві — справжнім take_damage.
##   godot --headless --path . --script res://SampleProject/UI/verify_audio.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var game: Node
var eb: Node
var am: Node
var sl: Node
var hero: Node
var sm: Node
var em: Node
var target: Node
## Програні звуки: [event, bus, stream path, pitch_scale].
var played: Array = []

func _finish_dialogue(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _tap(action: StringName) -> void:
	_press(action)
	await physics_frame
	_press(action, false)

## Подію [param event] програно (після останнього _mark) на шині [param bus] файлом з її таблиці.
func _heard(event: StringName, bus: StringName, label: String) -> void:
	var files: Array = am.events[event].files.map(func(f: String) -> String: return am.AUDIO_ROOT + f)
	var hits: Array = played.filter(func(p: Array) -> bool: return p[0] == event)
	ck(not hits.is_empty() and hits.all(func(p: Array) -> bool: return p[1] == bus and p[2] in files),
			"%s → %s on %s (%s)" % [label, event, bus, hits])

func _not_heard(event: StringName, label: String) -> void:
	ck(not played.any(func(p: Array) -> bool: return p[0] == event), "%s: no %s" % [label, event])

func _mark() -> void:
	played.clear()

func _initialize() -> void:
	# D393: кидки крита й ухилення з CALM_SEED — удари по героєві не ухиляються випадково (5 %), звук болю чути завжди
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
	am = root.get_node("AudioManager")
	am.sound_played.connect(func(event: StringName, stream: AudioStream, bus: StringName, pitch: float) -> void:
		played.append([event, bus, stream.resource_path, pitch]))
	sl.get_dialogue_manager().bubble_time_scale = 0.0

	_buses()

	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	hero = game.player
	sm = sl.get_skill_manager()
	em = sl.get_equipment_manager()
	_setup_enemies()
	await _world()
	await _combat()
	await _rooms()
	await _voices()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


## Ворогів зупинено (стоять, не бачать героя, не падають від комбо); перший — ціль, решта далеко.
func _setup_enemies() -> void:
	target = null
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
				node.global_position.x += 4000


func _buses() -> void:
	print("[1] Buses: Ambience and Voice go into SFX, so the Sound Effects slider covers them (D274)")
	for bus in ["Music", "SFX", "Ambience", "Voice"]:
		ck(AudioServer.get_bus_index(bus) >= 0, "bus %s exists" % bus)
	ck(AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience")) == &"SFX", "Ambience sends into SFX")
	ck(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == &"SFX", "Voice sends into SFX")
	ck(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")) == &"Master", "SFX sends into Master")
	am.set_sfx_volume(0.25)
	ck(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))) - 0.25) < 0.01, "the SFX slider sets the SFX bus")
	am.set_sfx_volume(0.9)


func _place(dx: float) -> void:
	hero.global_position = target.global_position + Vector2(-dx, 0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	await physics_frame
	await physics_frame


func _combat() -> void:
	print("[2] Combat: every swing, hit, guard, stagger, draw/sheathe and cast (D276)")
	var who: String = sl.get_game_manager().get_active_character().character_id
	em.equip_item(who, "sword", "iron_sword", sl.get_item_database().get_item("iron_sword"))  # вдягнений — в руці (D475)
	await create_timer(3.5).timeout  # бій від екіпірування минув

	await _place(600)
	_mark()
	await _tap(&"attack")
	await process_frame
	_heard(&"swing", &"SFX", "a swing at the air")
	_not_heard(&"hit", "a miss")
	_heard(&"draw", &"SFX", "the fight starts with a sword in hand")

	await create_timer(0.8).timeout
	await _place(40)
	_mark()
	await _tap(&"attack")
	for i in 6: await physics_frame
	_heard(&"hit", &"SFX", "a swing that lands")

	await create_timer(0.8).timeout
	_mark()
	await _tap(&"heavy_attack")
	await process_frame
	_heard(&"heavy_windup", &"SFX", "heavy wind-up")
	await create_timer(0.8).timeout
	_heard(&"swing_heavy", &"SFX", "heavy strike")
	_heard(&"hit_strike", &"SFX", "heavy hit lands (its own sound, D581)")

	await create_timer(1.5).timeout
	_mark()
	hero.take_damage(5, target)
	_heard(&"hero_hurt", &"SFX", "the hero is hit")

	await create_timer(1.2).timeout
	_press(&"block")
	await physics_frame
	await physics_frame
	_mark()
	hero.take_damage(5, target)
	_heard(&"parry", &"SFX", "a hit right after pressing block (parry)")
	await create_timer(0.6).timeout
	_mark()
	hero.take_damage(5, target)
	_heard(&"block", &"SFX", "a hit on a held block")
	_press(&"block", false)

	_mark()
	target.stagger(0.3, hero.global_position.x)
	_heard(&"stagger", &"SFX", "an enemy staggered")

	await create_timer(1.2).timeout
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 6:
		xp.add_xp(1000)
	ck(sm.unlock_skill("healing_palm") == 0, "Healing Palm learned")
	var slot := StringName("skill_slot_%d" % (sm.get_slot_of_skill("healing_palm") + 1))
	sm.restore_sp(999)
	hero.current_health = hero.Max_Health - 50
	_mark()
	await _tap(slot)
	_heard(&"cast_healing_palm_windup", &"SFX", "Healing Palm wind-up")
	await create_timer(sm.skill_database.get_skill("healing_palm").cast_windup + 0.1).timeout
	_heard(&"cast_healing_palm_release", &"SFX", "Healing Palm release")
	await create_timer(1.5).timeout
	sm.clear_cooldowns()
	sm.restore_sp(999)
	_mark()
	await _tap(slot)
	await create_timer(0.2).timeout
	hero.take_damage(5, target)
	await physics_frame
	_heard(&"cast_interrupt", &"SFX", "a cast interrupted by a hit")
	_not_heard(&"cast_healing_palm_release", "an interrupted cast")

	_mark()
	await create_timer(4.5).timeout
	_heard(&"sheathe", &"SFX", "3 s after the fight the sword is put away")


func _hooks() -> Node:
	return am.get_node(^"SoundHooks")


func _ambience_is(event: StringName, label: String) -> void:
	var loop: AudioStreamPlayer = _hooks().ambience
	var file: String = am.AUDIO_ROOT + am.events[event].files[0]
	ck(is_instance_valid(loop) and loop.playing and loop.bus == &"Ambience" and loop.stream.resource_path == file
			and loop.stream.loop and loop.get_parent() == game,
			"%s: %s loops on Ambience (%s)" % [label, event, loop.stream.resource_path if is_instance_valid(loop) else "none"])


func _world() -> void:
	print("[3] World: room ambience, footsteps by surface, jump, land, dash, pickups, level-up, UI (D276)")
	_ambience_is(&"amb_desert_wind", "DesertRoad")
	hero.global_position = target.global_position + Vector2(-500, -10)
	hero.velocity = Vector2.ZERO
	for i in 30: await physics_frame
	_mark()
	_press(&"move_left")
	await create_timer(0.7).timeout
	_press(&"move_left", false)
	_heard(&"step_sand", &"SFX", "running on DesertRoad sand")
	ck(played.filter(func(p: Array) -> bool: return p[0] == &"step_sand").size() >= 2, "several steps in 0.7 s of running")
	await create_timer(0.3).timeout
	_mark()
	await _tap(&"jump")
	await create_timer(1.2).timeout
	_heard(&"jump", &"SFX", "a jump")
	_heard(&"land", &"SFX", "landing after the jump")
	_mark()
	await _tap(&"dodge")
	_heard(&"dash", &"SFX", "a dash")
	await create_timer(0.8).timeout
	var inventory: Node = sl.get_inventory_manager()
	_mark()
	inventory.add_item("coin", 5)
	_heard(&"coin", &"SFX", "coins picked up")
	_not_heard(&"pickup", "coins")
	_mark()
	inventory.add_item("iron_mace", 1)
	_heard(&"pickup", &"SFX", "an item picked up")
	_mark()
	sl.get_xp_manager().add_xp(1000)
	_heard(&"level_up", &"SFX", "a level up")

	var ui: Node = root.get_node(^"ProjectUISoundController")
	ck(ui.process_mode == Node.PROCESS_MODE_ALWAYS, "UI sounds play under pause (menus pause the game)")
	var button := Button.new()
	button.text = "probe"
	game.add_child(button)
	await process_frame
	var focus_player: AudioStreamPlayer = ui.get_node(^"ButtonFocusedAudioStreamPlayer")
	focus_player.stop()
	# play() іде синхронно з focus_entered; кадр потому короткий тік уже міг відіграти (B94) — дивимось одразу.
	button.grab_focus()
	ck(button.has_focus() and focus_player.playing and focus_player.bus == &"SFX", "focusing a button (pad navigation) ticks on SFX")
	button.queue_free()


func _rooms() -> void:
	print("[4] Rooms: a door into and out of an interior, the hall ambience, wooden floor (D276)")
	var dm: Node = sl.get_dialogue_manager()
	_mark()
	await game.teleport_to_room("res://SampleProject/Maps/MayorHall.tscn", ^"Arrival")
	for i in 30: await process_frame
	await _finish_dialogue(dm)
	await create_timer(1.0).timeout
	_heard(&"door", &"SFX", "DesertRoad → MayorHall")
	_ambience_is(&"amb_hall", "MayorHall")
	hero = game.player
	_mark()
	_press(&"move_right")
	await create_timer(0.8).timeout
	_press(&"move_right", false)
	_heard(&"step_wood", &"SFX", "walking in the Mayor Hall")
	_mark()
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 30: await process_frame
	await _finish_dialogue(dm)
	_heard(&"door", &"SFX", "MayorHall → DesertRoad")
	_ambience_is(&"amb_desert_wind", "back on DesertRoad")


func _pitch_of(event: StringName) -> float:
	for p: Array in played:
		if p[0] == event:
			return p[3]
	return 0.0


func _voices() -> void:
	print("[5] Voices: babble while typing, greetings on a talk the hero starts, enemies, bosses, companions (D277, D278)")
	var dm: Node = sl.get_dialogue_manager()
	hero = game.player
	await create_timer(2.5).timeout  # вороги кімнати з'являються не одразу
	_setup_enemies()
	var dq: Node = root.get_node(^"DialogueQuest")
	var registry: Dictionary = dq.CharacterDB.get_character_registry()
	var mute: Array = registry.keys().filter(func(id: String) -> bool: return not am.voices.has(id))
	ck(mute.is_empty(), "every DialogueQuest character has a babble voice (missing: %s)" % [mute])
	for voice: String in am.voices.values():
		ck(am.has_event(StringName("babble_" + voice)), "babble_%s exists" % voice)

	# The box: a line types for 0.8 s → the speaker's babble on Voice.
	var box: Node = null
	var replay_done := [false]
	var run := func() -> void:
		await dm.replay("res://dialogue_quest/OldMan_Outside.dqd")
		replay_done[0] = true
	run.call()
	box = dm.current_dialogue_box
	_mark()
	await create_timer(0.8).timeout
	_heard(&"babble_kusakam", &"Voice", "Kusakam's line typing")
	box.finish()
	box.accept()
	await process_frame
	_mark()
	await create_timer(0.8).timeout
	_heard(&"babble_grandfather", &"Voice", "the grandfather's line typing")
	_not_heard(&"greet_grandfather", "a dialogue started by the story (first-meeting cutscene path)")
	for i in 10:
		if replay_done[0]:
			break
		box.finish()
		box.accept()
		await process_frame
	ck(replay_done[0], "the replay ended")

	# The cloud talk (D263) types at the box speed and babbles in Kusakam's voice.
	# The first line is Kusakam's (D437: no narration before it); it types at the box speed.
	dm.bubble_time_scale = 1.0
	_mark()
	dm.start_dialogue("res://dialogue_quest/Canyon_AbductionCutscene.dqd", true)
	await create_timer(1.0).timeout
	_heard(&"babble_kusakam", &"Voice", "Kusakam's cloud talk typing")
	dm.bubble_time_scale = 0.0
	for i in 40:
		if not dm.is_dialogue_active():
			break
		_press(&"dq_accept")
		await process_frame
		_press(&"dq_accept", false)
		await create_timer(0.3).timeout
	ck(not dm.is_dialogue_active(), "the cloud talk ended")

	# The hero walks up to the merchant on DesertRoad: his menu opens by itself (D454) and he greets him.
	var merchant: Node2D = game.map.get_node(^"Merchant")
	_mark()
	hero.global_position = merchant.global_position + Vector2(-40, -10)
	hero.velocity = Vector2.ZERO
	for i in 20: await physics_frame
	ck(merchant.npc_menu.visible, "walking up opens the merchant's menu")
	_heard(&"greet_merchant", &"Voice", "talking to the merchant")
	merchant.npc_menu.cancelled.emit()

	# Enemies: a pain grunt per hit, a death cry on the last; the tank's voice is deeper.
	_mark()
	target.take_damage(5, hero)
	_heard(&"enemy_grunt", &"Voice", "an enemy hit")
	var expected: float = am.enemy_voice_pitch[target.enemy_stats.enemy_type]
	ck(absf(_pitch_of(&"enemy_grunt") - expected) <= expected * 0.07, "voice pitch of a %s: %.2f (≈ %.2f)" % [target.enemy_stats.enemy_type, _pitch_of(&"enemy_grunt"), expected])
	_mark()
	target.current_health = 3
	target.take_damage(5, hero)
	_heard(&"enemy_death", &"Voice", "an enemy killed")
	_not_heard(&"enemy_grunt", "the killing blow")

	# Bosses (D278, D310): each real boss has its own voice — the Brass Collector roars, the djinn roars and laughs, the mercenary (D466) roars and guffaws.
	for scene: String in ["brass_collector", "fire_djinn", "lab_boss"]:
		var boss: Node = load("res://SampleProject/Scenes/Characters/Bosses/%s.tscn" % scene).instantiate()
		boss.process_mode = Node.PROCESS_MODE_DISABLED  # лише голос: ШІ не потрібне
		game.map.add_child(boss)
		boss.global_position = hero.global_position + Vector2(400, 0)
		var voice: Dictionary = am.boss_voices[boss.enemy_stats.enemy_type]
		boss.Max_Health = 9999
		boss.current_health = 9999
		_mark()
		for i in 3:
			eb.attack_started.emit(boss, hero)
		_heard(StringName(voice.roar), &"Voice", "%s's first swing" % scene)
		_heard(StringName(voice.shout), &"Voice", "%s's later swing" % scene)
		_not_heard(&"enemy_grunt", scene)
		_mark()
		boss.current_health = 3
		boss.take_damage(5, hero)
		_heard(StringName(voice.death), &"Voice", "%s killed" % scene)
		boss.bar.queue_free()
		boss.queue_free()
	ck(am.boss_voices.brass_collector.roar == "brass_collector_roar" and am.boss_voices.fire_djinn.roar == "fire_djinn_roar"
			and am.boss_voices.fire_djinn.shout == "fire_djinn_laugh", "the bosses' own roars, the djinn laughs (%s)" % [am.boss_voices])
	# Голос сцени (Cutscene.voice): звучить, а під пропуском — ні.
	var cs = load("res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd").new()
	_mark()
	cs.voice(&"prisoner_incantation")
	_heard(&"prisoner_incantation", &"Voice", "a cutscene voice")
	cs._skip()
	_mark()
	cs.voice(&"fire_djinn_laugh")
	_not_heard(&"fire_djinn_laugh", "a cutscene voice under a skip")
	cs.end()
	await process_frame

	# Hero: pain voice; heavy attack shout. Companion: the guard's call on assist.
	await create_timer(1.2).timeout
	_mark()
	hero.take_damage(3, null)
	_heard(&"hero_hurt_voice", &"Voice", "the hero hurt")
	await create_timer(1.2).timeout
	_mark()
	await _tap(&"heavy_attack")
	_heard(&"hero_effort", &"Voice", "Kusakam's heavy attack")
	await create_timer(1.5).timeout
	sl.get_companion_manager().offer_guard(true)
	_mark()
	await _tap(&"assist")
	for i in 4: await process_frame
	_heard(&"call_guard", &"Voice", "the guard called in")
