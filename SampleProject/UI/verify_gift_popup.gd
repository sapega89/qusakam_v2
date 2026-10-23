extends SceneTree

## Що герою дали й що він підібрав (BACKLOG 33, без скрині): дарунок діда (D129) і нагорода / видача завдання
## відкривають модалку «You obtained:» — коли розмова скінчилась, не посеред неї; закривається Enter, падом A або
## кліком. Убитий справжнім ударом (пад X) моб дає тост здобичі на HUD: монети складаються в один тост, тост гасне.
##   godot --headless --path . --script res://SampleProject/UI/verify_gift_popup.gd

var fails: Array[String] = []
var tokens: GDScript = load("res://SampleProject/UI/Tokens/UITokens.gd")

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


## Проклацує діалоги до кінця; true — поки вони йшли, модалка дарунка не з'являлась.
func _drain(dm: Node, layer: Node) -> bool:
	var clean := true
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			clean = clean and layer.active_modal == null
			if dm.is_replaying():
				dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
				root.get_node("DialogueQuest").Inputs.accept_pressed.emit()
			else:
				dm.current_dialogue_box.finish()
				dm.current_dialogue_player.accept()
			for f in 3: await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			break
	return clean


func _tap(event: InputEvent) -> void:
	event.set(&"pressed", true)
	Input.parse_input_event(event)
	for i in 3: await process_frame
	var release: InputEvent = event.duplicate()
	release.set(&"pressed", false)
	Input.parse_input_event(release)
	for i in 4: await process_frame


func _modal_text(layer: Node) -> String:
	if layer.active_modal == null:
		return ""
	return "%s|%s" % [layer.active_modal.title_label.text, layer.active_modal.description_label.text]


func _initialize() -> void:
	await process_frame
	await process_frame
	# Headless скидає вікно до 64×64 (verify_misc_destinations) — клік мишею по кнопці модалки міряє 1920×1080.
	root.size = Vector2i(1920, 1080)
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0  # облачка (D178) без очікування
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	var ui: Node = sl.get_ui_manager()
	var layer: Node = ui.get_modal_layer()
	var inv: Node = sl.get_inventory_manager()
	await _drain(dm, layer)  # вступ Canyon

	print("[1] A mob killed by a real attack (pad X) adds a loot toast that stacks and fades")
	game.set_quest_flag("desert_road_monologue_complete", true)
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _drain(dm, layer)  # репліка перед боєм
	await create_timer(2.5).timeout
	var enemies: Array = []
	for node: Node in game.map.find_children("*", "CharacterBody2D", true, false):
		if node.is_in_group(&"enemies"):
			enemies.append(node)
	ck(not enemies.is_empty(), "the road fight spawned enemies (%d)" % enemies.size())
	for e: Node in enemies:
		e.set_physics_process(false)
	while enemies.any(func(e: Node) -> bool: return e.enemy_logic.is_attacking) or game.player.combat.owns_animation():
		await physics_frame
	await create_timer(0.6).timeout
	var feed: Node = get_first_node_in_group(&"loot_feed")
	ck(feed != null and feed.toasts().is_empty(), "no toast before the kill")
	var victim: Node = enemies[0]
	victim.current_health = 1
	game.player.global_position = victim.global_position + Vector2(-26, 0)
	game.player.velocity = Vector2.ZERO
	game.player.current_health = game.player.Max_Health
	await create_timer(0.05).timeout
	var coins_before: int = inv.get_item_count("coin")
	var pad_x := InputEventJoypadButton.new()
	pad_x.button_index = JOY_BUTTON_X
	await _tap(pad_x)
	await create_timer(0.6).timeout
	ck(not victim.is_alive(), "pad X killed the mob")
	await create_timer(1.5).timeout  # монети летять до героя
	var gained: int = inv.get_item_count("coin") - coins_before
	var toasts: Array = feed.toasts()
	ck(gained > 0, "coins picked up from the mob (%d)" % gained)
	ck(toasts.size() == 1, "one toast for all its coins (%d)" % toasts.size())
	if toasts.size() == 1:
		var text: String = (toasts[0].get_node(^"Row/Text") as Label).text
		ck(text == "Coin × %d" % gained, "the toast sums them (%s, gained %d)" % [text, gained])
		ck(toasts[0].is_visible_in_tree() and toasts[0].modulate.a > 0.5, "the toast is shown on the HUD")
	ck(layer.active_modal == null and not ui.has_pending_obtained(), "mob loot opens no popup")
	feed.add_loot("iron_ingot", 1)
	ck(feed.toasts().size() == 2 and feed.toasts()[0].get_meta(&"item_id") == "iron_ingot", "another item stacks as a new toast on top")
	for i in tokens.LOOT_FEED_MAX + 2:
		feed.add_loot("drop_%d" % i, 1)
	for i in 2: await process_frame
	ck(feed.toasts().size() == tokens.LOOT_FEED_MAX, "at most %d toasts (%d)" % [tokens.LOOT_FEED_MAX, feed.toasts().size()])
	await create_timer(tokens.LOOT_TOAST_HOLD + tokens.LOOT_TOAST_FADE * 2.0 + 0.5).timeout
	ck(feed.toasts().is_empty(), "the toasts fade away")

	print("[2] The grandfather's gift (D129) opens 'You obtained:' after the talks, Enter closes it")
	var flags: Dictionary = game.get_quest_flags().duplicate()
	flags["village_fight_complete"] = true
	game.set_quest_flags(flags)
	var village: Node = load("res://SampleProject/Maps/Village.tscn").instantiate()
	root.add_child(village)
	for i in 4: await process_frame
	village.change_state_by_name("OLD_MAN_HEALING")
	for i in 4: await process_frame
	var clean: bool = await _drain(dm, layer)
	ck(clean, "no popup while the talks run")
	for i in 6: await process_frame
	ck(inv.get_item_count("copper_sword") == 1 and inv.get_item_count("leather_armor") == 1, "the gift is in the bag")
	ck(_modal_text(layer) == "You obtained:|Copper Sword × 1\nLeather Armor × 1", "the popup lists the gift (%s)" % _modal_text(layer).c_escape())
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	await _tap(enter)
	ck(layer.active_modal == null and not ui.has_pending_obtained(), "Enter closes it, nothing else pending")
	village.queue_free()
	for i in 4: await process_frame

	print("[3] A task reward and a task's hand-out open the popup; pad A and a click close it")
	var smith: Node = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/blacksmith.tscn").instantiate()
	game.add_child(smith)
	await process_frame
	smith.interactable.interacted.emit()
	await process_frame
	smith.npc_menu.chosen.emit(&"task")
	await _drain(dm, layer)  # «Шолом» узято — нічого не дано, модалки немає
	for i in 6: await process_frame
	ck(layer.active_modal == null, "taking a task that gives nothing opens no popup")
	inv.add_item("iron_helmet", 1)
	smith.interactable.interacted.emit()
	await process_frame
	smith.npc_menu.chosen.emit(&"task")
	clean = await _drain(dm, layer)
	for i in 6: await process_frame
	ck(clean and game.get_quest_flag("task_smith_helmet_done"), "the helmet turned in, no popup during the talk")
	ck(_modal_text(layer) == "You obtained:|Coin × 88", "the reward popup (%s)" % _modal_text(layer).c_escape())
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	await _tap(pad_a)
	ck(layer.active_modal == null, "pad A closes it")
	smith.interactable.interacted.emit()
	await process_frame
	smith.npc_menu.chosen.emit(&"task")
	await _drain(dm, layer)
	for i in 6: await process_frame
	ck(_modal_text(layer) == "You obtained:|Iron Sword × 2", "the hand-out popup of 'Enchanting' (%s)" % _modal_text(layer).c_escape())
	if layer.active_modal != null:
		var button: Button = layer.active_modal.buttons_container.get_children().filter(
				func(b: Node) -> bool: return b is Button and b.visible)[0]
		var pos: Vector2 = button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = pos
		motion.global_position = pos
		root.push_input(motion)
		await process_frame
		for pressed: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = pos
			click.global_position = pos
			root.push_input(click)
			await process_frame
		for i in 4: await process_frame
	ck(layer.active_modal == null, "a click on OK closes it")
	smith.queue_free()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
