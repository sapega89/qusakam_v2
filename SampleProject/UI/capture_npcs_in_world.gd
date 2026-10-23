extends SceneTree

## NPC у своїх кімнатах під камерою гри: чи стоять на підлозі й якого вони розміру.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_npcs_in_world.gd

const SPOTS := [
	["res://SampleProject/Maps/DesertRoad.tscn", ^"Merchant", "npc_world_merchant"],
	["res://SampleProject/Maps/City.tscn", ^"Blacksmith", "npc_world_blacksmith"],
	["res://SampleProject/Maps/Village.tscn", ^"OldManQuest", "npc_world_oldman"],
]


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	for spot in SPOTS:
		await game.teleport_to_room(spot[0], spot[1])
		for i in 90: await physics_frame
		for i in 300:
			if not dm.is_dialogue_active(): break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		var npc: Node2D = game.map.get_node(spot[1])
		var player: Node2D = game.player
		player.global_position.x = npc.global_position.x - 120
		for i in 60: await physics_frame
		print("%s: npc y=%.1f player y=%.1f on_floor=%s" % [spot[2], npc.global_position.y, player.global_position.y, player.is_on_floor()])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://design/shots/%s.png" % spot[2]))
	# Ворог зі смужкою HP (D170: смужка над головою під збільшеною камерою).
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Merchant")
	for i in 60: await physics_frame
	game.map.get_node("EnemySpawner").spawn_all_enemies()
	for i in 30: await physics_frame
	var enemies := get_nodes_in_group(&"enemies")
	print("enemies: %d" % enemies.size())
	if not enemies.is_empty():
		game.player.global_position = enemies[0].global_position + Vector2(-200, -40)
		for i in 20: await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://design/shots/npc_world_enemy.png"))
	quit(0)
