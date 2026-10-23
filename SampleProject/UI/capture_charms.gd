extends SceneTree

## Секція CHARMS у Equipment (D592) і вікно вибору оберега — у design/shots/charms/:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_charms.gd
## Потрібне вікно (headless малює чорне).

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const DIR := "res://design/shots/charms"


func _shot(name: String) -> void:
	await Kit.frames(self, 8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [DIR, name]))
	print("shot %s" % name)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	await process_frame
	await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	var layer: Node = ui.get_modal_layer()
	for i in 20:
		if layer.active_modal == null:
			break
		layer._close_with_result("confirm", layer.active_modal)
		await Kit.frames(self, 4)
	var charms: GDScript = load("res://SampleProject/Scripts/Systems/Charms.gd")
	for charm_id in charms.all_ids():
		charms.grant(charm_id)
	charms.equip(0, "grandfathers_ring")
	charms.equip(1, "breaker_ring")
	sl.get_inventory_manager().add_item("iron_armor", 1)
	sl.get_inventory_manager().add_item("iron_sword", 1)
	ui.open_game_menu()
	await Kit.frames(self, 16)
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Equipment")
	await Kit.frames(self, 4)
	var eq: Node = menu.find_child("EquipmentComponent", true, false)
	eq._equip("body", "iron_armor", sl.get_item_database().get_item("iron_armor"))
	eq._equip("sword", "iron_sword", sl.get_item_database().get_item("iron_sword"))
	await Kit.frames(self, 4)
	eq._charm_rows[2].grab_focus()
	await _shot("equipment_charms")
	eq._charm_rows[0].grab_focus()
	await Kit.frames(self, 4)
	eq._on_charm_pressed(0)
	await _shot("charm_picker")
	quit(0)
