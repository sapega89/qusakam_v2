extends SceneTree

## Знімок картки локації World Map з лічильником секретів (D765): «Explored N% · Chests a/b · Secrets c/d».
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##     --script res://SampleProject/UI/capture_secrets.gd
## Пише design/shots/secrets/card_vs_figma.png: згори картка з кадру Figma 539:6472, знизу — гра (en і uk).

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const OUT := "res://design/shots/secrets"
const REF := "res://design/refs/map_level1_world.png"
## Картка й трохи поля навколо (world_map_spec: картка в (368, 790)).
const CROP := Rect2i(340, 770, 760, 170)
const FOUND := ["res://SampleProject/Maps/DragonMural.tscn", "res://SampleProject/Maps/MesaClimb.tscn"]


func _card() -> Image:
	await Kit.frames(self, 8)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_region(CROP)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var met: Node = root.get_node("MetSys")
	var SecretArea: GDScript = load("res://SampleProject/Scripts/Gameplay/SecretArea.gd")
	game.set_quest_flag("village_left_complete", true)  # вкладку World Map відкриває сюжет
	game.set_room_state(met.map_data.get_room_from_scene_path(FOUND[0], false), SecretArea.state_key("SecretArea_DragonMural"), true)
	game.set_room_state(met.map_data.get_room_from_scene_path(FOUND[1], false), SecretArea.state_key("SecretArea_MesaTop"), true)

	sl.get_ui_manager().open_game_menu()
	await Kit.frames(self, 16)
	get_first_node_in_group("game_menu").switch_to_tab("World Map")
	var en: Image = await _card()
	TranslationServer.set_locale("uk")
	sl.get_ui_manager().close_game_menu()
	await Kit.frames(self, 8)
	sl.get_ui_manager().open_game_menu()
	await Kit.frames(self, 16)
	get_first_node_in_group("game_menu").switch_to_tab("World Map")
	var uk: Image = await _card()

	var ref := Image.load_from_file(ProjectSettings.globalize_path(REF))
	ref.convert(en.get_format())
	ref.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(CROP.size.x, CROP.size.y * 3, false, en.get_format())
	out.blit_rect(ref.get_region(CROP), Rect2i(Vector2i.ZERO, CROP.size), Vector2i.ZERO)
	out.blit_rect(en, Rect2i(Vector2i.ZERO, CROP.size), Vector2i(0, CROP.size.y))
	out.blit_rect(uk, Rect2i(Vector2i.ZERO, CROP.size), Vector2i(0, CROP.size.y * 2))
	out.save_png(ProjectSettings.globalize_path("%s/card_vs_figma.png" % OUT))
	print("shot card_vs_figma")
	quit(0)
