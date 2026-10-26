extends SceneTree

## Текст у грі ×1.5 (D474) і хотбар без зброї (D475): HUD, меню NPC, вікно діалогу, вікно й плашка туторіалу.
## Потрібне ВІКНО. Мітка знімків — після «--» (before / after):
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_ui_text.gd -- after
## → design/shots/ui_text/<поверхня>_<мітка>.png. Нова гра без сейву — справжні сейви не чіпаються.

const MERCHANT := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/merchant.tscn"

var _tag := "after"


func _shot(name: String) -> void:
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://design/shots/ui_text/%s_%s.png" % [name, _tag]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("capture saved: " + path)


func _drain(dm: Node) -> void:
	for i in 600:
		if not dm.is_dialogue_active():
			return
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_tag = args[0]
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var dm: Node = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 120:
		await process_frame
	await _drain(dm)
	# Перша тема (рух) відкриває вікно туторіалу за 2 с — знімаємо його як вікно туторіалу.
	var layer: ModalLayer = sl.get_ui_manager().get_modal_layer()
	for i in 600:
		if layer.active_modal != null:
			break
		await process_frame
	await _shot("tutorial_window")
	layer.active_modal.cancelled.emit()
	for i in 30:
		await process_frame
	await _drain(dm)
	await _shot("hud")

	var tray: Node = get_first_node_in_group(&"tip_tray")
	tray.show_tip("oldman_gift")  # D744: плашки немає — підказка лише «?»
	await _shot("tutorial_tip")
	tray.clear()

	var player: Node2D = game.player
	var npc: Node2D = load(MERCHANT).instantiate()
	npc.talk_dialogue = "res://dialogue_quest/OldMan_Decision.dqd"
	game.add_child(npc)
	npc.global_position = player.global_position + Vector2(-140, 0)
	await process_frame
	npc.interactable.interacted.emit()
	await _shot("npc_menu")
	npc.npc_menu.cancelled.emit()
	await process_frame

	dm.start_dialogue("res://dialogue_quest/OldMan_Decision.dqd")
	for i in 30:
		await process_frame
	dm.current_dialogue_box.finish()
	await _shot("dialogue_box")
	quit(0)
