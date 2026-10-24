extends SceneTree

## Поза збою ворога (D264, remaining_work Art 4): кожен ворог і бос зі stagger.png грає її весь збій — Sprite2D
## бере stagger.png (2 клітинки), кадр 0 «відкинутий», потім 1 «приголомшений»; по збою — знову свій sheet і
## звичайна анімація. Помер у збої — смерть із кадрів sheet. Шакал зграї (D692/D693) stagger.png не має: його поза
## збою — кадр hurt (12) власного листа на весь збій.
##   godot --headless --path . --script res://SampleProject/UI/verify_enemy_stagger.gd

## Ім'я арту → [сцена, тип статів (Resources/Enemies/enemy_stats_<тип>.tres, як EnemySpawnPoint) або "" — бос несе свої].
const ENEMIES := {
	"bandit": ["res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn", "melee"],
	"scorpion": ["res://SampleProject/Scenes/Characters/Enemies/enemy_tank.tscn", "tank"],
	"brass_collector": ["res://SampleProject/Scenes/Characters/Bosses/brass_collector.tscn", ""],
	"fire_djinn": ["res://SampleProject/Scenes/Characters/Bosses/fire_djinn.tscn", ""],
}
const JACKAL := ["res://SampleProject/Scenes/Characters/Enemies/enemy_fast.tscn", "fast"]
const JACKAL_HURT := 12
const ARCHER := ["res://SampleProject/Scenes/Characters/Enemies/enemy_archer.tscn", "archer"]
const NORMAL := ["idle", "walk", "attack"]
const PARRY_STAGGER := 1.0

var fails: Array[String] = []
var game: Node
var hero: Node

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _finish_dialogue(dm: Node) -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()  # D254
		dm.current_dialogue_player.accept()
		await process_frame

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
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
	hero.global_position.x += 700.0
	await create_timer(0.5).timeout

	for who in ENEMIES:
		await _stagger(who, ENEMIES[who])
	await _jackal_hurt_frame()
	await _dies_in_stagger()
	await _archer_keeps_tint()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()

func _spawn(scene: Array) -> CharacterBody2D:
	var enemy: CharacterBody2D = load(scene[0]).instantiate()
	if scene[1] != "":
		enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % scene[1])
	game.map.add_child(enemy)
	enemy.global_position = hero.global_position + Vector2(260, -40)
	enemy.Max_Health = 999999
	enemy.current_health = enemy.Max_Health
	return enemy

func _stagger(who: String, scene: Array) -> void:
	print("[%s] stagger pose for the whole stagger, then its sheet again" % who)
	var enemy := _spawn(scene)
	await create_timer(0.6).timeout
	var sprite: Sprite2D = enemy.get_node(^"Sprite2D")
	var anim: AnimationPlayer = enemy.get_node(^"AnimationPlayer")
	var sheet: Texture2D = sprite.texture
	var cells := Vector2i(sprite.hframes, sprite.vframes)
	enemy.stagger(PARRY_STAGGER, hero.global_position.x)
	await physics_frame  # сигнал іде до _physics_process ворогів — тінь ставить наступний
	await physics_frame
	ck(sprite.texture.resource_path.ends_with(who + "/stagger.png") and sprite.hframes == 2 and sprite.vframes == 1,
			"%s: staggered shows stagger.png (%s, %dx%d)" % [who, sprite.texture.resource_path.get_file(), sprite.hframes, sprite.vframes])
	ck(anim.current_animation == "stagger" and sprite.frame == 0, "%s: knocked-back frame 0 first (%s, frame %d)" % [who, anim.current_animation, sprite.frame])
	ck(sprite.modulate.is_equal_approx(enemy.STUN_TINT), "%s: the stun tint stays on top (%s)" % [who, sprite.modulate])
	await create_timer(PARRY_STAGGER * 0.6).timeout
	ck(anim.current_animation == "stagger" and sprite.frame == 1 and sprite.texture.resource_path.ends_with("stagger.png"),
			"%s: still the stagger pose at 60 %% of the stagger, dazed frame 1 (%s, frame %d)" % [who, anim.current_animation, sprite.frame])
	await create_timer(PARRY_STAGGER * 0.6).timeout
	ck(sprite.texture == sheet and Vector2i(sprite.hframes, sprite.vframes) == cells,
			"%s: its sheet back after the stagger (%s, %dx%d)" % [who, sprite.texture.resource_path.get_file(), sprite.hframes, sprite.vframes])
	ck(String(anim.current_animation) in NORMAL and anim.speed_scale == 1.0 and sprite.frame < cells.x * cells.y,
			"%s: back to a normal animation (%s ×%.2f, frame %d)" % [who, anim.current_animation, anim.speed_scale, sprite.frame])
	ck(sprite.modulate == Color.WHITE, "%s: the tint is gone" % who)
	enemy.queue_free()
	await create_timer(0.2).timeout

func _jackal_hurt_frame() -> void:
	print("[jackal] stagger pose = the hurt frame of its own sheet for the whole stagger")
	var enemy := _spawn(JACKAL)
	await create_timer(0.6).timeout
	var sprite: Sprite2D = enemy.get_node(^"Sprite2D")
	var anim: AnimationPlayer = enemy.get_node(^"AnimationPlayer")
	var sheet: Texture2D = sprite.texture
	enemy.stagger(PARRY_STAGGER, hero.global_position.x)
	await physics_frame  # сигнал іде до _physics_process ворогів — тінь ставить наступний
	await physics_frame
	ck(anim.current_animation == "stagger" and sprite.texture == sheet and sprite.frame == JACKAL_HURT,
			"jackal: staggered shows its hurt frame (%s, %s, frame %d)" % [anim.current_animation, sprite.texture.resource_path.get_file(), sprite.frame])
	ck(sprite.modulate.is_equal_approx(enemy.STUN_TINT), "jackal: the stun tint stays on top (%s)" % sprite.modulate)
	await create_timer(PARRY_STAGGER * 0.6).timeout
	ck(anim.current_animation == "stagger" and sprite.frame == JACKAL_HURT, "jackal: still the hurt frame at 60 %% of the stagger (frame %d)" % sprite.frame)
	await create_timer(PARRY_STAGGER * 0.6).timeout
	ck(String(anim.current_animation) in NORMAL and sprite.frame != JACKAL_HURT and sprite.texture == sheet,
			"jackal: back to a normal animation (%s, frame %d)" % [anim.current_animation, sprite.frame])
	ck(sprite.modulate == Color.WHITE, "jackal: the tint is gone")
	enemy.queue_free()
	await create_timer(0.2).timeout

func _dies_in_stagger() -> void:
	print("[death] killed while staggered: the death frames come from the sheet")
	var enemy := _spawn(ENEMIES.bandit)
	await create_timer(0.6).timeout
	var sprite: Sprite2D = enemy.get_node(^"Sprite2D")
	var anim: AnimationPlayer = enemy.get_node(^"AnimationPlayer")
	var sheet: Texture2D = sprite.texture
	enemy.stagger(PARRY_STAGGER, hero.global_position.x)
	await physics_frame  # сигнал іде до _physics_process ворогів — тінь ставить наступний
	await physics_frame
	enemy.take_damage(enemy.current_health)
	await create_timer(0.8).timeout
	ck(anim.current_animation == "death" and sprite.texture == sheet and sprite.hframes == 4,
			"bandit: dies with the sheet's death frames (%s, %s)" % [anim.current_animation, sprite.texture.resource_path.get_file()])
	await create_timer(1.5).timeout

func _archer_keeps_tint() -> void:
	print("[archer] no stagger.png: the tint alone, its sheet untouched")
	var enemy := _spawn(ARCHER)
	await create_timer(0.6).timeout
	var sprite: Sprite2D = enemy.get_node(^"Sprite2D")
	var sheet: Texture2D = sprite.texture
	enemy.stagger(PARRY_STAGGER, hero.global_position.x)
	await physics_frame  # сигнал іде до _physics_process ворогів — тінь ставить наступний
	await physics_frame
	ck(sprite.texture == sheet and sprite.modulate == enemy.STUN_TINT and not enemy.enemy_view.staggered,
			"archer: staggered keeps its sheet with the tint (%s, %s, staggered %s)" % [sprite.texture.resource_path.get_file(), sprite.modulate, enemy.enemy_view.staggered])
	enemy.queue_free()
