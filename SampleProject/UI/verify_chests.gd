extends SceneTree

## Chests (BACKLOG 33, D88 path 3, design/chests_plan.md) in the real game:
##   1. The bandits' stash on the DesertRoad watchtower holds a closed chest (D583; its cage opened with the bandit
##      key — verify_gates walks the key itself) with an "Open" prompt.
##   2. Open it with the keyboard (the E key event the interact action is bound to): the lid opens (Closed → Opening →
##      Open), the hero is held in Chest.HERO_POSE with the found item's icon above his head, the contents land in the
##      bag, then the "You obtained:" modal; a pad A closes it and the hero walks again.
##   3. A room reload: the chest stays open, nothing is offered, interact gives nothing.
##   4. Save → load: still open.
##   5. Open a chest with the pad button the interact action is bound to; a mouse click on OK closes the modal.
## Writes only to user://verify_chests/.
##   godot --headless --path . --script res://SampleProject/UI/verify_chests.gd

const ROAD := "res://SampleProject/Maps/DesertRoad.tscn"
const CHEST_SCENE := "res://SampleProject/Objects/Chest.tscn"
## Остання поза HERO_POSE — руки над головою (B91).
const RAISED := preload("res://SampleProject/Sprites/Player/Raise/3.png")
const TEST_DIR := "user://verify_chests/"
const TEST_SLOT := 1
## On top of the watchtower (Ledge_TowerTop, top y 158) beside the stash; the hero's origin is 24 px above his feet.
const LEDGE_SPOT := Vector2(2420.0, 134.0)

var fails: Array[String] = []
var sl: Node
var inventory: Node
var layer: Node


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _boot() -> Node:
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 60: await physics_frame
	return game


func _bound_event(cls: String) -> InputEvent:
	for ev: InputEvent in InputMap.action_get_events(&"interact"):
		if ev.is_class(cls):
			return ev
	return null


## A real press and release of the key / pad button the interact action is bound to.
func _press(template: InputEvent) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEvent = template.duplicate()
		ev.pressed = pressed
		if ev is InputEventJoypadButton:
			ev.device = 0
		Input.parse_input_event(ev)
		await process_frame


func _pad_accept() -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = JOY_BUTTON_A
		ev.device = 0
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame


func _click(control: Control) -> void:
	# The modal sits on a CanvasLayer: its canvas transform maps the button into viewport coordinates.
	var at := control.get_global_transform_with_canvas() * (control.size / 2.0)
	var vp := control.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	vp.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.global_position = at
		ev.pressed = pressed
		vp.push_input(ev, true)
		await process_frame


func _stand(player: CharacterBody2D, at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	for i in 20: await physics_frame


## Opens [param chest] with [param press] and follows the sequence; returns [sprite animations seen, pose seen,
## icon shown above the hero, movement held during the raise].
func _open(game: Node, chest: Node, press: InputEvent) -> Array:
	var player: CharacterBody2D = game.player
	var sprite: AnimatedSprite2D = chest.get_node("Sprite")
	var found: Sprite2D = chest.get_node("Found")
	var anim: AnimationPlayer = player.get_node("AnimationPlayer")
	var seen := {}
	var pose_ok := false
	var icon_ok := false
	var held := false
	await _press(press)
	for i in 240:
		seen[sprite.animation] = true
		if found.visible:
			icon_ok = found.texture != null and found.global_position.y < player.global_position.y - 40.0 \
					and absf(found.global_position.x - player.global_position.x) < 1.0
			# Raise не циклічна: остання поза тримається, тож питаємо assigned_animation, а не current_animation.
			pose_ok = anim.assigned_animation == chest.HERO_POSE and player.get_node("Sprite2D").texture == RAISED
			held = player.event
		if layer.active_modal:
			break
		await process_frame
	return [seen, pose_ok, icon_ok, held]


func _initialize() -> void:
	await process_frame
	await process_frame
	sl = root.get_node("ServiceLocator")
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false  # D289: hints as banners, no window pauses the game
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(TEST_SLOT)
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	inventory = sl.get_inventory_manager()
	layer = sl.get_ui_manager().get_modal_layer()
	var db: Node = sl.get_item_database()
	var key: InputEvent = _bound_event("InputEventKey")
	var pad: InputEvent = _bound_event("InputEventJoypadButton")
	ck(key != null and pad != null, "interact is bound to a key and a pad button")

	set_meta("start_new_game", true)
	var game: Node = await _boot()
	for flag in ["desert_road_fight_complete"]:
		game.set_quest_flag(flag, true)
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	var player: CharacterBody2D = game.player

	print("[1] The watchtower stash holds a closed chest")
	var chest: Node = game.map.get_node_or_null("Chest_TowerStash")
	ck(chest != null and chest.scene_file_path == CHEST_SCENE, "Chest_TowerStash is a Chest.tscn")
	ck(game.map.get_node_or_null("Chest_CaravanLedge") == null, "the old caravan-ledge chest is gone (D583)")
	inventory.add_item("bandit_key", 1)
	game.map.get_node("Cage_TowerStash/Area/Interactable").interacted.emit()  # ключ відмикає ґрати
	await create_timer(0.5).timeout
	if chest == null:
		_finish()
		return
	ck(chest.contents == {"mana_crystal": 2}, "it holds Mana Crystal × 2 (%s)" % chest.contents)
	ck(chest.get_node("Sprite").animation == &"closed" and not chest.is_open, "it starts closed")
	await _stand(player, LEDGE_SPOT)
	ck(player.is_on_floor() and absf(player.global_position.y - LEDGE_SPOT.y) < 4.0,
			"the hero stands on the ledge beside it (%.0f, %.0f)" % [player.global_position.x, player.global_position.y])
	var interactable: Node = chest.get_node("Interactable")
	ck(interactable.player_nearby and interactable.get_prompt().visible and interactable.get_prompt().action_text == "Open",
			"the prompt says \"Open\"")

	print("[2] Open it with the key")
	var before: int = inventory.get_item_count("mana_crystal")
	var r: Array = await _open(game, chest, key)
	ck(r[0].has(&"opening") and chest.get_node("Sprite").animation == &"open", "the lid opens: %s → open" % [r[0].keys()])
	ck(r[1], "the hero holds the %s pose (Raise/3, arms overhead) while the item is up" % chest.HERO_POSE)
	ck(r[2], "the Mana Crystal icon shows above his head")
	ck(r[3], "he cannot move during the raise")
	ck(inventory.get_item_count("mana_crystal") == before + 2, "Mana Crystal × 2 in the bag (%d → %d)" % [before, inventory.get_item_count("mana_crystal")])
	var modal: Control = layer.active_modal
	ck(modal != null and modal.description_label.text == "%s × 2" % db.get_item_name("mana_crystal"),
			"the \"You obtained:\" modal lists it (%s)" % (modal.description_label.text if modal else "no modal"))
	ck(not chest.get_node("Found").visible, "the icon is gone when the modal opens")
	if modal:
		await _pad_accept()
		for i in 4: await process_frame
	ck(layer.active_modal == null, "pad A closes the modal")
	ck(not player.event, "the hero walks again")
	await _press(key)
	for i in 4: await process_frame
	ck(inventory.get_item_count("mana_crystal") == before + 2 and layer.active_modal == null, "a second press gives nothing")

	print("[3] A room reload keeps it open")
	await game.teleport_to_room(ROAD, ^"Arrival_Start")
	for i in 20: await physics_frame
	chest = game.map.get_node("Chest_TowerStash")
	await _stand(player, LEDGE_SPOT)
	ck(chest.is_open and chest.get_node("Sprite").animation == &"open", "the chest is open after the reload")
	ck(not chest.get_node("Interactable").enabled and not chest.get_node("Interactable").get_prompt().visible, "no prompt")
	await _press(key)
	for i in 30: await process_frame
	ck(inventory.get_item_count("mana_crystal") == before + 2 and layer.active_modal == null, "interact gives nothing")

	print("[4] Save → load keeps it open")
	ck(game.save_game(), "saved to slot %d" % TEST_SLOT)
	game.queue_free()
	for i in 4: await process_frame
	set_meta("start_new_game", false)
	set_meta("save_file_path", save_system.get_slot_path(TEST_SLOT))
	game = await _boot()
	player = game.player
	ck(game.map.scene_file_path == ROAD, "loaded on the Desert Road (%s)" % game.map.scene_file_path)
	chest = game.map.get_node_or_null("Chest_TowerStash")
	ck(chest != null and chest.is_open and chest.get_node("Sprite").animation == &"open", "the chest is open after the load")
	ck(inventory.get_item_count("mana_crystal") == before + 2, "the crystals are still in the bag (%d)" % inventory.get_item_count("mana_crystal"))

	print("[5] Open one with the pad; the mouse closes the modal")
	var pad_chest: Node = load(CHEST_SCENE).instantiate()
	pad_chest.persistent = false
	var two: Dictionary[String, int] = {"herb": 1, "mana_crystal": 1}
	pad_chest.contents = two
	game.map.add_child(pad_chest)
	pad_chest.global_position = LEDGE_SPOT + Vector2(0.0, 24.0)  # на тому ж уступі, що й герой
	await _stand(player, LEDGE_SPOT)
	var herbs: int = inventory.get_item_count("herb")
	r = await _open(game, pad_chest, pad)
	ck(r[0].has(&"opening") and pad_chest.is_open, "the pad button opens it")
	ck(r[1] and r[2], "pose and icon as with the key")
	ck(inventory.get_item_count("herb") == herbs + 1, "the herb lands in the bag")
	modal = layer.active_modal
	ck(modal != null and modal.description_label.text == "%s × 1\n%s × 1" % [db.get_item_name("herb"), db.get_item_name("mana_crystal")],
			"two items, one line each (%s)" % (modal.description_label.text.replace("\n", " / ") if modal else "no modal"))
	var ok_button: Control = modal.get_viewport().gui_get_focus_owner() if modal else null
	ck(ok_button is BaseButton and ok_button.is_visible_in_tree(), "the OK button has focus")
	if ok_button:
		await _click(ok_button)
		for i in 4: await process_frame
	ck(layer.active_modal == null, "a click on OK closes the modal")
	_finish()


func _finish() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
	DirAccess.remove_absolute(TEST_DIR)
	save_system.set_save_dir(save_system.SAVE_DIR)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()
