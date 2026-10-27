extends RefCounted

## Shared helpers for the verify_*.gd scripts that drive real input (BACKLOG 9–13, item 24 rule):
## boot the game past the Canyon intro, then mouse clicks, keys and gamepad buttons through the viewport.
##   const Kit = preload("res://SampleProject/UI/input_kit.gd")
##   var game: Node = await Kit.boot(self)


## New game, Canyon intro talk drained; the root sized to 1920×1080 so clicks land where they are drawn.
static func boot(tree: SceneTree) -> Node:
	await tree.process_frame
	await tree.process_frame
	tree.root.size = Vector2i(1920, 1080)
	tree.set_meta("start_new_game", true)
	var sl: Node = tree.root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	tree.root.add_child(game)
	tree.current_scene = game
	await frames(tree, 40)
	await drain(tree)
	return game


## D815: a New Game hero starts with Shield Block and Healing Palm, asleep until the Canyon meditation. A test about
## buying skills and counting JP takes them away again — the hero as before D815: nothing learned, empty hotbar, awake.
static func pre_d815_hero(tree: SceneTree) -> void:
	var sm: Node = tree.root.get_node("ServiceLocator").get_skill_manager()
	var state: Dictionary = tree.root.get_node("ServiceLocator").get_game_manager().player_state
	state.unlocked_skills = []
	state.skill_ranks = {}
	state.starting_skills = []
	state.skills_awakened = true
	var empty: Array = []
	empty.resize(sm.SLOT_COUNT)
	empty.fill("")
	sm._commit_loadout(empty)


static func drain(tree: SceneTree) -> void:
	var dm: Node = tree.root.get_node("ServiceLocator").get_dialogue_manager()
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await tree.process_frame
		await frames(tree, 10)
		if not dm.is_dialogue_active():
			return


static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


static func mouse(tree: SceneTree, node: Control, double: bool = false) -> void:
	var vp: Viewport = node.get_viewport()
	var pos: Vector2 = node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await tree.process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.double_click = double and pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await tree.process_frame
	await frames(tree, 3)


static func key(tree: SceneTree, keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		tree.root.push_input(ev)
		await tree.process_frame
	await frames(tree, 3)


static func pad(tree: SceneTree, button: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		tree.root.push_input(ev)
		await tree.process_frame
	await frames(tree, 3)


static func modal_text(tree: SceneTree) -> String:
	var modal: Node = tree.root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal
	if modal == null:
		return ""
	return " ".join(modal.find_children("*", "Label", true, false).filter(
			func(l: Label) -> bool: return l.is_visible_in_tree()).map(func(l: Label) -> String: return l.text))
