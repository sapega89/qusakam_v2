extends SceneTree

## Знімок D737: розміри видів поруч із Кусакамом — три ряди (бандити, звірі, летючі), кожен вид у позі idle на
## підлозі DesertRoad (летючі — над нею). design/shots/enemy_sizes/<OUT або lineup>.png. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_enemy_sizes.gd

const DIR := "res://SampleProject/Scenes/Characters/Enemies/"
const ROWS := [
	[["default_enemy", "melee"], ["enemy_shield", "shield"], ["enemy_bandit_brute", "bandit_brute"], ["enemy_tower_shield_guard", "tower_shield_guard"], ["enemy_archer", "archer"], ["enemy_heavy_archer", "heavy_archer"]],
	[["enemy_fast", "fast"], ["enemy_jackal_pack_leader", "jackal_pack_leader"], ["enemy_jackal_cursed", "jackal_cursed"], ["enemy_tank", "tank"], ["enemy_armoured_scorpion", "armoured_scorpion"]],
	[["enemy_vulture", "vulture"], ["enemy_old_vulture", "old_vulture"], ["enemy_bat", "bat"], ["enemy_fly", "fly"]],
]
const GAP := 135.0
const PANEL := Vector2i(1000, 260)

var game: Node
var hero: Node
var panels: Array[Image] = []


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 400:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame
	await create_timer(1.0).timeout
	hero = game.player
	hero.Max_Health = 9999
	hero.current_health = 9999
	for node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			node.queue_free()
	await create_timer(0.6).timeout
	var floor_y: float = hero.global_position.y
	var start_x: float = hero.global_position.x
	for row: Array in ROWS:
		var lineup: Array[Node] = []
		for i in row.size():
			var e: Node = load(DIR + row[i][0] + ".tscn").instantiate()
			e.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % row[i][1])
			e.position = game.map.to_local(Vector2(start_x + 110.0 + i * GAP, floor_y - 40.0))
			game.map.add_child(e)
			lineup.append(e)
		for i in 40: await physics_frame
		for e: Node in lineup:
			e.set_physics_process(false)
			e.enemy_logic.set_physics_process(false)
			e.enemy_logic.last_direction = -1
			e.enemy_view.update_direction(-1)
			e.anim_player.play(&"idle")
			if e.flying:
				e.global_position.y = floor_y - 90.0
		hero.global_position.x = start_x
		hero.velocity = Vector2.ZERO
		await create_timer(0.4).timeout
		await _grab(Vector2(start_x + (row.size() - 1) * GAP * 0.5 + 40.0, floor_y - 20.0))
		for e: Node in lineup:
			e.queue_free()
		await create_timer(0.3).timeout
	var sheet := Image.create(PANEL.x, PANEL.y * panels.size(), false, Image.FORMAT_RGBA8)
	for i in panels.size():
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, panels[i].get_size()), Vector2i(0, PANEL.y * i))
	var name := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "lineup"
	var out := ProjectSettings.globalize_path("res://design/shots/enemy_sizes/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("shot ", out)
	quit()


## Кадр навколо [param world] (світові px), PANEL завбільшки, у panels.
func _grab(world: Vector2) -> void:
	Engine.time_scale = 0.0
	await RenderingServer.frame_post_draw
	var mid: Vector2 = root.get_viewport().get_canvas_transform() * world
	var img: Image = root.get_texture().get_image()
	var rect := Rect2i(Vector2i(mid) - PANEL / 2, PANEL).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.convert(Image.FORMAT_RGBA8)
	var panel := Image.create(PANEL.x, PANEL.y, false, Image.FORMAT_RGBA8)
	panel.blit_rect(img, rect, Vector2i.ZERO)
	panels.append(panel)
	Engine.time_scale = 1.0
