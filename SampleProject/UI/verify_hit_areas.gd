extends SceneTree

## Зони удару = те, що намальовано (B128). Сцени: у кожного типу ворога зона-ціль (Hurtbox) — межі кадрів idle і walk,
## хітбокс — межі кадрів удару від центру вперед (HitAreas), форми свої в кожній сцені, attack_range лише починає удар.
## Гра (DesertRoad): хітбокс кожної зброї героя — до краю шлейфа, що справді намальовано; герой влучає по ворогу, чиє
## намальоване тіло на краю шлейфа, і не влучає трохи далі; удар ворога так само.
##   godot --headless --path . --script res://SampleProject/UI/verify_hit_areas.gd

const HitAreas = preload("res://SampleProject/Scripts/Combat/HitAreas.gd")
const TOL := 3.0
## Пів ширини тіла героя (Player.tscn → CollisionShape2D, 24 px).
const HERO_HALF := 12.0
## Сцена → тип статів (Resources/Enemies/enemy_stats_<тип>.tres; "" — бос несе свої).
const KINDS := {
	"res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn": "melee",
	"res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn": "fast",
	"res://SampleProject/Scenes/Characters/Enemies/enemy_tank.tscn": "tank",
	"res://SampleProject/Scenes/Characters/Enemies/enemy_archer.tscn": "archer",
	"res://SampleProject/Scenes/Characters/Bosses/brass_collector.tscn": "",
	"res://SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn": "",
	"res://SampleProject/Scenes/Characters/Bosses/fire_djinn.tscn": "",
}

var fails: Array[String] = []
var game: Node
var hero: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _near(a: Rect2, b: Rect2) -> bool:
	return absf(a.position.x - b.position.x) <= TOL and absf(a.end.x - b.end.x) <= TOL \
			and absf(a.position.y - b.position.y) <= TOL and absf(a.end.y - b.end.y) <= TOL

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
	rolls.calm()
	await process_frame
	_scenes()

	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
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
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	await _hero_swings(sl)
	await _enemy_strikes()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()


## [1] Сцени: форми — з кадрів; нічого спільного між сценами й копіями; attack_range починає удар, що дістане.
func _scenes() -> void:
	print("[1] Each enemy kind: the hurtbox is its drawn body, the hitbox its drawn strike (B128)")
	for path: String in KINDS:
		var enemy: Node = load(path).instantiate()
		var twin: Node = load(path).instantiate()
		var sprite: Sprite2D = enemy.get_node("Sprite2D")
		var anim: AnimationPlayer = enemy.get_node("AnimationPlayer")
		var stats: Resource = enemy.enemy_stats if KINDS[path] == "" else load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % KINDS[path])
		var name := path.get_file().get_basename()
		var hurt := HitAreas.shape_rect(enemy.get_node("Hurtbox/CollisionShape2D"))
		var drawn_body := HitAreas.body_rect(sprite, anim)
		ck(_near(hurt, drawn_body), "%s: hurtbox %s = drawn body %s" % [name, hurt, drawn_body])
		for node_path in ["Hurtbox/CollisionShape2D", "hitbox/CollisionShape2D"]:
			var shape: Shape2D = enemy.get_node(node_path).shape
			ck(shape.resource_local_to_scene and shape != twin.get_node(node_path).shape, "%s: %s is its own, not shared" % [name, node_path])
		ck(enemy.get_node("Hurtbox").is_in_group(&"hurtbox") and enemy.get_node("Hurtbox").monitorable, "%s: the hurtbox can be hit" % name)
		enemy.free()
		twin.free()
		if KINDS[path] == "archer":
			continue  # стріляє стрілами, хітбокса не має
		enemy = load(path).instantiate()
		sprite = enemy.get_node("Sprite2D")
		anim = enemy.get_node("AnimationPlayer")
		var strike := HitAreas.strike_rect(sprite, anim, stats.attack_active_time)
		if anim.has_animation(&"charge_strike"):
			strike = strike.merge(HitAreas.frames_rect(sprite, HitAreas.anim_frames(anim, &"charge_strike", 0.0, INF)))  # ривок боса б'є тим самим хітбоксом
		var drawn_strike := Rect2(0.0, strike.position.y, strike.end.x, strike.size.y)
		var hit := HitAreas.shape_rect(enemy.get_node("hitbox/CollisionShape2D"))
		ck(_near(hit, drawn_strike), "%s: hitbox %s = drawn strike %s" % [name, hit, drawn_strike])
		var body_half: float = enemy.get_node("CollisionShape2D").shape.get_rect().end.x
		if KINDS[path] == "":
			ck(absf(enemy.melee_reach - hit.end.x) <= TOL, "%s: melee_reach %.0f = the hitbox's front %.0f" % [name, enemy.melee_reach, hit.end.x])
			var combo: Dictionary = enemy.moves.filter(func(m: Dictionary) -> bool: return m.kind == "combo")[0]
			ck(combo.max_range > body_half + HERO_HALF and combo.max_range <= hit.end.x + HERO_HALF,
					"%s: the combo starts at %.0f px, where its strike reaches the hero (%.0f)" % [name, combo.max_range, hit.end.x + HERO_HALF])
		else:
			ck(stats.attack_range > body_half + HERO_HALF and stats.attack_range <= hit.end.x + stats.lunge + HERO_HALF,
					"%s: attack_range %.0f starts a strike that reaches (body contact %.0f, reach %.0f)" % [name, stats.attack_range, body_half + HERO_HALF, hit.end.x + stats.lunge + HERO_HALF])
		enemy.free()


## Шлейф, що зараз на героєві: межі кадрів його анімації, як він стоїть у світі (обличчям праворуч).
func _trail_rect() -> Rect2:
	for child in hero.get_children():
		if child.has_method(&"play") and child.has_node(^"Sprite"):
			var sprite: AnimatedSprite2D = child.get_node(^"Sprite")
			var out := Rect2()
			for i in sprite.sprite_frames.get_frame_count(sprite.animation):
				var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, i)
				var used := Rect2(texture.get_image().get_used_rect())
				used.position += sprite.offset - (texture.get_size() / 2.0 if sprite.centered else Vector2.ZERO)
				out = used if i == 0 else out.merge(used)
			return Rect2(child.global_position + out.position * child.global_scale, out.size * child.global_scale)
	return Rect2()


func _hitbox_rect() -> Rect2:
	var shape: CollisionShape2D = hero.get_node("Hitbox/CollisionShape2D")
	var size: Vector2 = shape.shape.get_rect().size
	return Rect2(shape.global_position - size / 2.0, size)


## Нерухомий ворог [param path] (AI вимкнено) на підлозі героя, обличчям до героя.
func _stand(path: String, kind: String) -> Node:
	var enemy: Node = load(path).instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
	game.map.add_child(enemy)
	enemy.global_position = hero.global_position + Vector2(400, -40)
	for i in 30: await physics_frame
	enemy.set_physics_process(false)
	enemy.velocity = Vector2.ZERO
	return enemy


## Ворога ставимо так, щоб край його намальованого тіла був на [param x] (світ).
func _put_hurt_edge(enemy: Node, x: float) -> void:
	enemy.enemy_view.update_direction(-1)
	enemy._face_shapes(-1)
	enemy.global_position.x += x - enemy.hurt_rect().position.x
	await physics_frame


## [2] Удар героя кожною зброєю: хітбокс = намальований шлейф перед героєм; ворог на краю шлейфа отримує удар, трохи далі — ні.
func _hero_swings(sl: Node) -> void:
	print("[2] The hero's swing hits what its slash trail covers (B128)")
	var em: Node = sl.get_equipment_manager()
	var gm: Node = sl.get_game_manager()
	var items: Node = sl.get_item_database()
	var who: String = gm.get_active_character().character_id
	for slot in ["sword", "mace", "polearm", "dagger", "bow"]:
		em.unequip_item(who, slot)
	var target: Node = await _stand("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn", "melee")
	target.Max_Health = 99999
	target.current_health = target.Max_Health
	var hits: Array = []
	target.damage_token.connect(func(d: int) -> void: hits.append(d))
	for case in [["", ""], ["sword", "iron_sword"], ["mace", "iron_mace"], ["polearm", "iron_halberd"], ["dagger", "iron_dagger"]]:
		if case[0] != "":
			em.equip_item(who, case[0], case[1], items.get_item(case[1]))
			await process_frame  # D475 / D510: екіпірування одразу бере зброю в руку, перемикання немає
		var label: String = "bare hands" if case[0] == "" else case[1]
		await create_timer(1.2).timeout  # серія скінчилась, кулдаун минув — наступний удар перший
		hero.mover.last_direction = 1
		hero.velocity = Vector2.ZERO
		for inside in [true, false]:
			# Удар з землі крокує вперед на SWING_STEP px (D504) — край шлейфа там, куди герой ступить
			var reach: float = hero.global_position.x + hero.combat.SWING_STEP + hero.combat.hitbox_center.x + hero.get_node("Hitbox/CollisionShape2D").shape.size.x / 2.0
			await _put_hurt_edge(target, reach - 3.0 if inside else reach + 6.0)
			hits.clear()
			hero.combat.perform_attack(1)
			var trail := Rect2()
			for i in 30:
				await physics_frame
				trail = _trail_rect()
				if trail.size != Vector2.ZERO:
					break
			if inside:
				var box := _hitbox_rect()
				var near := maxf(trail.position.x, hero.global_position.x)  # частина шлейфа за спиною героя не б'є
				ck(trail.size != Vector2.ZERO and absf(box.position.x - near) <= TOL and absf(box.end.x - trail.end.x) <= TOL
						and absf(box.position.y - trail.position.y) <= TOL and absf(box.end.y - trail.end.y) <= TOL,
						"%s: hitbox %s = drawn trail %s in front of the hero" % [label, box, trail])
			await create_timer(0.5).timeout
			ck(hits.size() == (1 if inside else 0), "%s: an enemy whose drawn body is %s the trail's edge is %s (%s)" % [label, "3 px inside" if inside else "6 px past", "hit" if inside else "not hit", hits])
			await create_timer(0.8).timeout
		if case[0] != "":
			em.unequip_item(who, case[0])
	target.queue_free()


## [3] Удар ворога: герой на краю намальованого удару отримує його, трохи далі — ні (ривок шакала вимкнено: лише хітбокс).
func _enemy_strikes() -> void:
	print("[3] An enemy's strike reaches only as far as it is drawn (B128)")
	var hurt: Array = []
	hero.damage_token.connect(func(d: int) -> void: hurt.append(d))
	for case in [["default_enemy", "melee"], ["enemy_fast", "fast"], ["enemy_tank", "tank"]]:
		var enemy: Node = await _stand("res://SampleProject/Scenes/Characters/Enemies/%s.tscn" % case[0], case[1])
		enemy.lunge = 0.0
		for inside in [true, false]:
			var front: float = enemy._strike_x + enemy.hitbox_collision.shape.size.x / 2.0
			var hero_right: float = hero.body_rect().end.x
			var gap := -3.0 if inside else 6.0
			enemy.global_position.x = hero_right + front + gap  # герой ліворуч, ворог дивиться на нього
			enemy.enemy_logic.last_direction = -1
			hero.velocity = Vector2.ZERO
			await physics_frame
			hurt.clear()
			hero.set_invulnerable(false)
			enemy.enemy_logic.perform_attack()
			await create_timer(enemy.attack_windup + enemy.attack_active_time + 0.15).timeout
			ck(hurt.size() == (1 if inside else 0), "%s: a hero %s the drawn strike's edge is %s (%s)" % [case[1], "3 px inside" if inside else "6 px past", "hit" if inside else "not hit", hurt])
			await create_timer(1.0).timeout
		enemy.queue_free()
