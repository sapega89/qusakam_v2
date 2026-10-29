extends SceneTree

## Режим розробника (D943, design/dev_menu_plan.md slice 1) у справжній грі:
##   1. F10 відкриває меню й ставить гру на паузу; F10 ще раз — закриває й знімає паузу.
##   2. «+100 / +1000 gold» додають гроші.
##   3. «God mode» — удар ворога не знімає HP; вимкнено — знімає.
##   4. «Full HP» — здоровʼя повне.
##   godot --headless --path . --script res://SampleProject/UI/verify_dev_menu.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _f10() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F10
	ev.pressed = true
	root.push_input(ev)
	await process_frame

func _initialize() -> void:
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	for i in 400:
		if not dm.is_dialogue_active():
			break
		dm.current_dialogue_box.finish()
		dm.current_dialogue_player.accept()
		await process_frame
	var menu: Control = game.get_node("UICanvas/DevMenu")
	var hero: Node = game.player

	print("[1] F10 opens and closes it")
	ck(not menu.visible, "hidden at the start")
	await _f10()
	ck(menu.visible and paused, "F10: open, the game paused (visible %s, paused %s)" % [menu.visible, paused])
	await _f10()
	ck(not menu.visible and not paused, "F10 again: closed, unpaused")

	print("[2] Gold")
	var inventory: Node = sl.get_inventory_manager()
	var coins: int = inventory.get_coins()
	menu.get_node("%Gold100").pressed.emit()
	menu.get_node("%Gold1000").pressed.emit()
	ck(inventory.get_coins() == coins + 1100, "+100 and +1000 gold (%d → %d)" % [coins, inventory.get_coins()])

	print("[3] God mode")
	hero.restore_health(hero.Max_Health)
	menu.get_node("%God").pressed.emit()
	await create_timer(hero.invulnerability_duration + 0.1).timeout
	hero.take_damage(20)
	ck(hero.dev_god and hero.current_health == hero.Max_Health, "on: a hit takes no HP (%d / %d)" % [hero.current_health, hero.Max_Health])
	ck(menu.get_node("%God").text == TranslationServer.translate("God mode: ON"), "the button says ON (%s)" % menu.get_node("%God").text)
	menu.get_node("%God").pressed.emit()
	await create_timer(hero.invulnerability_duration + 0.1).timeout
	hero.take_damage(20)
	ck(not hero.dev_god and hero.current_health < hero.Max_Health, "off: a hit hurts again (%d / %d)" % [hero.current_health, hero.Max_Health])

	print("[4] Full HP")
	menu.get_node("%FullHp").pressed.emit()
	ck(hero.current_health == hero.Max_Health, "Full HP (%d / %d)" % [hero.current_health, hero.Max_Health])

	print("[5] The console line runs any GDScript expression")
	menu.run("ServiceLocator.get_inventory_manager().add_coins(7)")
	ck(inventory.get_coins() == coins + 1107, "ServiceLocator.…add_coins(7) adds 7 (%d)" % inventory.get_coins())
	ck(menu.run("player.Max_Health") == hero.Max_Health, "player.Max_Health reads the hero (%s)" % menu.get_node("%ConsoleOut").text)
	menu.run("no_such_thing.foo()")
	ck(menu.get_node("%ConsoleOut").text != "", "a bad line shows its error (%s)" % menu.get_node("%ConsoleOut").text)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
