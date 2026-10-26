extends SceneTree

## Реакції NPC у кат-сцені (D460, Cutscene.react) — кадр у камерах лабораторії: «!», «?», «…», крапля поту, біль.
## Потрібне вікно:
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_cutscene_react.gd -- <out_dir>
## Файли: <out_dir>/cutscene_react_a.png (Астрит «!», Алісія — біль, алхімік «…»), _b.png (Уризен «?», Малік — страх)

## load(), не preload: Cutscene.gd знає autoload-и, а скрипт компілюється ще до них.
const CUTSCENE := "res://SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd"

var game: Node
var dm: Node

func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	await process_frame
	set_meta("start_new_game", true)
	dm = root.get_node("ServiceLocator").get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain()
	game.set_quest_flag("lab_cells_cutscene_complete", true)  # AWAKE: усі в камерах, кат-сцена не грає
	await game.teleport_to_room("res://SampleProject/Maps/LabCells.tscn", ^"Arrival")
	for i in 60: await physics_frame
	await _drain()
	var cells: Node = game.map
	var scientist: Node2D = cells.get_node(^"Scientist")
	scientist.show()
	scientist.global_position = Vector2(900, 384)
	var cs: RefCounted = load(CUTSCENE).new()
	await cs.pan_to(Vector2(700, 280), 0.1)
	cs.react(cells.get_node(^"CompanionNPC_astrit"), &"surprise")
	cs.react(scientist, &"silence")
	await create_timer(0.12).timeout
	cs.react(cells.get_node(^"CompanionNPC_alisia"), &"pain")
	await process_frame  # спалах болю — 0.3 с, а кадр під xvfb довгий: знімаємо одразу
	root.get_texture().get_image().save_png("%s/cutscene_react_a.png" % out_dir)
	await create_timer(1.5).timeout
	await cs.pan_to(Vector2(1250, 280), 0.1)
	cs.react(cells.get_node(^"CompanionNPC_urizen"), &"confusion")
	cs.react(cells.get_node(^"Malik"), &"fear")
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("%s/cutscene_react_b.png" % out_dir)
	quit()

func _drain() -> void:
	for i in 400:
		if not dm.is_dialogue_active():
			for f in 10: await process_frame
			if not dm.is_dialogue_active():
				return
		else:
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
		await process_frame
