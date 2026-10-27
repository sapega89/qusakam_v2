extends SceneTree

## Фільм бойових ефектів для нотаток Sapega (BACKLOG 30 / MASTER_PLAN A9; D273 «вже краще, але є над чим працювати»).
## Один запуск — один фільм з мітками: на рівній ділянці DesertRoad (світло дня, кімнатні вороги прибрані) герой
## показує кожен ефект проти манекена (ворог, ШІ стоїть, HP і стійкість безмежні) чи ворога, що б'є сам. Дії героя —
## справжні прив'язки InputMap (клавіша / кнопка миші): attack, heavy_attack, block, jump, skill_slot_1, assist.
## Герою шкода не страшна (Max_Health 99999, HP відновлюється). HUD схований; ефекти на CanvasLayer (червоні краї
## HurtVignette) лишаються. Як film_rooms.gd — Movie Maker, вікно:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##     --write-movie <тека>/fx.avi --fixed-fps 30 --script res://SampleProject/UI/film_fx.gd -- out=<тека>
## Файли: <тека>/fx.avi, <тека>/fx.marks.json (кліп: id, кадри відео, прямокутник героя й цілі на екрані).
## Пакунок: Scripts/Tools/fx_pack.py.

const ENEMIES := "res://SampleProject/Scenes/Characters/Enemies/"
const STATS := "res://SampleProject/Resources/Enemies/enemy_stats_%s.tres"
const SCENE_OF := {"melee": "default_enemy.tscn"}
const BOSSES := "res://SampleProject/Scenes/Characters/Bosses/%s.tscn"
const OATH_ACTIVES := ["radiant_smite", "skyfall_blessing", "judgement_of_the_sky", "searing_hex", "withering_grasp",
		"eclipse_cleave", "balanced_strike", "dervish_whirl", "second_wind"]
const BASE_SKILLS := ["fire_strike", "electric_strike", "healing_palm"]
## Удар ворога кожної родини шлейфів EnemyStrikeFX.WEAPONS (вид → що видно).
const ENEMY_KINDS := ["melee", "bandit_brute", "armoured_scorpion", "fast", "jackal_cursed", "vulture", "archer"]
## Відступ кадру навколо героя й цілі, px світу (зверху більше: дуги й стовпи йдуть угору).
const PAD := Rect2(-70.0, -110.0, 140.0, 140.0)
## Манекен — за стільки px праворуч від героя.
const DUMMY_DX := 36.0
## Де новий ворог стає на підлогу, перш ніж перейти до героя, px праворуч.
const SETTLE_DX := 1600.0
## Предмет для категорії зброї, якої вимагає навичка (skills.json → required_weapons).
const WEAPON_OF := {"sword": "iron_sword", "dagger": "iron_dagger", "polearm": "iron_halberd", "mace": "iron_mace"}

var game: Node
var hero: CharacterBody2D
var sl: Node
var dm: Node
var sm: Node
var em: Node
var items: Node
var who := ""
var out_dir := ""
var floor_y := 0.0
var arena_x := 0.0
var dummy: Node
var clips: Array[Dictionary] = []
var clip: Dictionary = {}
var skipped: Array[String] = []
var started_ms := 0


func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — кадр щоразу той самий
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: без підказок «?»
	await process_frame
	set_meta("start_new_game", true)
	sl = root.get_node("ServiceLocator")
	dm = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	sm = sl.get_skill_manager()
	em = sl.get_equipment_manager()
	items = sl.get_item_database()
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _drain()
	await create_timer(1.5).timeout
	hero = game.player
	who = sl.get_game_manager().get_active_character().character_id
	var spawner_script: Script = load("res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd")
	for node in game.map.get_children():
		if node.get_script() == spawner_script and node.trigger_area:
			node.trigger_area.monitoring = false
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x
	_hide_ui(root)
	# Передній план кімнати (паралакс-валуни й пальми FrontDark) на цій ділянці закриває героя — лише у фільмі.
	(game.map.get_node(^"FrontDark") as CanvasItem).visible = false
	RenderingServer.frame_pre_draw.connect(_sample)

	await _level_up()
	await _landing()
	await _melee()
	await _bow()
	await _skills()
	await _guard()
	await _shield_enemy()
	await _enemy_strikes()
	await _bosses()
	await _companions()
	await _death()

	RenderingServer.frame_pre_draw.disconnect(_sample)
	var view: Vector2 = root.get_viewport().get_visible_rect().size
	var data := {"movie_fps": 30, "view": [view.x, view.y], "zoom": root.get_viewport().get_canvas_transform().get_scale().x,
			"clips": clips, "skipped": skipped, "run_s": (Time.get_ticks_msec() - started_ms) / 1000.0}
	var f := FileAccess.open(out_dir.path_join("fx.marks.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("FILM fx: %d clips, %d skipped -> %s" % [clips.size(), skipped.size(), out_dir])
	quit()


# --- кліпи ---------------------------------------------------------------------------------------------------------

func _level_up() -> void:
	await _begin("level_up", "Level-up flash and golden particles (Player._spawn_level_up_vfx)", [], 0.2)
	var xp: Node = sl.get_xp_manager()
	xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	await create_timer(1.8).timeout
	_end()


func _landing() -> void:
	await _begin("landing_dust", "Landing dust after a jump (VFXHooks._on_player_landed, LandingDust.tscn)", [], 0.2)
	_press(&"jump")
	for i in 18: await physics_frame
	_press(&"jump", false)
	await create_timer(1.4).timeout
	_end()


## Удари по манекену: серія кожною зброєю, важкий удар; шлейф (Smear/*) і розтин (Hit/cut) на кожному влучанні.
func _melee() -> void:
	dummy = await _spawn("melee", DUMMY_DX)
	var weapons := [
		["punch_combo", "Bare-hand combo: punch streaks (Smear/punch_1-3) and the hit cut (Hit/cut_1-4)", []],
		["sword_combo", "Sword combo: swing crescents (Smear/arc_1-3), the finisher bigger", [["sword", "iron_sword"]]],
		["mace_combo", "Mace combo: swing crescents (Smear/arc_1-3)", [["mace", "iron_mace"]]],
		["dagger_combo", "Dagger combo: thrust streaks (Smear/thrust_1-3)", [["dagger", "iron_dagger"]]],
		["halberd_combo", "Halberd combo: thrusts and a sweep (Smear/thrust, arc)", [["polearm", "iron_halberd"]]],
		["dual_combo", "Sword + dagger dual-wield: four fast swings", [["dagger", "iron_dagger"], ["sword", "iron_sword"]]],
	]
	for w: Array in weapons:
		_unequip_weapons()
		for pair: Array in w[2]:
			em.equip_item(who, pair[0], pair[1], items.get_item(pair[1]))
		await create_timer(0.3).timeout
		await _ready_hero(dummy, DUMMY_DX)
		await _begin(w[0], w[1], [dummy])
		var swings: int = hero.combat.combo_length()
		for i in swings:
			await _tap(&"attack")
			await create_timer(0.3).timeout
		await create_timer(0.6).timeout
		_end()
	_unequip_weapons()
	em.equip_item(who, "sword", "iron_sword", items.get_item("iron_sword"))
	await create_timer(0.3).timeout
	await _ready_hero(dummy, DUMMY_DX)
	await _begin("heavy_attack", "Sword heavy attack: the big crescent, heavy hit feel", [dummy])
	await _tap(&"heavy_attack")
	await create_timer(1.4).timeout
	_end()


func _bow() -> void:
	_unequip_weapons()
	em.equip_item(who, "bow", "short_bow", items.get_item("short_bow"))
	await create_timer(0.3).timeout
	var far: Node = dummy
	await _ready_hero(far, 200.0)
	await _begin("bow_quick_shot", "Bow quick shots: the arrow (Projectiles/arrow.png) and its hit", [far])
	for i in 2:
		await _tap(&"attack")
		await create_timer(0.5).timeout
	await create_timer(0.4).timeout
	_end()
	await _ready_hero(far, 200.0)
	await _begin("bow_charged_shot", "Bow held: draw, charged glow, the piercing charged arrow (arrow_charged.png)", [far])
	_press(&"attack")
	await create_timer(1.1).timeout
	_press(&"attack", false)
	await create_timer(0.9).timeout
	_end()
	_unequip_weapons()
	em.equip_item(who, "sword", "iron_sword", items.get_item("iron_sword"))
	await create_timer(0.3).timeout


## Навички зі слота 1 справжньою клавішею: замах (charge), реліз (release); D271 і дев'ять навичок клятв (D279).
func _skills() -> void:
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 20:
		xp.add_xp(1000)
	await create_timer(2.0).timeout  # спалахи рівнів позаду
	var state: Dictionary = sl.get_game_manager().player_state
	var notes := {
		"fire_strike": "Fire Strike: wind-up, then the fire crescent (Skills/fire_arc.png)",
		"electric_strike": "Electric Strike: the bolt in the wind-up and from the sky at the release (Skills/bolt.png)",
		"healing_palm": "Healing Palm: the healing ring (Skills/heal_aura.png)",
	}
	for id: String in BASE_SKILLS + OATH_ACTIVES:
		var definition: Object = sm.skill_database.get_skill(id)
		if definition.oath != "":
			state["oath"] = definition.oath
		if not (id in state.get("unlocked_skills", [])):
			state["unlocked_skills"] = state.get("unlocked_skills", []) + [id]
		# Навичка з вимогою зброї (fire_strike — меч чи кинджал, electric_strike — алебарда чи булава): перша з них у руці.
		var need: Array = definition.required_weapons
		if not need.is_empty() and not (em.get_weapon_in_hand() in need):
			_unequip_weapons()
			var item_id: String = WEAPON_OF[need[0]]
			em.equip_item(who, need[0], item_id, items.get_item(item_id))
			await create_timer(0.3).timeout
		var verdict: int = sm.equip_skill(id, 0)
		if verdict != 0:
			skipped.append("%s: equip_skill refused (%d)" % [id, verdict])
			continue
		sm.clear_cooldowns()
		sm.restore_sp(999)
		await _ready_hero(dummy, 40.0)
		hero.current_health = hero.Max_Health - 70  # лікувальним є що лікувати
		var note: String = notes.get(id, "%s (oath %s): own charge and release frames (Skills/%s/)" % [id, definition.oath, id])
		await _begin("skill_" + id, note, [dummy])
		var failed: Array = []
		var on_fail := func(skill: String, reason: int) -> void: failed.append("%s refused (%d)" % [skill, reason])
		root.get_node("EventBus").skill_failed.connect(on_fail)
		await _tap(&"skill_slot_1")
		await create_timer(definition.cast_windup + definition.cast_release + 0.9).timeout
		_end()
		root.get_node("EventBus").skill_failed.disconnect(on_fail)
		skipped.append_array(failed)
	hero.current_health = hero.Max_Health


## Блок і парирування (D264): іскри між героєм і ворогом.
func _guard() -> void:
	var bandit := await _spawn("melee", 40.0)
	for parry: bool in [true, false]:
		await _ready_hero(bandit, 40.0)
		await _begin("parry_spark" if parry else "block_spark",
				"Parry: the hero blocks just as the bandit strikes - parry sparks (ParrySpark.tscn)" if parry
				else "Block: the hero holds block through the strike - smaller block sparks", [bandit])
		_press(&"block")
		await create_timer(0.15 if parry else hero.combat.PARRY_WINDOW + 0.2).timeout
		bandit.start_attack(-1)
		hero.take_damage(5, bandit)
		await create_timer(0.3).timeout
		bandit.end_attack()
		await create_timer(0.5).timeout
		_press(&"block", false)
		await create_timer(0.4).timeout
		_end()
		hero.current_health = hero.Max_Health
	bandit.queue_free()
	await physics_frame


## Удари героя в щит щитоносця: іскри щита; важкий удар його ламає (EventBus.enemy_shield_blocked / broken).
func _shield_enemy() -> void:
	var shield := await _spawn("shield", 40.0)
	await _ready_hero(shield, 40.0)
	await _begin("enemy_shield_sparks", "Hits on a shield bandit's shield: shield sparks, a heavy hit breaks it", [shield])
	for i in 2:
		await _tap(&"attack")
		await create_timer(0.35).timeout
	await create_timer(0.4).timeout
	await _tap(&"heavy_attack")
	await create_timer(1.2).timeout
	_end()
	shield.queue_free()
	await physics_frame


## Удар ворога кожної родини (EnemyStrikeFX, A17), що влучає в героя: розтин по героєві, червоні краї, тряска.
func _enemy_strikes() -> void:
	dummy.global_position.x += 2000.0  # манекен не плутається під ногами
	for kind: String in ENEMY_KINDS:
		var dx: float = 220.0 if kind == "archer" else 48.0
		var enemy := await _spawn(kind, dx)
		await _ready_hero(enemy, dx)
		await _begin("enemy_" + kind, "Enemy strike (%s): its smear from EnemyStrikeFX.WEAPONS, then the hit on the hero (red cut, vignette)" % kind, [enemy])
		await create_timer(0.2).timeout
		enemy.start_attack(-1)
		await create_timer(0.12).timeout
		if kind != "archer":
			hero.take_damage(5, enemy)
		await create_timer(0.3).timeout
		enemy.end_attack()
		await create_timer(1.0).timeout
		_end()
		hero.current_health = hero.Max_Health
		enemy.queue_free()
		await physics_frame
	dummy.global_position.x -= 2000.0


## Боси (D301, D302): куля й стовп джина, хвиля Колекціонера. Ходи — з їхніх moves, як у бою.
func _bosses() -> void:
	dummy.global_position.x += 2000.0
	var shows := [["fire_djinn", "fireball", "Fire djinn: the fireball (Bosses/fireball.png, boss_fireball.tscn)"],
			["fire_djinn", "pillar", "Fire djinn: the floor mark, then the fire pillar (Bosses/mark.png, pillar.png)"],
			["brass_collector", "slam", "Brass Collector: the slam, its shockwave and dust (Bosses/shockwave.png)"]]
	for show: Array in shows:
		var boss: Node = load(BOSSES % show[0]).instantiate()
		var dx: float = 90.0 if show[1] == "slam" else 220.0
		boss = await _place(boss, dx)
		boss.enemy_logic.player = hero
		await _ready_hero(boss, dx)
		var move: Dictionary = boss.moves.filter(func(m: Dictionary) -> bool: return m.kind == show[1])[0]
		boss.enemy_logic.last_move = move
		boss.enemy_logic.last_direction = -1
		await _begin("boss_%s_%s" % [show[0], show[1]], show[2], [boss])
		await create_timer(0.2).timeout
		boss.strike(move)
		match show[1]:
			"fireball": boss.enemy_logic._fireballs(move)
			"pillar": boss.enemy_logic._pillars(move)
			"slam": boss.enemy_logic._slam(move)
		await create_timer(2.2).timeout
		_end()
		hero.current_health = hero.Max_Health
		boss.queue_free()
		await physics_frame
	dummy.global_position.x -= 2000.0


## Компаньйони (D464, D515) на кнопку assist: їхні ефекти (Scenes/FX/Companions/*).
func _companions() -> void:
	var cm: Node = sl.get_companion_manager()
	for f: String in ["lab_companion_01_complete", "lab_companion_02_complete", "lab_companion_03_complete"]:
		game.set_quest_flag(f, true)
		cm.announce_unlock(f)
	var others: Array[Node] = [dummy, await _spawn("melee", 120.0), await _spawn("melee", 200.0)]
	var notes := {"alisia": "Alisia: green draw glow, the arrow streak, hit sparks (Companions/charge_glow, arrow_streak, hit_spark)",
			"astrit": "Astrit: drops in - landing dust, charge glow, shield slam, stun stars",
			"urizen": "Urizen: gold glow, the coin chaining to three enemies - gold bursts",
			"guard": "City Gates guard: runs in, the thrust ends with a wind arc, knockback puff"}
	for id: String in ["alisia", "astrit", "urizen", "guard"]:
		if id == "guard":
			cm.offer_guard(true)
		else:
			for p: String in cm.get_party():
				cm.toggle_party(p)
			cm.toggle_party(id)
		cm._process(cm.COOLDOWN)
		for e: Node in others:
			e.current_health = e.Max_Health
			e.enemy_logic.stun_left = 0.0
		await _ready_hero(dummy, DUMMY_DX + 30.0)
		await _begin("companion_" + id, notes[id], others, 0.6)
		_press(&"assist")
		await physics_frame
		_press(&"assist", false)
		await create_timer(3.6).timeout
		_end()
	cm.offer_guard(false)
	for e: Node in others:
		if e != dummy:
			e.queue_free()
	await physics_frame


## Смерть ворога: розсип часток (DeathParticles.tscn) і числа шкоди.
func _death() -> void:
	await _ready_hero(dummy, DUMMY_DX)
	dummy.current_health = 1
	await _begin("enemy_death", "Enemy death: the last hit, damage number, death particles (DeathParticles.tscn)", [dummy])
	await _tap(&"attack")
	await create_timer(1.6).timeout
	_end()


# --- помічники -----------------------------------------------------------------------------------------------------

## Ворог виду [param kind] за [param dx] px праворуч від героя; ШІ стоїть, HP і стійкість безмежні.
func _spawn(kind: String, dx: float) -> Node:
	var enemy: Node = load(ENEMIES + SCENE_OF.get(kind, "enemy_%s.tscn" % kind)).instantiate()
	enemy.enemy_stats = load(STATS % kind)
	return await _place(enemy, dx)


func _place(enemy: Node, dx: float) -> Node:
	# Стає на підлогу далеко від героя: ШІ ходить і через фізику тіла (process_physics), тож поруч із героєм за ці
	# 30 тактів устиг би вдарити (джин кидав кулю). Потім ШІ стоїть, а ворог переходить на своє місце.
	enemy.position = game.map.to_local(Vector2(arena_x + SETTLE_DX, floor_y - 40.0))
	game.map.add_child(enemy)
	for i in 30: await physics_frame
	enemy.set_physics_process(false)
	enemy.enemy_logic.set_physics_process(false)
	enemy.enemy_logic.set_process(false)
	# Та сама висота над підлогою, що й там, де він став (підлога під героєм може лежати інакше).
	var above: float = _floor_under(enemy.global_position) - enemy.global_position.y
	enemy.global_position = Vector2(arena_x + dx, _floor_under(Vector2(arena_x + dx, floor_y - 60.0)) - above)
	enemy.player = hero
	enemy.Max_Health = 99999
	enemy.current_health = enemy.Max_Health
	enemy.poise_max = 99
	enemy.poise = 99
	return enemy


## Y підлоги (колізія світу) під точкою [param at].
func _floor_under(at: Vector2) -> float:
	var q := PhysicsRayQueryParameters2D.create(at, at + Vector2(0, 600), hero.collision_mask, [hero.get_rid()])
	var hit: Dictionary = hero.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		push_error("film_fx: no floor under %s" % at)
		return at.y
	return (hit.position as Vector2).y


## Герой стоїть за [param dx] px лівіше від [param target], дивиться на нього, готовий (без завмирання й невразливості).
func _ready_hero(target: Node, dx: float) -> void:
	for i in 600:
		if not hero.is_invulnerable and Engine.time_scale >= 1.0 and hero.combat.state == hero.combat.State.READY:
			break
		await physics_frame
	await _drain()
	# Рівень і спорядження перераховують Max_Health (Player.refresh_max_health) — тож щоразу знову.
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position = Vector2(target.global_position.x - dx, floor_y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	target.current_health = maxi(target.current_health, 2)
	for i in 8: await physics_frame


## Почати кліп: кадри відео пишуться в мітку, прямокутник — герой і [param targets] на екрані (+ PAD).
func _begin(id: String, note: String, targets: Array, wide: float = 0.0) -> void:
	await process_frame
	clip = {"id": id, "note": note, "targets": targets, "wide": wide, "first": Engine.get_frames_drawn(),
			"last": Engine.get_frames_drawn(), "rect": null}
	print("CLIP %s" % id)


func _end() -> void:
	var done := clip.duplicate()
	done.erase("targets")
	clips.append(done)
	clip = {}


## Кадр перед малюванням: розширити прямокутник кліпу героєм і цілями на екрані.
func _sample() -> void:
	if clip.is_empty():
		return
	clip.last = Engine.get_frames_drawn()
	var canvas: Transform2D = root.get_viewport().get_canvas_transform()
	var bodies: Array = [hero]
	for t: Variant in clip.targets:
		if is_instance_valid(t):
			bodies.append(t)
	var rect: Variant = clip.rect
	for body: Node in bodies:
		var r := _body_rect(body as Node2D)
		r = Rect2(r.position + PAD.position, r.size + PAD.size)
		r = r.grow_individual(r.size.x * clip.wide, r.size.y * clip.wide * 0.5, r.size.x * clip.wide, 0.0)
		var on_screen := Rect2(canvas * r.position, (canvas * r.end) - (canvas * r.position))
		rect = on_screen if rect == null else (rect as Rect2).merge(on_screen)
	clip.rect = rect
	var view: Vector2 = root.get_viewport().get_visible_rect().size
	var cut: Rect2 = (rect as Rect2).intersection(Rect2(Vector2.ZERO, view))
	clip["rect_px"] = [roundi(cut.position.x), roundi(cut.position.y), roundi(cut.size.x), roundi(cut.size.y)]


## Колізія тіла у світі.
func _body_rect(body: Node2D) -> Rect2:
	for child: Node in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			var shape_node: CollisionShape2D = child
			var r: Rect2 = shape_node.shape.get_rect()
			return Rect2(shape_node.global_transform * r.position, r.size * shape_node.global_transform.get_scale().abs())
	return Rect2(body.global_position - Vector2(20, 40), Vector2(40, 40))


func _unequip_weapons() -> void:
	for slot: String in em.WEAPON_SLOTS + ["shield"]:
		em.unequip_item(who, slot)


## Справжня прив'язка дії: перша клавіша чи кнопка миші з InputMap, натиснута чи відпущена.
func _press(action: StringName, pressed: bool = true) -> void:
	for bound: InputEvent in InputMap.action_get_events(action):
		if bound is InputEventKey or bound is InputEventMouseButton:
			var ev: InputEvent = bound.duplicate()
			ev.device = 0
			ev.pressed = pressed
			if ev is InputEventMouseButton:
				ev.position = Vector2(root.size) / 2.0
				ev.global_position = ev.position
			Input.parse_input_event(ev)
			return
	push_error("film_fx: %s has no key or mouse binding" % action)


func _tap(action: StringName) -> void:
	_press(action)
	await physics_frame
	await physics_frame
	_press(action, false)


func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 5: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame


## HUD і решта UI: кожен CanvasLayer, крім ефектів VFXHooks (червоні краї удару).
func _hide_ui(node: Node) -> void:
	for child: Node in node.get_children():
		if child == game.map or child.name == &"VFXHooks":
			continue
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		else:
			_hide_ui(child)
