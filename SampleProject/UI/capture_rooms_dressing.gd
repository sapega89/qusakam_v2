extends SceneTree

## R2/R3 (rooms-dressing): кадри кімнат для аркушів «до / після» design/shots/rooms_dressing_*.png. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_rooms_dressing.gd -- <out_dir> Room:x:y[:wait] ...
## Кожен кадр — <out_dir>/<Room>_<x>_<y>.png: герой у (x, y), камера доїхала; бої й вороги прибрані, щоб не тримали камеру.
## wait — кадрів після того, як камера доїхала (за замовчуванням 40). Аркуш складає Scripts/Tools/rooms_dressing_sheet.py.

const Kit = preload("res://SampleProject/UI/input_kit.gd")


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	root.get_node("SaveSystem").set_save_dir("user://capture_rooms_dressing/")
	var game: Node = await Kit.boot(self)
	game.player.set_invulnerable(true)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	for view: String in args.slice(1):
		var p: PackedStringArray = view.split(":")
		var room := "res://SampleProject/Maps/%s.tscn" % p[0]
		if game.map.scene_file_path != room:
			await game.teleport_to_room(room, ^"Arrival")
			await Kit.frames(self, 10)
			await Kit.drain(self)
		for n: Node in game.map.get_children():
			if String(n.name).begins_with("Fight_") or String(n.name) == "EnemySpawner":
				n.free()
		game.place_player(Vector2(float(p[1]), float(p[2])))
		game.player.velocity = Vector2.ZERO
		await Kit.frames(self, 4)
		(game.player.get_node(^"Camera2D") as Camera2D).reset_smoothing()
		await Kit.frames(self, int(p[3]) if p.size() > 3 else 40)
		await RenderingServer.frame_post_draw
		var file := "%s/%s_%s_%s.png" % [out_dir, p[0], p[1], p[2]]
		root.get_texture().get_image().save_png(file)
		print("saved " + file)
	quit()
