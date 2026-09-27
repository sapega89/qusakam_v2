extends SceneTree

## Візуальний знімок slice 3: Merchant і Blacksmith з артом Figma, підказками та меню.
##   godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_npcs.gd


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	var bg := ColorRect.new()
	bg.color = UITokens.SHOP_PANEL_BG
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player := CharacterBody2D.new()
	player.add_to_group(GameGroups.PLAYER)
	world.add_child(player)

	var merchant: NpcBase = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/merchant.tscn").instantiate()
	merchant.position = Vector2(600, 620)
	world.add_child(merchant)
	var smith: NpcBase = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/blacksmith.tscn").instantiate()
	smith.position = Vector2(1200, 620)
	smith.talk_dialogue = "preview"  # лише для знімка: показати меню
	world.add_child(smith)
	await process_frame
	merchant.interactable._on_body_entered(player)
	smith.refresh_availability()
	smith.interactable.interacted.emit()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://design/shots/npcs_1920.png"))
	print("capture saved: res://design/shots/npcs_1920.png")
	quit(0)
