extends SceneTree

## Знімок A17: ефекти ударів ворогів у DesertRoad — кожен вид і обидва боси (серія, slam, ривок). На кожен удар два
## кадри: шлейф на кадрі удару і влучання в героя (розтин, завмирання, спалах). У рядку — два удари (по 2 кадри).
## Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_enemy_fx.gd
## Файл: design/shots/enemy_fx.png

const OUT := "res://design/shots/enemy_fx.png"
const CELL := Vector2i(360, 220)
const PER_ROW := 2
const ENEMIES := "res://SampleProject/Scenes/Characters/Enemies/"
const STATS := "res://SampleProject/Resources/Enemies/enemy_stats_%s.tres"
const KINDS := ["melee", "shield", "tower_shield_guard", "bandit_brute", "tank", "armoured_scorpion", "fast",
		"jackal_cursed", "jackal_pack_leader", "bat", "fly", "vulture", "old_vulture", "archer", "heavy_archer"]
const BOSSES := {
	"lab_boss": "res://SampleProject/Scenes/Characters/Bosses/lab_boss.tscn",
	"scorpicore_warrior": "res://SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn",
}
## Кадр шлейфа: другий з трьох (30 к/с) — дуга на всю довжину; влучання — розтин на другому кадрі.
const SMEAR_WAIT := 0.045
const IMPACT_WAIT := 0.06

var game: Node
var hero: Node
var floor_y: float
var arena_x: float


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	root.get_node("DisplayManager").graphics_quality.apply("high")
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _drain(sl.get_dialogue_manager())
	await create_timer(1.5).timeout
	hero = game.player
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	hero.global_position.x += 700.0
	await create_timer(0.8).timeout
	floor_y = hero.global_position.y
	arena_x = hero.global_position.x

	var cells: Array[Image] = []
	for kind: String in KINDS:
		var enemy: Node = load(ENEMIES + ("default_enemy.tscn" if kind == "melee" else "enemy_%s.tscn" % kind)).instantiate()
		enemy.enemy_stats = load(STATS % kind)
		enemy = await _place(enemy)
		cells.append_array(await _shot(enemy, func() -> void: enemy.start_attack(-1)))
		enemy.queue_free()
	for id: String in BOSSES:
		var boss: Node = await _place(load(BOSSES[id]).instantiate())
		for kind: String in ["combo", "slam", "charge"]:
			var moves: Array = boss.moves.filter(func(m: Dictionary) -> bool: return m.kind == kind)
			if moves.is_empty():
				continue
			boss.enemy_logic.last_move = moves[0]
			if kind == "slam":
				cells.append_array(await _shot(boss, func() -> void: boss.strike(moves[0])))
			else:
				cells.append_array(await _shot(boss, func() -> void: boss.start_attack(-1)))
		boss.queue_free()

	var cols := PER_ROW * 2
	var rows := ceili(cells.size() / float(cols))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % cols * CELL.x, i / cols * CELL.y))
	sheet.save_png(ProjectSettings.globalize_path(OUT))
	print("CAPTURED " + OUT)
	quit()


## Ворог за 70 px праворуч від героя, ШІ стоїть.
func _place(enemy: Node) -> Node:
	enemy.position = game.map.to_local(Vector2(arena_x + 70.0, floor_y - 40.0))
	game.map.add_child(enemy)
	for i in 30: await physics_frame
	enemy.set_physics_process(false)
	enemy.enemy_logic.set_physics_process(false)
	enemy.enemy_logic.set_process(false)
	enemy.player = hero
	enemy.Max_Health = 99999
	enemy.current_health = enemy.Max_Health
	hero.global_position = Vector2(arena_x, floor_y)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = 1
	return enemy


## Кадр шлейфа після [param strike] і кадр влучання удару [param enemy] у героя.
func _shot(enemy: Node, strike: Callable) -> Array[Image]:
	while hero.is_invulnerable or Engine.time_scale < 1.0:
		await physics_frame
	await create_timer(0.3).timeout
	strike.call()
	await create_timer(SMEAR_WAIT, true, false, true).timeout
	var smear: Image = await _grab(enemy)
	enemy.end_attack()
	await create_timer(0.3).timeout
	hero.take_damage(5, enemy)
	await create_timer(IMPACT_WAIT, true, false, true).timeout
	var impact: Image = await _grab(enemy)
	for i in 20: await process_frame
	return [smear, impact]


## Виріз вікна між героєм і ворогом.
func _grab(enemy: Node) -> Image:
	await process_frame
	var img: Image = root.get_texture().get_image()
	var at: Vector2 = (hero.get_global_transform_with_canvas().origin + enemy.get_global_transform_with_canvas().origin) / 2.0
	var origin := Vector2i(clampi(int(at.x) - CELL.x / 2, 0, img.get_width() - CELL.x), clampi(int(at.y) - CELL.y / 2 - 20, 0, img.get_height() - CELL.y))
	return img.get_region(Rect2i(origin, CELL))


func _drain(dm: Node) -> void:
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
