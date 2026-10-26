extends SceneTree

## D554: одна кімната на High і на Low поруч (ліворуч High, праворуч Low) → design/shots/graphics_quality/.
## Потрібне ВІКНО:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_graphics_quality.gd -- room=Village

const Kit := preload("res://SampleProject/UI/input_kit.gd")
const OUT := "res://design/shots/graphics_quality/"


func _initialize() -> void:
	var room: String = "Village"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("room="):
			room = arg.trim_prefix("room=")
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	var game: Node = await Kit.boot(self)
	print("CAPTURE booted in %s" % game.map.scene_file_path.get_file())
	game.player.set_invulnerable(true)
	if game.map.scene_file_path.get_file().get_basename() != room:
		await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % room, ^"Arrival")
		await Kit.frames(self, 30)
		await Kit.drain(self)
	var quality: Node = root.get_node("DisplayManager").graphics_quality
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	quality.apply("high")
	await Kit.frames(self, 6)
	var high: Image = root.get_viewport().get_texture().get_image()
	quality.apply("low")
	await Kit.frames(self, 6)
	var low: Image = root.get_viewport().get_texture().get_image()
	quality.apply("high")
	high.save_png(ProjectSettings.globalize_path(OUT + "%s_high.png" % room))
	low.save_png(ProjectSettings.globalize_path(OUT + "%s_low.png" % room))
	var w: int = high.get_width() / 2
	var h: int = high.get_height() / 2
	high.resize(w, h, Image.INTERPOLATE_BILINEAR)
	low.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var both := Image.create(w * 2, h, false, high.get_format())
	both.blit_rect(high, Rect2i(0, 0, w, h), Vector2i.ZERO)
	both.blit_rect(low, Rect2i(0, 0, w, h), Vector2i(w, 0))
	both.save_png(ProjectSettings.globalize_path(OUT + "%s_high_vs_low.png" % room))
	print("CAPTURE %s high / low -> %s" % [room, OUT])
	quit()
