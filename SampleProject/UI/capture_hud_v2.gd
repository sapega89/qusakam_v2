extends SceneTree

## HUD v2 (D453, D549, D552; cloud/hud-v2): панель героя з чипами F і Q, хотбар на 8 слотів, смуга XP на всю ширину.
## Слоти: готові, на перезарядці, без SP, порожні; асист готовий. Кадр гри + порівняння з Figma (design/shots):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_hud_v2.gd -- 1920x1080
##   godot --path . --resolution 1280x720 --script res://SampleProject/UI/capture_hud_v2.gd -- 1280x720
## Нова гра; справжні сейви не чіпаються (нічого не зберігається).

const FIGMA := "res://design/shots/figma_hud_v2_context.png"
## [навичка, слот]: 4 і 8 порожні, як у Figma 492:6543.
const LOADOUT := [["healing_palm", 0], ["fire_strike", 1], ["radiant_smite", 2],
		["electric_strike", 4], ["skyfall_blessing", 5], ["judgement_of_the_sky", 6]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var res: String = args[0] if not args.is_empty() else "1920x1080"
	var out := ProjectSettings.globalize_path("res://design/shots")
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await process_frame

	var gm: Node = sl.get_game_manager()
	var sm: Node = sl.get_skill_manager()
	var unlocked: Array = gm.player_state.get("unlocked_skills", [])
	for pair in LOADOUT:
		if not pair[0] in unlocked:
			unlocked.append(pair[0])
	gm.player_state["unlocked_skills"] = unlocked
	for pair in LOADOUT:
		sm.equip_skill(pair[0], pair[1])
	sm.set_max_sp(30)
	sm.restore_sp(30)
	sm._cooldowns["fire_strike"] = 2.1  # слот 2 — на перезарядці, як у Figma
	sl.get_inventory_manager().add_item("potion", 2)
	sl.get_xp_manager().add_xp(40)
	var cm: Node = sl.get_companion_manager()
	game.set_quest_flag("lab_companion_01_complete", true)
	cm.announce_unlock("lab_companion_01_complete")
	cm.toggle_party("alisia")
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join("hud_v2_%s.png" % res))
	print("saved hud_v2_%s.png (%s)" % [res, img.get_size()])
	if res == "1920x1080":
		_compare(img, out)
	quit()


## Figma поруч із грою: панель героя й хотбар, кадр Figma 1600×900 розтягнутий до 1920×1080.
func _compare(ours: Image, out: String) -> void:
	var figma := Image.load_from_file(ProjectSettings.globalize_path(FIGMA))
	figma.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	var hero := Rect2i(0, 0, 600, 240)
	var bar := Rect2i(540, 920, 840, 160)
	var sheet := Image.create(1680, 400, false, Image.FORMAT_RGBA8)
	sheet.blit_rect(figma.get_region(hero), Rect2i(Vector2i.ZERO, hero.size), Vector2i(0, 0))
	sheet.blit_rect(ours.get_region(hero), Rect2i(Vector2i.ZERO, hero.size), Vector2i(600, 0))
	sheet.blit_rect(figma.get_region(bar), Rect2i(Vector2i.ZERO, bar.size), Vector2i(0, 240))
	sheet.blit_rect(ours.get_region(bar), Rect2i(Vector2i.ZERO, bar.size), Vector2i(840, 240))
	sheet.save_png(out.path_join("hud_v2_vs_figma.png"))
	print("saved hud_v2_vs_figma.png")
