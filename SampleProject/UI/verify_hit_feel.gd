extends SceneTree

## Вага удару (D581) у справжній фізиці DesertRoad, герой проти бандита:
##   [1] завмирання росте з ударом: легкий < важкий < рипост < удар боса по героєві; тряска — лише важкий, рипост
##       і удари по героєві, і вона теж росте;
##   [2] справжні влучання: легкий без тряски, важкий і рипост — з трясками своєї сили; завмирання міряне в мс;
##   [3] удар по героєві: тряска, білий спалах кадрів героя, що гасне;
##   [4] Settings → Screen Shake Off: тряска лише сигналом, камера стоїть;
##   [5] звуки: легкий, фінішер, важкий, рипост, блок, парирування — різні події sound_events.json.
##   godot --headless --path . --script res://SampleProject/UI/verify_hit_feel.gd

const BANDIT := "res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn"
const BANDIT_STATS := "res://SampleProject/Resources/Enemies/enemy_stats_melee.tres"
## Скрипти з автозавантаженнями всередині — load після старту, не preload (SceneTree-скрипт компілюється раніше).
var VFX: GDScript
var SOUNDS: GDScript

var fails: Array[String] = []
var game: Node
var hero: Node
var combat: Node
var bandit: Node
var vfx: Node
var shakes: Array[Vector2] = []
var strengths: Array[int] = []
var floor_y: float
var arena_x: float

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

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

func _initialize() -> void:
	var rolls: GDScript = load("res://SampleProject/Scripts/Combat/CombatRolls.gd")
	VFX = load("res://SampleProject/Scripts/Systems/VFXHooks.gd")
	SOUNDS = load("res://SampleProject/Scripts/Systems/SoundHooks.gd")
	rolls.calm()
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _finish_dialogue(sl.get_dialogue_manager())
	await create_timer(1.5).timeout
	hero = game.player
	combat = hero.combat
	vfx = root.get_node("GameManager/VFXHooks")
	vfx.shake_started.connect(func(strength: float, seconds: float) -> void: shakes.append(Vector2(strength, seconds)))
	root.get_node("EventBus").damage_dealt.connect(func(source: Node, _target: Node, _amount: int) -> void:
		if source == hero:
			strengths.append(VFX.hit_strength(source)))
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x
	bandit = load(BANDIT).instantiate()
	bandit.enemy_stats = load(BANDIT_STATS)
	bandit.position = game.map.to_local(Vector2(arena_x + 300.0, floor_y - 40.0))
	game.map.add_child(bandit)
	for i in 40: await physics_frame
	bandit.set_physics_process(false)
	bandit.Max_Health = 99999
	bandit.current_health = bandit.Max_Health

	_scale()
	await _real_hits()
	await _hit_taken()
	await _shake_off()
	_sounds()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()


## Скільки реальних мс триває завмирання, що почнеться впродовж [param wait_ms] (0 — не почалось).
func _hitstop_ms(wait_ms: int) -> int:
	var deadline := Time.get_ticks_msec() + wait_ms
	while Engine.time_scale >= 1.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if Engine.time_scale >= 1.0:
		return 0
	var t0 := Time.get_ticks_msec()
	while Engine.time_scale < 1.0:
		await process_frame
	return Time.get_ticks_msec() - t0


## Упритул до бандита, обличчям до нього.
func _hero_at_bandit() -> void:
	hero.global_position = Vector2(bandit.hurt_rect().position.x - 30.0, floor_y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	bandit.enemy_view.update_direction(-1)
	bandit._face_shapes(-1)
	await physics_frame


func _until_ready() -> void:
	for i in 180:
		if combat.state == combat.State.READY and combat.attack_cooldown <= 0.0:
			break
		await physics_frame
	await create_timer(0.3).timeout


## [1] Шкала в числах (VFXHooks.HIT_FEEL / HURT_FEEL).
func _scale() -> void:
	print("[1] Hitstop and shake scale with the blow: light < heavy < riposte < a boss hit (D581)")
	var hit: Array = VFX.HIT_FEEL
	var hurt: Array = VFX.HURT_FEEL
	ck(hit[0].hitstop < hit[2].hitstop and hit[2].hitstop < hit[3].hitstop and hit[3].hitstop < hurt[2].hitstop,
			"hitstop light %.3f < heavy %.3f < riposte %.3f < boss hit %.3f" % [hit[0].hitstop, hit[2].hitstop, hit[3].hitstop, hurt[2].hitstop])
	ck(hurt[0].hitstop < hurt[1].hitstop and hurt[1].hitstop < hurt[2].hitstop, "hits taken: normal < guard-breaking < boss")
	ck(hit[0].shake == Vector2.ZERO and hit[1].shake == Vector2.ZERO, "a light swing and a finisher do not shake the screen")
	ck(hit[2].shake.x > 0.0 and hit[3].shake.x > hit[2].shake.x, "the heavy shakes, the riposte harder (%.0f, %.0f px)" % [hit[2].shake.x, hit[3].shake.x])
	ck(hurt[0].shake.x > 0.0 and hurt[1].shake.x > hurt[0].shake.x and hurt[2].shake.x > hurt[1].shake.x,
			"every hit taken shakes, scaled (%.0f, %.0f, %.0f px)" % [hurt[0].shake.x, hurt[1].shake.x, hurt[2].shake.x])
	var boss := Node2D.new()
	boss.add_to_group(&"boss")
	ck(VFX.hurt_tier(boss) == 2 and VFX.hurt_tier(null) == 0, "a boss's blow is the top hurt tier")
	boss.free()


## [2] Справжні влучання героя по бандиту: легкий, важкий, рипост.
func _real_hits() -> void:
	print("[2] Real hits: a light swing does not shake; the heavy and the riposte do, harder; hitstop grows (D581)")
	var ms: Array[int] = []
	var shook: Array = []
	for kind in [&"light", &"heavy", &"riposte"]:
		await _hero_at_bandit()
		shakes.clear()
		strengths.clear()
		match kind:
			&"light": combat.perform_attack(1)
			&"heavy": combat.heavy_attack(1)
			&"riposte":
				combat.riposte_left = combat.RIPOSTE_WINDOW
				combat.perform_attack(1)
		ms.append(await _hitstop_ms(1500))
		shook.append(shakes.duplicate())
		ck(strengths.size() == 1, "%s: one hit lands (strengths %s)" % [kind, strengths])
		if strengths.size() == 1:
			ck(strengths[0] == {&"light": 0, &"heavy": 2, &"riposte": 3}[kind], "%s: hit strength %d" % [kind, strengths[0]])
		bandit.current_health = bandit.Max_Health
		await _until_ready()
		await create_timer(0.8).timeout  # бандит відходить від збою
	ck(shook[0].is_empty(), "the light swing: no shake (%s)" % [shook[0]])
	ck(shook[1].size() == 1 and shook[1][0] == VFX.HIT_FEEL[2].shake, "the heavy: one shake %s" % [shook[1]])
	ck(shook[2].size() == 1 and shook[2][0] == VFX.HIT_FEEL[3].shake, "the riposte: one stronger shake %s" % [shook[2]])
	ck(ms[0] >= 40 and ms[0] < ms[1] and ms[1] < ms[2], "hitstop measured: light %d < heavy %d < riposte %d ms" % ms)


## [3] Удар по героєві: тряска і білий спалах.
func _hit_taken() -> void:
	print("[3] A hit taken shakes the screen and flashes the hero white (D581)")
	await _hero_at_bandit()
	var material: ShaderMaterial = hero.get_node(^"Sprite2D").material
	shakes.clear()
	bandit.stagger_time = 0.25
	hero.take_damage(5, bandit)
	var flash: float = material.get_shader_parameter(&"flash")
	ck(flash > 0.9, "the hero's frames flash white (flash %.2f)" % flash)
	ck(shakes.size() == 1 and shakes[0] == VFX.HURT_FEEL[0].shake, "a normal hit taken shakes %s" % [shakes])
	await create_timer(VFX.HURT_FLASH_TIME + 0.2).timeout
	ck(is_zero_approx(material.get_shader_parameter(&"flash")), "the flash fades (%.2f)" % material.get_shader_parameter(&"flash"))
	while hero.is_invulnerable:  # невразливість після удару
		await physics_frame
	shakes.clear()
	bandit.stagger_time = 0.6
	hero.take_damage(5, bandit)
	ck(shakes.size() == 1 and shakes[0] == VFX.HURT_FEEL[1].shake, "a guard-breaking hit shakes harder %s" % [shakes])
	bandit.stagger_time = 0.25
	hero.current_health = hero.Max_Health
	await create_timer(1.2).timeout
	await _until_ready()


## [4] Screen Shake Off (D426): тряска не рухає камеру.
func _shake_off() -> void:
	print("[4] Settings → Screen Shake Off: the camera does not move (D426)")
	var settings: Dictionary = root.get_node("SaveSystem").settings_module.settings
	settings.screen_shake = false
	var camera: Camera2D = hero.get_viewport().get_camera_2d()
	await _hero_at_bandit()
	shakes.clear()
	combat.heavy_attack(1)
	var moved := false
	for i in 90:
		await process_frame
		if camera.offset != Vector2.ZERO:
			moved = true
	ck(shakes.size() == 1 and not moved, "the heavy asks for a shake (%d) but the camera stays (moved %s)" % [shakes.size(), moved])
	settings.screen_shake = true
	bandit.current_health = bandit.Max_Health
	await _until_ready()


## [5] Свій звук для кожного роду удару.
func _sounds() -> void:
	print("[5] Distinct sounds: light, finisher, heavy, riposte, block, parry (D581)")
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/sound_events.json")).events
	var names: Array = SOUNDS.HIT_SOUNDS.duplicate()
	names.append_array([&"block", &"parry"])
	var keys: Array = names.map(func(n: StringName) -> String: return String(n))
	ck(keys.all(func(k: String) -> bool: return events.has(k)), "every hit sound is in sound_events.json (%s)" % [keys])
	var shapes: Dictionary = {}
	for k in keys:
		shapes[[events[k].files, events[k].get("pitch", 1.0)]] = k
	ck(shapes.size() == keys.size(), "no two of them sound the same (files and pitch differ)")
