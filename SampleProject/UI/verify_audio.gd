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
## Програні звуки: [event, bus, stream path].
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
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	eb = root.get_node("EventBus")
	am = root.get_node("AudioManager")
	am.sound_played.connect(func(event: StringName, stream: AudioStream, bus: StringName) -> void:
		played.append([event, bus, stream.resource_path]))
	sl.get_dialogue_manager().bubble_time_scale = 0.0

	_buses()

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
				node.global_position.x += 4000
	await _combat()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


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
	em.equip_item(who, "sword", "iron_sword", sl.get_item_database().get_item("iron_sword"))
	for i in 4:
		if em.get_weapon_in_hand() == "sword":
			break
		await _tap(&"weapon_next")
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
	_heard(&"hit_heavy", &"SFX", "heavy hit lands")

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
