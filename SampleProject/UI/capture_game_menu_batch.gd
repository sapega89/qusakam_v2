extends SceneTree

## Captures of the Game Menu batch (BACKLOG 9–13) into the directory given after `--`:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_game_menu_batch.gd -- <dir>
## Needs a window (headless renders black).

const Kit = preload("res://SampleProject/UI/input_kit.gd")

var _dir := ""


func _shot(name: String) -> void:
	await Kit.frames(self, 8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("shot %s" % name)


func _initialize() -> void:
	_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = true
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var layer: Node = ui.get_modal_layer()

	# 12: the movement hint opens its window after the intro talk.
	for i in 300:
		if layer.active_modal != null:
			break
		await process_frame
	await _shot("fb12_hint_window_keyboard")
	await Kit.pad(self, JOY_BUTTON_B)
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	root.get_node("EventBus").player_staggered.emit(0.3)
	for i in 300:
		if layer.active_modal != null:
			break
		await process_frame
	await _shot("fb12_hint_window_pad")
	await Kit.pad(self, JOY_BUTTON_B)
	await Kit.key(self, KEY_RIGHT)

	for flag in ["village_oldman_gift", "village_oldman_healed", "village_abduction_complete", "village_left_complete"]:
		game.set_quest_flag(flag, true)
	var inventory: Node = sl.get_inventory_manager()
	for id in ["potion", "herb", "iron_sword", "copper_sword", "iron_armor", "iron_helmet", "wood_log"]:
		inventory.add_item(id, 2)
	game.player.current_health = 40

	# 9 + 10: Inventory, party of one; the "Cannot Use" modal.
	ui.open_game_menu()
	await Kit.frames(self, 16)
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Inventory")
	var inv: Node = menu.find_child("InventoryComponent", true, false)
	await Kit.frames(self, 4)
	(inv._item_list.get_child(0) as Control).grab_focus()
	await _shot("fb9_inventory_party_of_one")
	for i in inv.items.size():
		if inv.items[i].id == "herb":
			await Kit.mouse(self, inv._item_list.get_child(i), true)
	await _shot("fb9_cannot_use")
	# Клавіші до кнопки у фокусі у віконному запуску не доходять через push_input — тиснемо мишею.
	await Kit.mouse(self, layer.active_modal.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.visible)[0])
	for i in inv.items.size():
		if inv.items[i].id == "potion":
			await Kit.mouse(self, inv._item_list.get_child(i), true)
	await _shot("fb9_potion_drunk")

	# 10: a companion joins.
	game.set_quest_flag(sl.get_companion_manager().UNLOCK_FLAGS["alisia"], true)
	sl.get_companion_manager().toggle_party("alisia")
	await _shot("fb10_party_of_two")

	# 11: Equipment slot picker.
	menu.switch_to_tab("Equipment")
	await Kit.frames(self, 4)
	var eq: Node = menu.find_child("EquipmentComponent", true, false)
	await Kit.mouse(self, eq._slot_rows["sword"])
	await _shot("fb11_picker_swords")
	await Kit.mouse(self, layer.active_modal._list.get_child(0))
	await Kit.mouse(self, eq._slot_rows["sword"])
	await _shot("fb11_picker_worn_marked")
	await Kit.key(self, KEY_ESCAPE)
	await Kit.mouse(self, eq._slot_rows["shield"])
	await _shot("fb11_picker_empty")
	await Kit.key(self, KEY_ESCAPE)

	# 12: Tutorial list and the setting.
	await Kit.mouse(self, menu.misc_button)
	await Kit.frames(self, 6)
	await Kit.mouse(self, layer.active_modal.tutorial_button)
	await _shot("fb12_tutorial_list")
	await Kit.mouse(self, menu.misc_button)
	await Kit.frames(self, 6)
	await Kit.mouse(self, layer.active_modal.settings_button)
	var options: Node = menu.find_child("OptionsComponent", true, false)
	options.switch_to_tab("game")
	await _shot("fb12_settings_tutorial_windows")

	# 13: Journal sections (hints as banners here, so no window covers the menu).
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false
	ui.close_game_menu()
	await Kit.frames(self, 6)
	sl.get_dialogue_manager().start_dialogue("res://dialogue_quest/OldMan_Outside.dqd")
	await Kit.frames(self, 4)
	await Kit.drain(self)
	for kind in ["melee", "fast"]:
		var enemy: Node = load("res://SampleProject/Scenes/Characters/Enemies/%s.tscn" % ("default_enemy" if kind == "melee" else "enemy_" + kind)).instantiate()
		enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_%s.tres" % kind)
		enemy.position = game.player.position + Vector2(900, -40)
		game.map.add_child(enemy)
		await Kit.frames(self, 3)
		if kind == "melee":
			enemy.take_damage(99999)
	await Kit.frames(self, 30)
	ui.open_game_menu()
	await Kit.frames(self, 16)
	menu = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Journal")
	var journal: Node = menu.find_child("JournalComponent", true, false)
	await _shot("fb13_quests")
	await Kit.mouse(self, journal.get_node("%CharactersTab"))
	await _shot("fb13_characters")
	await Kit.mouse(self, journal.get_node("%BestiaryTab"))
	await _shot("fb13_bestiary")
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = true
	quit()
