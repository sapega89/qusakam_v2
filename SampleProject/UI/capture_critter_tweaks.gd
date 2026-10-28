extends SceneTree

## Голуб у Місті й міль на горищі поряд з героєм (BACKLOG «Critter tweaks»). Потрібне вікно; запускати двічі:
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_critter_tweaks.gd -- before
## (на старих сценах), потім те саме з `-- after`: друге збирає design/shots/critter_tweaks.png (до | після).

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const Critter = preload("res://SampleProject/Scripts/Gameplay/AmbientCritter.gd")
const OUT := "res://design/shots/critter_tweaks.png"
const TMP := "user://capture_critter_tweaks/%s_%s.png"
const CROP := Vector2i(480, 270)
const ZOOM := 2
## Кімната, двері прибуття, вузол створіння, де стає герой (зсув від створіння; на горищі підлога лише x 448..671).
const SHOTS := [
	["res://SampleProject/Maps/City.tscn", ^"ForgeDoor", ^"Critters/Pigeon3", "city", Vector2(90.0, -48.0)],
	["res://SampleProject/Maps/ElderHouse.tscn", ^"Arrival", ^"Critters/Moth1", "attic", Vector2(-90.0, -48.0)],
]


func _initialize() -> void:
	var tag: String = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	root.get_node("SaveSystem").set_save_dir("user://capture_critter_tweaks/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://capture_critter_tweaks/"))
	var game: Node = await Kit.boot(self)
	for shot: Array in SHOTS:
		Critter.left_at.clear()
		await game.teleport_to_room(shot[0], shot[1])
		await Kit.frames(self, 20)
		await Kit.drain(self)
		for c: Node in game.map.get_node(^"Critters").get_children():
			c.set(&"scare_distance", 0.0)
		var critter: Node2D = game.map.get_node(shot[2])
		game.place_player(critter.global_position + (shot[4] as Vector2))
		await Kit.frames(self, 90)
		# Сидить на тому самому кадрі сидіння в обох знімках: голуб міг злетіти, поки герой з'являвся, тож спершу
		# його політ (до 2 с) закінчується, потім він знову сідає.
		await create_timer(2.5).timeout
		critter.set(&"_away", false)
		critter.call(&"_sit")
		var sprite: AnimatedSprite2D = critter.get_node(^"Sprite")
		sprite.stop()
		sprite.frame = 0
		await Kit.frames(self, 2)
		await RenderingServer.frame_post_draw
		var at := Vector2i(critter.get_global_transform_with_canvas().origin)
		var image: Image = root.get_texture().get_image()
		var crop := image.get_region(Rect2i(at - Vector2i(CROP.x / 2, CROP.y * 2 / 3), CROP))
		crop.resize(CROP.x * ZOOM, CROP.y * ZOOM, Image.INTERPOLATE_NEAREST)
		crop.save_png(ProjectSettings.globalize_path(TMP % [tag, shot[3]]))
	if tag == "after":
		var size := CROP * ZOOM
		var sheet := Image.create(size.x * 2 + 8, size.y * 2 + 8, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.BLACK)
		for row: int in SHOTS.size():
			for col: int in 2:
				var part := Image.load_from_file(ProjectSettings.globalize_path(TMP % [["before", "after"][col], SHOTS[row][3]]))
				part.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(part, Rect2i(Vector2i.ZERO, size), Vector2i(col * (size.x + 8), row * (size.y + 8)))
		sheet.save_png(ProjectSettings.globalize_path(OUT))
		print("saved " + OUT)
	quit()
