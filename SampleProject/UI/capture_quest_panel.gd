extends SceneTree

## D717: верх HUD з плашкою квесту (щойно змінилась ціль) і без неї (згасла за OBJECTIVE_PLAQUE_HOLD).
## Обидва кадри — один аркуш design/shots/quest_panel_d717.png (верхні 360 px екрана, «з» над «без»).
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_quest_panel.gd
## Нова гра; справжні сейви не чіпаються (нічого не зберігається).

const OBJECTIVE := "Return to the village"
const BAND := Rect2i(0, 0, 1920, 360)

var tokens: GDScript = load("res://SampleProject/UI/Tokens/UITokens.gd")


func _drain(dm: Node) -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _initialize() -> void:
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await process_frame
	await _drain(sl.get_dialogue_manager())
	var hud: Node = get_first_node_in_group(&"combat_hud_top")

	game.set_objective(OBJECTIVE)
	var deadline: int = Time.get_ticks_msec() + int(tokens.OBJECTIVE_PLAQUE_FADE * 1000.0) + 300
	while Time.get_ticks_msec() < deadline:
		await process_frame
	var shown: Image = await _shot()
	print("with plaque: shown=%s" % hud.is_plaque_shown())
	deadline = Time.get_ticks_msec() + int((tokens.OBJECTIVE_PLAQUE_HOLD + tokens.OBJECTIVE_PLAQUE_FADE * 2.0 + 0.5) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
	var hidden: Image = await _shot()
	print("without plaque: shown=%s" % hud.is_plaque_shown())

	var sheet := Image.create(BAND.size.x, BAND.size.y * 2, false, Image.FORMAT_RGBA8)
	sheet.blit_rect(_rgba(shown).get_region(BAND), Rect2i(Vector2i.ZERO, BAND.size), Vector2i.ZERO)
	sheet.blit_rect(_rgba(hidden).get_region(BAND), Rect2i(Vector2i.ZERO, BAND.size), Vector2i(0, BAND.size.y))
	var out := ProjectSettings.globalize_path("res://design/shots/quest_panel_d717.png")
	sheet.save_png(out)
	print("saved %s" % out)
	quit()


func _rgba(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	return img
