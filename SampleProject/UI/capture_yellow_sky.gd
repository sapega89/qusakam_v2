extends SceneTree

## D864: жовте небо до виходу з Лабораторії і синє після. Справжня гра (герой, вороги, HUD): кожна кімната двічі —
## ліворуч жовте небо (SkyTint.apply до прапорця), праворуч синє (після); двір Лабораторії — з його власним прапорцем.
## Одне зображення design/shots/yellow_sky.png. Потрібне ВІКНО:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_yellow_sky.gd

var SkyTint: GDScript
const OUT := "res://design/shots/yellow_sky.png"
## Кімната → мітка, до якої стає герой.
const ROOMS: Array[Array] = [
	["Canyon", ^"Arrival"],
	["DesertRoad", ^"Arrival_Start"],
	["City", ^"SavePoint"],  # кузня пішла в ремісничий квартал (D773)
	["MountainPath", ^"Arrival"],
	["CaveUnderBridge", ^"Arrival"],
	["LaboratoryOutside", ^"Arrival"],
]
const CELL := Vector2i(960, 540)


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0
	SkyTint = load("res://SampleProject/Scripts/Gameplay/SkyTint.gd")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await process_frame
	var sheet := Image.create(CELL.x * 2, CELL.y * ROOMS.size(), false, Image.FORMAT_RGB8)
	for row: int in ROOMS.size():
		var room: String = ROOMS[row][0]
		await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % room, ROOMS[row][1])
		# Двір одразу веде до фіналу демо — знімок, поки герой ще стоїть у дворі.
		for i in (6 if room == "LaboratoryOutside" else 45): await process_frame
		for col: int in 2:
			# Двір сам ставить прапорець виходу — там обидва кадри вже сині (так і в грі).
			if room != "LaboratoryOutside":
				SkyTint.apply(game.map, col == 1)
			for i in 4: await process_frame
			var shot: Image = root.get_viewport().get_texture().get_image()
			shot.convert(Image.FORMAT_RGB8)
			shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))
		print("CAPTURE %s (lab exit flag %s)" % [room, game.get_quest_flag(SkyTint.LAB_EXIT_FLAG)])
	sheet.save_png(ProjectSettings.globalize_path(OUT))
	print("CAPTURE done -> %s" % OUT)
	quit()
