extends SceneTree

## Візуальний знімок slice 1a для порівняння з Figma (не тест, вікно обов'язкове):
##   godot --path . --script res://SampleProject/UI/capture_interaction.gd
## Зберігає design/shots/interaction_prompt_1920.png і item_pickup_modal_1920.png.

const OUT_PROMPT := "res://design/shots/interaction_prompt_1920.png"
const OUT_MODAL := "res://design/shots/item_pickup_modal_1920.png"


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var bg := ColorRect.new()
	bg.color = UITokens.BACKGROUND
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)

	var scene: PackedScene = load("res://SampleProject/UI/Components/interaction_prompt.tscn")
	var specs := [
		["Pick up", InteractionPrompt.State.DEFAULT, Vector2(200, 200)],
		["Save", InteractionPrompt.State.FOCUSED, Vector2(200, 280)],
		["Talk", InteractionPrompt.State.DISABLED, Vector2(200, 360)],
		["Examine the relic", InteractionPrompt.State.DEFAULT, Vector2(200, 440)],
	]
	for spec in specs:
		var p: InteractionPrompt = scene.instantiate()
		p.action_text = spec[0]
		p.state = spec[1]
		p.position = spec[2]
		root.add_child(p)

	await _save(OUT_PROMPT)

	# Реальні дані предмета з ItemDatabase — нічого не вигадуємо.
	var sl: Node = root.get_node("ServiceLocator")
	var item_name: String = sl.get_item_database().get_item_name("potion")
	sl.get_ui_manager().show_modal(ModalTemplates.item_pickup(item_name, 2))
	await _save(OUT_MODAL)
	quit(0)


func _save(path: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("capture saved: %s (err=%d, %dx%d)" % [path, err, img.get_width(), img.get_height()])
