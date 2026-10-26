extends SceneTree

## Captures of every Game Menu tab (menu QA, B129–B132, D493) into the directory given after `--`:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_menu_qa.gd -- <dir>
## Needs a window (headless renders black).

const Kit = preload("res://SampleProject/UI/input_kit.gd")

const TABS: Array[String] = ["World Map", "Journal", "Inventory", "Equipment", "Skills", "Status"]

var _dir := ""


func _shot(name: String) -> void:
	await Kit.frames(self, 8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("shot %s" % name)


func _initialize() -> void:
	_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	var game: Node = await Kit.boot(self)
	await Kit.drain(self)
	var sl: Node = root.get_node("ServiceLocator")
	for flag in ["village_oldman_gift", "village_oldman_healed", "village_abduction_complete", "village_left_complete"]:
		game.set_quest_flag(flag, true)
	var inventory: Node = sl.get_inventory_manager()
	for id in ["potion", "herb", "iron_sword", "iron_armor", "iron_helmet"]:
		inventory.add_item(id, 1)
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	await Kit.frames(self, 16)
	var menu: Node = get_first_node_in_group("game_menu")
	for tab in TABS:
		menu.switch_to_tab(tab)
		await _shot("tab_%s" % tab.to_lower().replace(" ", "_"))
	await Kit.mouse(self, menu.misc_button)
	await _shot("tab_misc")
	quit()
