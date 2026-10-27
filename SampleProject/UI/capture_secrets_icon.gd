extends SceneTree

## Знімок рівня 2 карти (World Map) Canyon of Whispers до і після: зліва скрині закриті й секретів не знайдено,
## справа скрині відкриті (приглушені) і знайдено два секрети — фіалкові значки зі шпариною (D765, secrets-icon).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##     --script res://SampleProject/UI/capture_secrets_icon.gd
## Пише design/shots/secrets/map_icon_before_after.png. Клітинки досліджено лише в памʼяті MetSys, сейв не пишеться.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const OUT := "res://design/shots/secrets"
const LOCATION := "canyon_of_whispers"
const FOUND := {"DragonMural": "SecretArea_DragonMural", "MesaClimb": "SecretArea_MesaTop"}


func _level2(ui: Node) -> Image:
	ui.open_game_menu()
	await Kit.frames(self, 16)
	get_first_node_in_group("game_menu").switch_to_tab("World Map")
	await Kit.frames(self, 8)
	get_first_node_in_group("game_menu").find_child("MetSysMapComponent", true, false).open_location(LOCATION)
	await Kit.frames(self, 8)
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	ui.close_game_menu()
	await Kit.frames(self, 8)
	return shot


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	var game: Node = await Kit.boot(self)
	var ui: Node = root.get_node("ServiceLocator").get_ui_manager()
	var met: Node = root.get_node("MetSys")
	var LocationMap: GDScript = load("res://SampleProject/Scripts/Systems/LocationMap.gd")
	var SecretArea: GDScript = load("res://SampleProject/Scripts/Gameplay/SecretArea.gd")
	game.set_quest_flag("village_left_complete", true)  # вкладку World Map відкриває сюжет
	var data: RefCounted = LocationMap.new(LOCATION)
	for c: Vector3i in data.cells:
		met.save_data.explore_cell(c)
	var before: Image = await _level2(ui)

	var folder: String = met.settings.map_root_folder
	for room: String in data.cells.values():
		var path := folder.path_join(room + ".tscn")
		var key: String = met.map_data.get_room_from_scene_path(path, false)
		var scene: Node = (load(path) as PackedScene).instantiate()
		for chest: Node in scene.find_children("*", "Chest", true, false):
			game.set_room_state(key, "opened_%s" % chest.name, true)
		scene.free()
	for room: String in FOUND:
		game.set_room_state(met.map_data.get_room_from_scene_path(folder.path_join(room + ".tscn"), false),
				SecretArea.state_key(FOUND[room]), true)
	var after: Image = await _level2(ui)

	var half := Vector2i(960, 540)
	before.resize(half.x, half.y, Image.INTERPOLATE_LANCZOS)
	after.resize(half.x, half.y, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(half.x * 2, half.y, false, before.get_format())
	out.blit_rect(before, Rect2i(Vector2i.ZERO, half), Vector2i.ZERO)
	out.blit_rect(after, Rect2i(Vector2i.ZERO, half), Vector2i(half.x, 0))
	out.save_png(ProjectSettings.globalize_path("%s/map_icon_before_after.png" % OUT))
	# Легенда й значки в натуральний розмір — для перевірки знака.
	after = await _level2(ui)
	after.get_region(Rect2i(1480, 680, 340, 260)).save_png(ProjectSettings.globalize_path("%s/map_legend.png" % OUT))
	print("shot map_icon_before_after")
	quit(0)
