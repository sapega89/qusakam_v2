extends SceneTree

## Сюжетна подача розмови (D110–D112, MASTER_PLAN S5) поруч із Figma conversation-dialog-choices 36:65
## (design/refs/figma_36_65_story_dialogue.png) — кадри в теку з аргументу (за замовчуванням design/shots/story_dialogue):
##   grandfather_uk / grandfather_en — рішення діда в його домі (Каньйон Шепотів);
##   census_uk / census_en           — перепис писаря біля Міської брами (Місто).
## Кожен кадр — гра ліворуч, Figma праворуч, 3840×1080.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_story_dialogue.gd -- <dir>

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const FIGMA := "res://design/refs/figma_36_65_story_dialogue.png"

var out: String
var dm: Node
var figma: Image


## Кадр гри й Figma поруч.
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var game_image: Image = root.get_texture().get_image()
	game_image.convert(Image.FORMAT_RGBA8)
	var pair := Image.create(game_image.get_width() * 2, game_image.get_height(), false, Image.FORMAT_RGBA8)
	pair.blit_rect(game_image, Rect2i(Vector2i.ZERO, game_image.get_size()), Vector2i.ZERO)
	pair.blit_rect(figma, Rect2i(Vector2i.ZERO, figma.get_size()), Vector2i(game_image.get_width(), 0))
	pair.save_png(out.path_join("%s.png" % name))


## Перша репліка розмови [param path] набрана до кінця.
func _open(path: String) -> void:
	dm.start_dialogue(path)
	await Kit.frames(self, 30)
	dm.current_dialogue_box.finish()
	await Kit.frames(self, 6)


func _gate_fight(game: Node) -> void:
	game.set_quest_flag("city_gates_intro_complete", true)
	await game.teleport_to_room("res://SampleProject/Maps/CityGates.tscn", ^"Arrival")
	await Kit.frames(self, 30)
	await Kit.drain(self)
	await Kit.frames(self, 30)
	for enemy in game.map.find_children("*", "CharacterBody2D", true, false):
		if enemy.is_in_group(&"enemies") and enemy.is_alive():
			enemy.take_damage(99999, game.player)
	for i in 300:
		await process_frame
		if dm.is_dialogue_active():
			break


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots/story_dialogue")
	DirAccess.make_dir_recursive_absolute(out)
	figma = Image.load_from_file(ProjectSettings.globalize_path(FIGMA))
	figma.convert(Image.FORMAT_RGBA8)
	figma.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	await process_frame
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	root.get_node("SaveSystem").settings_module.settings.auto_advance = false
	var game: Node = await Kit.boot(self)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	var loc: Node = root.get_node("LocalizationManager")

	loc.apply_language("uk")
	await game.teleport_to_room("res://SampleProject/Maps/ElderHouse.tscn", ^"Arrival")
	await Kit.frames(self, 40)
	await Kit.drain(self)
	await Kit.frames(self, 20)
	await _open("res://dialogue_quest/OldMan_Decision.dqd")
	await _shot("grandfather_uk")
	await Kit.drain(self)
	loc.apply_language("en")
	await _open("res://dialogue_quest/OldMan_Decision.dqd")
	await _shot("grandfather_en")
	await Kit.drain(self)

	loc.apply_language("uk")
	await _gate_fight(game)
	await Kit.frames(self, 40)
	dm.current_dialogue_box.finish()
	await Kit.frames(self, 6)
	await _shot("census_uk")
	await Kit.drain(self)
	loc.apply_language("en")
	await _open("res://dialogue_quest/CityGates_Census.dqd")
	await _shot("census_en")
	await Kit.drain(self)
	quit()
