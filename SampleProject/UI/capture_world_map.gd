extends SceneTree

## Кадри вкладки World Map у два рівні (world_map_spec) поруч з затвердженими кадрами Figma:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_world_map.gd
## Пише в design/shots/world_map/: level1_world.png, level2_location.png і *_vs_figma.png (ліворуч Figma, праворуч гра).
## Потрібне вікно (headless малює чорне). Дослідження клітинок міняється лише в памʼяті MetSys — сейвів не чіпає.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const OUT := "res://design/shots/world_map"
const REFS := {
	"level1_world": "res://design/refs/map_level1_world.png",
	"level2_location": "res://design/refs/map_level2_location.png",
}


func _shot(name: String) -> void:
	await Kit.frames(self, 8)
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	var ref := Image.load_from_file(ProjectSettings.globalize_path(REFS[name]))
	ref.convert(shot.get_format())
	ref.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	var half: Image = shot.duplicate()
	half.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	var pair := Image.create(1920, 540, false, shot.get_format())
	pair.blit_rect(ref, Rect2i(0, 0, 960, 540), Vector2i.ZERO)
	pair.blit_rect(half, Rect2i(0, 0, 960, 540), Vector2i(960, 0))
	pair.save_png(ProjectSettings.globalize_path("%s/%s_vs_figma.png" % [OUT, name]))
	print("shot %s" % name)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var met: Node = root.get_node("MetSys")
	var LocationDB: GDScript = load("res://SampleProject/Scripts/Systems/LocationDB.gd")
	game.set_quest_flag("village_left_complete", true)  # вкладку World Map відкриває сюжет
	# Як у кадрі: частина Каньйону пройдена, а Місто відвідане.
	var location: Dictionary = LocationDB.location(LocationDB.of_scene(game.map.scene_file_path))
	for room: String in location.rooms.slice(0, 3):
		for c: Vector3i in met.map_data.get_cells_assigned_to(room + ".tscn"):
			met.save_data.explore_cell(c)
	for c: Vector3i in met.map_data.get_cells_assigned_to(LocationDB.location("city").rooms[0] + ".tscn"):
		met.save_data.explore_cell(c)

	sl.get_ui_manager().open_game_menu()
	await Kit.frames(self, 16)
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("World Map")
	await Kit.frames(self, 6)
	var map: Control = menu.find_child("MetSysMapComponent", true, false)
	map.grab_focus()
	await _shot("level1_world")
	map.open_location(map.location_ids[map.selected])
	await _shot("level2_location")
	quit(0)
