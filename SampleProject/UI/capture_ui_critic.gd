extends SceneTree

## Критик раунду 13 (D717–D722, B151, B152): кадри змінених екранів у теку з аргументу (за замовчуванням design/shots/ui_critic):
##   1. hint_tray — плашка підказки вгорі під квестом (B151) і два «?» біля лівого краю (D718), uk
##   2. lesson — урок тренування одним рядком у селі (D719)
##   3. inventory — інвентар: вдягнений меч зі знаком Equipped (B152, D720)
##   4. npc_menu — меню коваля, взяте клавішею S (D721)
##   5. dialogue — вікно діалогу, репліка показана вся після натискання (D722)
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 \
##       --script res://SampleProject/UI/capture_ui_critic.gd -- <dir>

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var out: String


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%s.png" % name))


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://design/shots/ui_critic")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = true
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var dm: Node = sl.get_dialogue_manager()
	var hint: Node = get_first_node_in_group(&"tutorial_hint_display")

	# 1. Плашка вгорі й «?» біля краю — українською, найдовші тексти.
	root.get_node("LocalizationManager").apply_language("uk")
	root.get_node("EventBus").player_staggered.emit(0.3)
	root.get_node("EventBus").enemy_died.emit("e0", Vector2.ZERO)
	hint.show_hint("oldman_gift", true, true)
	await Kit.frames(self, 40)
	await _shot("hint_tray")
	hint.force_hide()
	root.get_node("LocalizationManager").apply_language("en")

	# 2. Урок тренування — один рядок.
	hint.show_hint("lesson_defend", true, true)
	await Kit.frames(self, 20)
	await _shot("lesson")
	hint.force_hide()

	# 3. Інвентар: меч вдягнений.
	var inventory: Node = sl.get_inventory_manager()
	inventory.add_item("iron_sword", 1)
	inventory.add_item("iron_dagger", 1)
	var character: Object = sl.get_game_manager().get_active_character()
	sl.get_equipment_manager().equip_item(String(character.character_id), "sword", "iron_sword",
			root.get_node("ItemDatabase").get_item("iron_sword"))
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 14)
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Inventory")
	await Kit.frames(self, 10)
	await _shot("inventory")
	sl.get_ui_manager().close_game_menu()
	await Kit.frames(self, 10)

	# 4. Меню коваля, взяте клавішею S.
	await game.teleport_to_room("res://SampleProject/Maps/City.tscn", ^"SavePoint")
	for i in 60: await physics_frame
	await Kit.drain(self)
	var smith: NpcBase = game.map.get_node(^"Blacksmith")
	game.player.global_position.x = smith.global_position.x - 40
	for i in 30: await physics_frame
	await Kit.key(self, KEY_S)
	await Kit.frames(self, 6)
	await _shot("npc_menu")
	await Kit.key(self, KEY_ESCAPE)

	# 5. Вікно діалогу: натискання під час набору показує всю репліку.
	dm.start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	await Kit.frames(self, 6)
	await Kit.key(self, KEY_ENTER)
	await _shot("dialogue")
	await Kit.drain(self)
	quit()
