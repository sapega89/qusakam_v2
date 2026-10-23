extends SceneTree

## Асисти компаньйонів ([[companion_assist_plan]], D209, D464) у справжній грі на DesertRoad: хто відкритий —
## з прапорців лабораторії, у загін — лише вибрані гравцем; одна кнопка кличе наступного готового з вибраних;
## кожен робить своє (стріла Алісії в найдальшого, оглушення щитом Астрит, ланцюг монети Уризена на 3,
## відкидання охоронця) з ефектами D465 і прибирає себе; кулдаун у кожного свій. Туторіал вибору — D463.
##   godot --headless --path . --script res://SampleProject/UI/verify_companions.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254: тест не чекає набору репліки
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

## Слот асисту на хотбарі (зріз 4): видно? чий портрет? залишок кулдауну?
func _hud() -> Array:
	var bind: Control = get_first_node_in_group(&"skill_hotbar").get_node(^"%SlotsRow/AssistBind")
	var portrait: Texture2D = bind.get_node(^"Slot/Portrait").texture
	var overlay: Label = bind.get_node(^"Slot/Cooldown")
	var who := "" if portrait == null else portrait.resource_path.get_base_dir().get_file()
	return [bind.is_visible_in_tree(), who, overlay.text if overlay.visible else ""]

func _actors() -> Array:
	return get_nodes_in_group(&"companions")

## Ефекти асистів (D465), що з'явились у кімнаті з останнього _fx.clear(): імена сцен.
var _fx: Array[String] = []

func _fx_count(scene: String) -> int:
	return _fx.count(scene)

func _stars(enemy: Node) -> bool:
	return enemy.get_node_or_null(^"StunStars") != null

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.tutorial_windows = false  # D289: hints as banners, the game never pauses under a window
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	await _drain(sl.get_dialogue_manager())
	await game.teleport_to_room("res://SampleProject/Maps/DesertRoad.tscn", ^"Arrival_Start")
	for i in 16: await process_frame
	await _drain(sl.get_dialogue_manager())
	await create_timer(2.5).timeout
	var enemies: Array = game.map.find_children("*", "CharacterBody2D", true, false).filter(
			func(n: Node) -> bool: return n.is_in_group(&"enemies"))
	var hero: Node2D = game.player
	hero.mover.last_direction = 1
	for i in enemies.size():  # стоять у ряд перед героєм, не рухаються й не б'ють
		enemies[i].set_physics_process(false)
		enemies[i].global_position = Vector2(hero.global_position.x + 60 + i * 50, enemies[i].global_position.y)
	var near = enemies[0]
	var far = enemies[-1]
	game.map.child_entered_tree.connect(func(n: Node) -> void: _fx.append(n.scene_file_path.get_file().get_basename()))
	var cm: Node = sl.get_companion_manager()
	var called: Array = []
	root.get_node("EventBus").assist_called.connect(func(id: String) -> void: called.append(id))

	print("[1] Nobody unlocked → the button does nothing")
	ck(cm.get_unlocked().is_empty() and cm.call_next() == "" and _actors().is_empty(), "no companions, no assist")
	for i in 2: await process_frame  # хотбар оновлюється у своєму _process
	ck(not _hud()[0], "no assist slot on the hotbar")

	print("[2] D464: the Laboratory flags make them available, but nobody joins until picked")
	for f in ["lab_companion_01_complete", "lab_companion_02_complete"]:  # як LabCells._acquaintance
		game.set_quest_flag(f, true)
		cm.announce_unlock(f)
	ck(cm.get_unlocked() == ["alisia", "astrit"], "Алісия and Астрит available (%s)" % [cm.get_unlocked()])
	ck(cm.get_party().is_empty(), "nobody joined on unlock (%s)" % [cm.get_party()])
	ck(cm.call_next() == "" and _actors().is_empty(), "the button calls nobody before a pick")
	for i in 2: await process_frame
	ck(not _hud()[0], "no assist slot while nobody is picked")

	print("[3] Picking: only the picked companion is called")
	ck(cm.toggle_party("alisia") and cm.get_party() == ["alisia"], "Алісия picked (%s)" % [cm.get_party()])
	for i in 2: await process_frame
	ck(_hud() == [true, "alisia", ""], "the hotbar shows Алісия ready (%s)" % [_hud()])

	print("[4] Алісия (D464): a ranged shot at the farthest enemy in front, an arrow streak and a hit spark")
	var before: Array = enemies.map(func(e: Node) -> int: return e.current_health)
	_fx.clear()
	ck(cm.call_next() == "alisia" and _actors().size() == 1, "Алісия runs in")
	await process_frame
	# Ступні — як намальовано: низ непрозорих пікселів поточного кадру героя й компаньйона на екрані.
	var hs: Sprite2D = hero.get_node(^"Sprite2D")
	var himg: Image = hs.texture.get_image()
	var hero_feet: float = hs.to_global(hs.offset + Vector2(0, himg.get_used_rect().end.y - himg.get_height() / 2.0)).y
	var cs: AnimatedSprite2D = _actors()[0].get_node(^"Sprite")
	var cimg: Image = cs.sprite_frames.get_frame_texture(cs.animation, cs.frame).get_image()
	var comp_feet: float = cs.to_global(cs.offset + Vector2(0, cimg.get_used_rect().end.y)).y
	ck(absf(hero_feet - comp_feet) <= 1.5, "Алісия's feet on the hero's foot line (%.1f vs %.1f)" % [comp_feet, hero_feet])
	await create_timer(2.5).timeout
	ck(far.current_health == before[-1] - 24, "the arrow hit the farthest enemy for 24 (%d → %d)" % [before[-1], far.current_health])
	ck(range(enemies.size() - 1).all(func(i: int) -> bool: return enemies[i].current_health == before[i]), "nobody nearer was touched")
	ck(_fx_count("arrow_streak") == 1 and _fx_count("hit_spark") == 1, "an arrow streak flew and a hit spark burst (%s)" % [_fx])
	ck(_actors().is_empty(), "Алісия left and freed herself")
	ck(cm.call_next() == "", "Астрит is available but not picked → nobody while Алісия cools down")

	print("[5] Астрит (D464): pounces on the nearest, the spiked shield stuns; a dust ring and stun stars")
	ck(cm.toggle_party("astrit") and cm.get_party() == ["alisia", "astrit"], "Астрит picked second (%s)" % [cm.get_party()])
	var hp: int = near.current_health
	_fx.clear()
	ck(cm.call_next() == "astrit", "Астрит is next in the queue")
	await create_timer(2.0).timeout
	ck(near.current_health == hp - 40, "Астрит hit for 40 (%d → %d)" % [hp, near.current_health])
	ck(near.enemy_logic.stun_left > 0.0 and _stars(near), "and stunned it, with stars over its head (%.2f s)" % near.enemy_logic.stun_left)
	ck(_fx_count("shield_slam") == 1, "a shield slam: flash and dust ring (%s)" % [_fx])
	ck(cm.call_next() == "", "both on cooldown → nobody")
	for i in 2: await process_frame
	var hud := _hud()
	ck(hud[0] and hud[1] == "alisia" and hud[2].ends_with("s"), "the hotbar shows Алісия, soonest back, with seconds left (%s)" % [hud])

	print("[6] Уризен (D464): the coin smite chains to up to 3 enemies, a golden burst on each")
	game.set_quest_flag("lab_companion_03_complete", true)
	cm.announce_unlock("lab_companion_03_complete")
	cm.toggle_party("urizen")
	near.enemy_logic.stun_left = 0.0  # Астрит оглушила першого — рахуємо лише оглушення монетою
	before = enemies.map(func(e: Node) -> int: return e.current_health)
	_fx.clear()
	ck(cm.call_next() == "urizen", "Уризен answers")
	await create_timer(2.6).timeout
	var hurt: Array = range(enemies.size()).filter(func(i: int) -> bool: return enemies[i].current_health == before[i] - 30)
	ck(hurt == [0, 1, 2], "the coin struck the three nearest for 30 each, the fourth is spared (%s of %d)" % [hurt, enemies.size()])
	ck(hurt.all(func(i: int) -> bool: return enemies[i].enemy_logic.stun_left > 0.0), "each struck enemy is stunned")
	ck(_fx_count("gold_burst") == 3, "a golden burst on each hit (%d)" % _fx_count("gold_burst"))

	print("[7] Cooldowns: 15 s each, then the queue goes on")
	cm._process(cm.COOLDOWN + 0.1)
	ck(cm.is_ready("alisia") and cm.is_ready("astrit") and cm.is_ready("urizen"), "all ready after %.0f s" % cm.COOLDOWN)
	ck(cm.call_next() == "alisia", "the queue goes on after the last called (Уризен): Алісия")
	await create_timer(2.5).timeout

	print("[8] The City Gates guard: offered for the fight, his thrust ends it with a wind arc")
	cm.offer_guard(true)
	for i in 2: await process_frame  # хотбар оновлюється у своєму _process
	ck(_hud()[1] == "guard", "the hotbar shows the guard while he is offered (%s)" % [_hud()])
	_fx.clear()
	ck(cm.call_next() == "guard" and not cm.is_guard_offered(), "the button calls the guard once")
	await create_timer(2.0).timeout
	ck(enemies.all(func(e: Node) -> bool: return not e.is_alive()), "every enemy in front is down")
	ck(_fx_count("wind_arc") == 1 and _fx_count("knockback_puff") == enemies.size(), "a wind arc and a puff per enemy (%s)" % [_fx])
	ck(called == ["alisia", "astrit", "urizen", "alisia", "guard"], "assist_called for each (%s)" % [called])
	await create_timer(1.0).timeout
	ck(_actors().is_empty(), "no companion left behind")
	ck(get_nodes_in_group(&"assist_fx").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(), "every effect freed itself")
	# Охоронець б'є кількох одразу → кілька hitstop за кадр; гра мусить повернутись до нормальної швидкості.
	ck(is_equal_approx(Engine.time_scale, 1.0), "time runs normally after the guard's multi-hit (%.2f)" % Engine.time_scale)

	print("[9] The party (D220): chosen in Status, its order is the assist queue, at most 3")
	ck(cm.get_party() == ["alisia", "astrit", "urizen"], "all three in the party, in picking order (%s)" % [cm.get_party()])
	cm._process(cm.COOLDOWN + 0.1)
	ck(not cm.toggle_party("alisia") and cm.get_party() == ["astrit", "urizen"], "Алісия stays in camp (%s)" % [cm.get_party()])
	cm._last_called = ""
	ck(cm.peek_next() == "astrit", "the queue starts at the first in the party (%s)" % cm.peek_next())
	ck(cm.toggle_party("alisia") and cm.get_party() == ["astrit", "urizen", "alisia"], "taken back, she goes last (%s)" % [cm.get_party()])
	var saved: Dictionary = root.get_node("SaveSystem").player_data_module.save()
	ck(saved.companion_party == cm.get_party(), "the party is saved with the player (%s)" % [saved.companion_party])
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	for i in 14: await process_frame
	get_first_node_in_group("game_menu").switch_to_tab("Status")
	for i in 10: await process_frame
	var cards: Array = get_first_node_in_group("game_menu").find_child("CompanionCards", true, false).get_children().filter(func(c: Control) -> bool: return c.visible)
	var labels: Array = cards.map(func(c: Control) -> String: return "%s %s" % [c.get_node(^"Row/Info/Name").text, c.get_node(^"Row/Info/Order").text])
	ck(labels == ["Alisia IN PARTY · 3", "Astrit IN PARTY · 1", "Urizen IN PARTY · 2"], "Status shows each with its place in the queue (%s)" % [labels])
	cards[0].get_node(^"Select").pressed.emit()
	await process_frame
	ck(cards[0].get_node(^"Row/Info/Order").text == "IN CAMP" and not cm.is_in_party("alisia"), "pressing her card sends her to camp")
	ui.close_game_menu()
	for i in 10: await process_frame

	print("[10] D463: the picker tutorial window — frames, the assist key, a button to Status → Companions")
	var settings: Dictionary = root.get_node("SaveSystem").settings_module.settings
	var seen: Array = sl.get_game_manager().player_state.seen_tutorials
	var hint: Node = get_first_node_in_group(&"tutorial_hint_display")
	var layer: Node = ui.get_modal_layer()
	settings.tutorial_windows = true
	seen.erase("choose_companions")
	hint.show_hint("choose_companions")
	for i in 6: await process_frame
	var window: Control = layer.active_modal
	ck(window != null and window.scene_file_path.ends_with("tutorial_menu.tscn") and paused, "a tutorial window opens and pauses the game")
	ck(window.get_node("%Title").text == "Choosing Companions", "on the picker topic (%s)" % window.get_node("%Title").text)
	ck(window.frames.size() > 1, "its frames play (%d)" % window.frames.size())
	ck(window.get_node("%HintBar").visible and window.get_node("%Key").text != "", "the assist key is shown (%s)" % window.get_node("%Key").text)
	var open_button: Button = window.get_node("%OpenButton")
	ck(open_button.is_visible_in_tree() and open_button.text == "OPEN COMPANIONS", "with the Open Companions button (%s)" % open_button.text)
	open_button.pressed.emit()
	for i in 20: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	var focus: Control = root.gui_get_focus_owner()
	ck(layer.active_modal == null and menu != null and menu.current_tab_name == "Status", "the button closed the window and opened Status")
	ck(focus != null and focus.name == "Select" and menu.find_child("CompanionCards", true, false).is_ancestor_of(focus), "focus is on a companion card (%s)" % [focus])
	ui.close_game_menu()
	for i in 10: await process_frame
	# Інші підказки (перше вбивство охоронцем) могли стати в чергу, поки вікна були ввімкнені — дивимось лише на свою тему.
	hint.show_hint("choose_companions")
	ck(not hint._pending.any(func(e: Array) -> bool: return e[0] == "choose_companions") and hint.current_hint != "choose_companions",
			"it fires once: a second time queues no window and shows no banner")
	if layer.active_modal != null:
		layer.active_modal.cancelled.emit()
	hint.force_hide()
	seen.erase("choose_companions")
	settings.tutorial_windows = false
	hint.show_hint("choose_companions")
	ck(not hint._pending.any(func(e: Array) -> bool: return e[0] == "choose_companions") and hint.is_showing and hint.current_hint == "choose_companions",
			"Tutorial windows Off → the plain hint banner instead (%s)" % hint.current_hint)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
