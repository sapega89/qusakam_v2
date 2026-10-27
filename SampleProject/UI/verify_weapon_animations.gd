extends SceneTree

## BACKLOG 42 (design/hero_weapon_animation_plan.md): кадри героя для кожного типу зброї і палітра металу предмета.
## Для кожного типу (меч, кинджал, булава, алебарда, меч + кинджал) у бою герой грає кадри цього типу в стійці, бігу,
## серії, важкому ударі й блоці, окремий спрайт зброї схований; два предмети одного типу — різна палітра шейдера.
##   godot --headless --path . --script res://SampleProject/UI/verify_weapon_animations.gd

const KEY := ["#F8F8E4", "#C2C2C2", "#87878C"]
const WEAPON_FRAMES := "res://SampleProject/Sprites/Player/Weapons/"

var fails: Array[String] = []

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

func _press(action: StringName, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

## Чекає [param seconds] у фізичних кроках, а не в часі кадрів: удар і хітбокс ідуть у фізиці, а на зайнятій машині
## таймер кадрів випереджає фізику (B186).
func _physics_wait(seconds: float) -> void:
	for i in ceili(seconds * Engine.physics_ticks_per_second):
		await physics_frame

func _tap(action: StringName) -> void:
	_press(action)
	await physics_frame
	_press(action, false)

var game: Node
var hero: Node
var enemies: Array = []
var em: Node
var items: Node
var gm: Node
var who: String
var wv: Node
var anim: AnimationPlayer
var material: ShaderMaterial

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
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
	await create_timer(2.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
			node.set_physics_process(false)  # стоять і не б'ють; бій вмикає тест (CHASE)
			node.Max_Health = 999999  # важкий удар алебарди сягає ворога — живий ворог тримає бій
			node.current_health = node.Max_Health
	ck(enemies.size() >= 1, "an enemy on DesertRoad to start a fight (%d)" % enemies.size())
	em = sl.get_equipment_manager()
	items = sl.get_item_database()
	gm = sl.get_game_manager()
	who = gm.get_active_character().character_id
	wv = hero.get_node("WeaponMount")
	anim = hero.get_node("AnimationPlayer")
	material = hero.get_node("Sprite2D").material
	ck(material is ShaderMaterial and material.shader.resource_path.ends_with("weapon_palette.gdshader"),
			"the hero sprite carries the weapon palette shader")

	_frames_carry_the_key()
	_own_frames()
	var start_x: float = hero.global_position.x
	for case in [
		["sword", ["sword"], ["iron_sword"], 3],
		["dagger", ["dagger"], ["iron_dagger"], 3],
		["mace", ["mace"], ["iron_mace"], 3],
		["polearm", ["polearm"], ["iron_halberd"], 3],
		["dual_sword_dagger", ["sword", "dagger"], ["iron_sword", "iron_dagger"], 4],
	]:
		hero.global_position.x = start_x  # удари крокують уперед (D504) — інакше герой доходить до ворога й не біжить
		await _weapon_type(case[0], case[1], case[2], case[3])
	await _palettes()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

## Метал зброї в кожній анімації кожної бібліотеки — у ключі палітри (інакше шейдерові нічого перефарбовувати).
## По анімації, а не по кадру: у dagger/Attack1/1 кинджал схований за стегном, леза в кадрі немає.
func _frames_carry_the_key() -> void:
	print("[0] Every weapon animation draws its metal in the key colours (BACKLOG 42 palette swap)")
	var key: Dictionary = {}
	for c in KEY:
		key[Color(c).to_html(false)] = true
	for library in [&"sword", &"dagger", &"mace", &"polearm", &"dual_sword_dagger"]:
		var missing: Array[String] = []
		var lib: AnimationLibrary = anim.get_animation_library(library)
		for name in lib.get_animation_list():
			var a: Animation = lib.get_animation(name)
			var found := false
			for k in a.track_get_key_count(0):
				var texture: Texture2D = a.track_get_key_value(0, k)
				if _has_key(Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path)), key):
					found = true
					break
			if not found:
				missing.append(name)
		ck(missing.is_empty(), "%s: key metal in every animation (missing: %s)" % [library, missing])

## Кадри fe96e88a (remaining_work Art 3) стоять у своїх анімаціях, а не позичені з інших (Attack3, Attack1, sword/Hurt).
func _own_frames() -> void:
	print("[0b] dagger Heavy/Attack2 and dual Hurt play their own frames")
	for case in [
		[&"dagger", &"HeavyWindup", ["dagger/Heavy/1"]],
		[&"dagger", &"HeavyStrike", ["dagger/Heavy/2", "dagger/Heavy/3"]],
		[&"dagger", &"Attack2", ["dagger/Attack2/1", "dagger/Attack2/2", "dagger/Attack2/3", "dagger/CombatIdle/1"]],
		[&"dual_sword_dagger", &"Hurt", ["dual/Hurt/1"]],
	]:
		var a: Animation = anim.get_animation_library(case[0]).get_animation(case[1])
		var got: Array[String] = []
		for k in a.track_get_key_count(0):
			var texture: Texture2D = a.track_get_key_value(0, k)
			got.append(texture.resource_path.trim_prefix(WEAPON_FRAMES).trim_suffix(".png"))
		ck(got == Array(case[2], TYPE_STRING, "", null), "%s/%s frames %s" % [case[0], case[1], got])

func _has_key(image: Image, key: Dictionary) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0 and key.has(c.to_html(false)):
				return true
	return false

func _equip(slots: Array, ids: Array) -> void:
	for slot in ["sword", "dagger", "mace", "polearm", "shield"]:
		em.unequip_item(who, slot)
	for i in slots.size():
		em.equip_item(who, slots[i], ids[i], items.get_item(ids[i]))
	em.equip_item(who, slots[0], ids[0], items.get_item(ids[0]))  # перша — в руці (D475: в руці остання вдягнена)
	await process_frame

func _fight(on: bool) -> void:
	for enemy in enemies:  # удар алебарди сягає й інших — вони теж кидаються в погоню
		enemy.enemy_logic.current_state = 0
	enemies[0].enemy_logic.current_state = 1 if on else 0  # CHASE — бій (D268)
	if on:
		await create_timer(0.4).timeout
	else:
		await create_timer(hero.combat.COMBAT_LINGER + 0.4).timeout

func _weapon_type(library: String, slots: Array, ids: Array, swings: int) -> void:
	print("[%s] %s in combat: idle, run, the %d-swing combo, heavy, block from its own frames" % [library, " + ".join(ids), swings])
	await _equip(slots, ids)
	await create_timer(0.5).timeout
	ck(wv.body_library() == &"" and not material.get_shader_parameter(&"active"),
			"out of combat: no weapon frames, palette off (%s)" % wv.body_library())
	await _fight(true)
	var sprite: Sprite2D = hero.get_node("Sprite2D")
	# Зсув клітинки 96 — (0, −16); ключі анімації ще садять ноги на підлогу до 6 рядків (verify_hero_feet, алебарда −12)
	ck(anim.current_animation == StringName(library + "/Idle") and not wv.pivot.visible and not wv.off_pivot.visible
			and sprite.offset.x == 0.0 and absf(sprite.offset.y + 16.0) <= 6.0 and material.get_shader_parameter(&"active"),
			"combat idle: %s, overlay hidden, 96×96 offset, palette on (overlay %s / %s)" % [anim.current_animation, wv.pivot.visible, wv.off_pivot.visible])

	Input.action_press(&"move_right")
	await create_timer(0.35).timeout
	var run_anim: StringName = anim.current_animation
	var run_overlay: bool = wv.pivot.visible
	Input.action_release(&"move_right")
	ck(run_anim == StringName(library + "/Run") and not run_overlay, "run: %s, overlay hidden %s" % [run_anim, not run_overlay])
	await create_timer(0.4).timeout

	var played: Array = []
	var log_anim := func(name: StringName) -> void: played.append(name)
	anim.animation_started.connect(log_anim)
	var hitbox: Area2D = hero.get_node("Hitbox")
	var strikes: Array = []
	for i in swings:
		await _tap(&"attack")
		await _physics_wait(0.06)  # кадр удару (0.05 с від початку) — хітбокс увімкнений
		var swing: Animation = anim.get_animation(anim.current_animation)
		strikes.append(hitbox.monitoring and not wv.pivot.visible and not wv.off_pivot.visible
				and sprite.texture == swing.track_get_key_value(0, 1))
		await _physics_wait(0.25)  # удар (0.3 с) скінчився — наступне натискання не в черзі
	await create_timer(1.0).timeout
	var expected: Array = []
	for i in swings:
		expected.append(StringName("%s/Attack%d" % [library, i + 1]))
	ck(expected.all(func(a: StringName) -> bool: return played.has(a)), "the combo plays %s (%s)" % [expected, played])
	ck(strikes.size() == swings and strikes.all(func(s: bool) -> bool: return s),
			"each strike frame shows with the hitbox on and no overlay (%s)" % [strikes])
	for i in swings:
		var a: Animation = anim.get_animation(expected[i])
		ck(is_equal_approx(a.length, anim.get_animation(&"Attack").length)
				and is_equal_approx(a.track_get_key_time(0, 1), anim.get_animation(&"Attack").track_get_key_time(0, 1)),
				"%s: %.2f s, strike at %.2f s — the base swing's timing" % [expected[i], a.length, a.track_get_key_time(0, 1)])
	played.clear()
	await _tap(&"heavy_attack")
	await create_timer(0.6).timeout
	ck(played.has(StringName(library + "/HeavyWindup")) and played.has(StringName(library + "/HeavyStrike"))
			and is_equal_approx(anim.get_animation(StringName(library + "/HeavyWindup")).length, hero.combat.heavy_windup),
			"heavy: wind-up then strike from the %s frames (%s)" % [library, played])
	await create_timer(1.3).timeout
	played.clear()
	_press(&"block")
	await create_timer(0.3).timeout  # довше за саму анімацію Block (0.1 с): кадр блоку лишається, накладки немає
	ck(played.has(StringName(library + "/Block")) and not wv.pivot.visible and not wv.off_pivot.visible
			and material.get_shader_parameter(&"active"), "block: %s, overlay hidden, palette on" % [played])
	_press(&"block", false)
	anim.animation_started.disconnect(log_anim)
	await _fight(false)
	ck(not String(anim.current_animation).begins_with(library + "/") and sprite.offset == Vector2.ZERO
			and not material.get_shader_parameter(&"active"),
			"the fight is over: base frames, offset back, palette off (%s)" % anim.current_animation)

## Палітра: предмети одного типу — однакові кадри, різний метал (items.json → palette).
func _palettes() -> void:
	print("[palette] Copper, iron, silver and crystal swords share the sword frames, each with its own metal")
	var seen: Dictionary = {}
	for id in ["iron_sword", "copper_sword", "silver_sword", "crystal_sword"]:
		await _equip(["sword"], [id])
		var colours: Array = [material.get_shader_parameter(&"to_light"), material.get_shader_parameter(&"to_mid"),
				material.get_shader_parameter(&"to_dark")]
		seen[id] = colours
		ck(wv.palette == items.get_item(id).palette, "%s: palette %s" % [id, wv.palette])
	ck(seen.iron_sword == KEY.map(func(c: String) -> Color: return Color(c)), "iron is the key itself (%s)" % [seen.iron_sword])
	ck(seen.iron_sword != seen.copper_sword and seen.copper_sword != seen.silver_sword and seen.silver_sword != seen.crystal_sword
			and seen.iron_sword != seen.crystal_sword, "four swords, four different palettes")
	await _equip(["sword"], ["crystal_sword"])
	ck(material.get_shader_parameter(&"shimmer") > 0.0 and material.get_shader_parameter(&"glow") > 0.0,
			"the crystal sword shimmers and glows")
	await _equip(["sword"], ["copper_sword"])
	ck(is_zero_approx(material.get_shader_parameter(&"shimmer")) and is_zero_approx(material.get_shader_parameter(&"glow")),
			"the copper sword does not")
	await _fight(true)
	ck(anim.current_animation == &"sword/Idle" and material.get_shader_parameter(&"active"),
			"copper in a fight: the same sword frames, recoloured (%s)" % anim.current_animation)
	await _fight(false)
