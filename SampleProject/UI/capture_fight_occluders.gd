extends SceneTree

## B199: бій за заслоном переднього плану — ліворуч як було (заслон повний), праворуч FightOccluderFade (тьмяний).
## Потрібне вікно:
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_fight_occluders.gd
## Файл: design/shots/fight_occluders.png

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const OUT := "res://design/shots/fight_occluders.png"
## Найгірше місце з verify_room_entrances [B199]: кімната, бій, точка спавну.
const ROOM := "res://SampleProject/Maps/%s.tscn" % "DesertRoad"
const SPAWNER := ^"EnemySpawner"
const POINT := 1


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	root.get_node("SaveSystem").set_save_dir("user://capture_fight_occluders/")
	var game: Node = await Kit.boot(self)
	await game.teleport_to_room(ROOM, ^"")
	await Kit.frames(self, 20)
	await Kit.drain(self)
	var spawner: Node = game.map.get_node(SPAWNER)
	if spawner.get_alive_enemies_count() == 0:
		spawner.spawn_all_enemies()
	await Kit.frames(self, 10)
	var sp: Node2D = spawner.spawn_points[POINT]
	game.place_player(sp.global_position + Vector2(-60.0, -40.0))
	await Kit.frames(self, 4)
	(game.player.get_node(^"Camera2D") as Camera2D).reset_smoothing()
	var fade: Node = game.get_node(^"FightOccluderFade")
	var shots: Array[Image] = []
	for on: bool in [false, true]:
		fade.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		if not on:
			for o: CanvasItem in fade.occluders_of(game.map):
				o.modulate.a = 1.0
		await Kit.frames(self, 25)
		game.player.current_health = game.player.Max_Health
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2)
		shots.append(img)
	var out := Image.create(shots[0].get_width() * 2 + 8, shots[0].get_height(), false, shots[0].get_format())
	out.fill(Color.BLACK)
	out.blit_rect(shots[0], Rect2i(Vector2i.ZERO, shots[0].get_size()), Vector2i.ZERO)
	out.blit_rect(shots[1], Rect2i(Vector2i.ZERO, shots[1].get_size()), Vector2i(shots[0].get_width() + 8, 0))
	out.save_png(ProjectSettings.globalize_path(OUT))
	print("saved " + OUT)
	quit()
