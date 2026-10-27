extends SceneTree

## Кажани печери ящурів (D774, ambient_critters_plan slice 1): друга висить під корінням, перша щойно злетіла від
## героя. Потрібне вікно:
##   godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_ambient_critters.gd
## Файл: design/shots/ambient_critters_cave.png

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const Critter = preload("res://SampleProject/Scripts/Gameplay/AmbientCritter.gd")
const OUT := "res://design/shots/ambient_critters_cave.png"


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	root.get_node("SaveSystem").set_save_dir("user://capture_ambient_critters/")
	var game: Node = await Kit.boot(self)
	Critter.left_at.clear()
	await game.teleport_to_room("res://SampleProject/Maps/LizardCave.tscn", ^"ExitDoor")
	await Kit.frames(self, 20)
	await Kit.drain(self)
	for n: Node in game.map.get_children():
		if String(n.name).begins_with("Fight_"):
			n.free()
	var near: Node2D = game.map.get_node(^"FrontDark/Bat1")
	# Друга лишається сидіти для кадру: герой проходить під нею з правого боку до першої.
	(game.map.get_node(^"FrontDark/Bat2") as Node2D).set(&"scare_distance", 0.0)
	game.place_player(Vector2(near.global_position.x + 330.0, game.player.global_position.y))
	await Kit.frames(self, 60)
	Input.action_press(&"move_left")
	while not near.is_flying():
		await physics_frame
	Input.action_release(&"move_left")
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("saved " + OUT)
	quit()
