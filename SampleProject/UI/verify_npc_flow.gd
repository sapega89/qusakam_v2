extends SceneTree

## Як NPC зустрічає героя (playtest 2026-10-23): D442 — знак над головою замість катсцени: жовтий «!» сюжетний
## квест, синій «!» побічний, зникає, щойно квест взято; D452 — герб клятви (професії) і репліка мимохідь від того,
## хто має що дати, раз за кімнату; D454 — меню NPC відкривається саме, без [E], не модальне: стрибок не вибирає,
## вгору/вниз — пункти, interact — вибір; відійшов — закрилось; ui_cancel — геть, поки герой не відійде, E — знову.
##   godot --headless --path . --script res://SampleProject/UI/verify_npc_flow.gd

const NPC_DIR := "res://SampleProject/Scenes/Gameplay/Objects/NPCs/"
const QuestMarker := preload("res://SampleProject/UI/Components/quest_marker.gd")
const TALK := "res://dialogue_quest/OldMan_Decision.dqd"

var fails: Array[String] = []
var _hero: CharacterBody2D
var _far: Vector2
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()  # D254
			dm.current_dialogue_player.accept()
			await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return


func _action(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


## Пробіл — і ui_accept, і стрибок (project.godot).
func _space() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.unicode = 32
	ev.pressed = true
	return ev


func _spawn(world: Node, file: String, at: Vector2) -> NpcBase:
	var npc: NpcBase = load(NPC_DIR + file).instantiate()
	npc.shown_with_flag = ""
	npc.gone_with_flag = ""
	npc.global_position = at
	world.add_child(npc)
	return npc


## «You obtained:» від take / turn_in — поки вони відкриті, меню NPC чекає (як і будь-який ігровий ввід).
func _close_popups(sl: Node) -> void:
	for i in 20:
		await process_frame
		if sl.get_ui_manager().is_gameplay_input_allowed():
			return
		root.push_input(_action(&"ui_accept"))
		var up := _action(&"ui_accept")
		up.pressed = false
		root.push_input(up)  # кнопка модалки спрацьовує на відпусканні
		for f in 4: await process_frame
	ck(sl.get_ui_manager().is_gameplay_input_allowed(), "the reward popups are closed")


## Герой стоїть у зоні NPC: справжнє перекриття Area2D (герой заморожений — тут немає підлоги).
func _go(npc: NpcBase) -> void:
	_hero.global_position = npc.global_position + Vector2(-40, -20)
	for i in 3: await physics_frame


func _leave() -> void:
	_hero.global_position = _far
	for i in 3: await physics_frame


func _focused_label() -> String:
	var focused := root.gui_get_focus_owner()
	return (focused as Button).text if focused is Button else ""


func _initialize() -> void:
	await process_frame
	await process_frame
	set_meta("start_new_game", true)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	var sl: Node = root.get_node("ServiceLocator")
	var dm: Node = sl.get_dialogue_manager()
	dm.bubble_time_scale = 0.0
	var world: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 40: await process_frame
	await _drain(dm)
	var game: Node = world
	var player: CharacterBody2D = world.player
	var far := player.global_position + Vector2(-6000, 0)
	player.global_position = far
	player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE  # без процесу, але в фізиці: зони NPC його бачать
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_hero = player
	_far = far
	var TASKS: GDScript = load("res://SampleProject/Scripts/Tasks/task_service.gd")

	print("[1] The marker is pixel UI art drawn in code, in the token colours (D442, D452)")
	ck(QuestMarker.COLORS[&"story"] == UITokens.QUEST_MARK_STORY and UITokens.QUEST_MARK_STORY == UITokens.ACCENT,
			"story \"!\": yellow (the accent gold)")
	ck(QuestMarker.COLORS[&"side"] == UITokens.QUEST_MARK_SIDE and UITokens.QUEST_MARK_SIDE.b > UITokens.QUEST_MARK_SIDE.r,
			"side \"!\": blue")
	ck(QuestMarker.COLORS[&"oath"] == UITokens.QUEST_MARK_OATH and UITokens.QUEST_MARK_OATH != UITokens.QUEST_MARK_STORY
			and UITokens.QUEST_MARK_OATH != UITokens.QUEST_MARK_SIDE, "oath crest: a third colour")
	var src := FileAccess.get_file_as_string("res://SampleProject/UI/Components/quest_marker.gd")
	ck(src.find("Texture") == -1 and src.find("draw_rect") != -1, "drawn cell by cell, no generated texture")
	ck(QuestMarker.EXCLAIM != QuestMarker.CREST and QuestMarker.CREST[0].length() > QuestMarker.EXCLAIM[0].length(),
			"the crest is its own shape, not a \"!\"")

	print("[2] Story NPC: yellow \"!\" until his story quest is given")
	var old_man: NpcBase = _spawn(world, "grandfather.tscn", far + Vector2(800, 0))
	old_man.quest_flag = "verify_npc_flow_story"
	old_man.refresh_availability()
	await process_frame
	ck(old_man.marker.visible and old_man.marker.kind == &"story", "yellow \"!\" over the old man (%s)" % old_man.marker.kind)
	ck(old_man.marker.global_position.y < old_man.sprite.global_position.y + old_man.sprite.get_rect().position.y * old_man.sprite.scale.y,
			"above his head")
	ck(old_man.marker.scale.is_equal_approx(Vector2.ONE / 2.25), "screen-sized under the ×2.25 camera (D170)")
	game.set_quest_flag("verify_npc_flow_story", true)
	await process_frame
	ck(not old_man.marker.visible and old_man.marker.kind == &"", "gone once the quest is given")
	old_man.queue_free()

	print("[3] Side quest: blue \"!\" while a task waits to be taken; back for the next one")
	var smith: NpcBase = _spawn(world, "blacksmith.tscn", far + Vector2(1600, 0))
	await process_frame
	ck(smith.marker.visible and smith.marker.kind == &"side", "blue \"!\" over the blacksmith (%s)" % smith.marker.kind)
	var helmet: Dictionary = TASKS.tasks().filter(func(t: Dictionary) -> bool: return t.id == "smith_helmet")[0]
	TASKS.take(helmet)
	await process_frame
	ck(not smith.marker.visible, "gone once The Helmet is taken")
	TASKS.turn_in(helmet)
	await process_frame
	ck(smith.marker.visible and smith.marker.kind == &"side", "The Enchantment opens: the blue \"!\" is back")
	await _drain(dm)
	for i in 10: await process_frame
	await _close_popups(sl)

	print("[4] Oath keepers: a crest until the hero swears an oath, then gone on all of them (D452)")
	var priest: NpcBase = _spawn(world, "oath_priest.tscn", far + Vector2(2400, 0))
	var witch: NpcBase = _spawn(world, "oath_witch.tscn", far + Vector2(3200, 0))
	await process_frame
	ck(priest.marker.kind == &"oath" and witch.marker.kind == &"oath" and priest.marker.visible, "the crest over the priestess and the witch")
	ck(priest.marker.pattern() == QuestMarker.CREST and smith.marker.pattern() == QuestMarker.EXCLAIM, "crest vs \"!\" shapes")

	print("[5] A quest giver calls out once per visit as the hero passes; without a quest he keeps quiet (D452)")
	dm.bubble_time_scale = 1.0  # облачко живе seconds_for() — тест має його побачити
	await _go(witch)
	for i in 2: await process_frame
	var bubble: Node2D = dm.chatter_bubble(witch)
	var bark: String = dm._stage_tag.sub(dm.DQD_READER.lines(witch.quest_bark_dialogue)[0].text, "")
	ck(bubble != null, "the witch calls out in a cloud")
	ck(witch.quest_bark_dialogue.ends_with("City_Oath_Witch_Bark.dqd") and bark != "", "her bark line: %s" % bark)
	ck(not witch.marker.visible, "the crest steps aside while the cloud is up")
	ck(witch.npc_menu.visible, "and her menu opens alongside (D454)")
	await _leave()
	dm.end_chatter(witch)
	await process_frame
	ck(not witch.npc_menu.visible, "leaving the range closes the menu")
	ck(witch.marker.visible, "the crest is back")
	await _go(witch)
	await process_frame
	ck(dm.chatter_bubble(witch) == null, "once per visit: no second call")
	await _leave()
	for file: String in ["merchant.tscn", "blacksmith.tscn", "grandfather.tscn", "oath_priest.tscn", "oath_witch.tscn", "oath_dervish.tscn"]:
		var path: String = (load(NPC_DIR + file) as PackedScene).instantiate().quest_bark_dialogue
		var en: String = path.replace("dialogue_quest/", "dialogue_quest/en/")
		ck(FileAccess.get_file_as_string(path).contains("[ЧЕРНЕТКА]") and FileAccess.get_file_as_string(en).contains("[DRAFT]"),
				"%s: a bark in uk and en, both drafts (%s)" % [file, path.get_file()])
	var helmet_done: bool = TASKS.status(helmet) == TASKS.DONE
	var enchant: Dictionary = TASKS.tasks().filter(func(t: Dictionary) -> bool: return t.id == "smith_enchant")[0]
	TASKS.take(enchant)
	await _drain(dm)
	await _close_popups(sl)
	ck(helmet_done and not smith.marker.visible, "the blacksmith has nothing left to give")
	await _go(smith)
	await process_frame
	# Нічого дати — не гукає (D452), а каже своє звичайне мимохідь (D338, D571).
	var passing: Node2D = dm.chatter_bubble(smith)
	var plain: String = dm._stage_tag.sub(dm.DQD_READER.lines(smith.chatter_dialogue)[0].text, "")
	ck(passing != null and passing._label.text == plain, "so he does not call out: his plain chatter instead (%s)"
			% (passing._label.text if passing != null else "no cloud"))
	await _leave()
	dm.bubble_time_scale = 0.0

	print("[6] The menu opens by itself and is not modal (D454)")
	priest.talk_dialogue = TALK
	priest.refresh_availability()
	await _go(priest)
	await process_frame
	await process_frame
	ck(priest.npc_menu.visible and not priest.interactable.get_prompt().visible, "entering the range opens the menu, no [E] prompt")
	ck(not paused, "the world keeps running")
	var labels: Array = priest.npc_menu.get_children().map(func(b: Button) -> String: return b.text)
	ck(labels.size() >= 2 and _focused_label() == labels[0], "focus on the first row (%s)" % [labels])
	root.push_input(_space())
	for i in 3: await process_frame
	ck(priest.npc_menu.visible and not dm.is_dialogue_active(), "Space / pad A jumps: it does not pick a row")
	root.push_input(_action(&"ui_down"))
	for i in 2: await process_frame
	ck(_focused_label() == labels[1], "Down moves to the next row (%s)" % _focused_label())
	ck(priest.npc_menu.is_engaged and _hero.event, "D735: the first menu key takes the menu and holds the hero")
	root.push_input(_action(&"ui_up"))
	for i in 2: await process_frame
	ck(_focused_label() == labels[0], "Up moves back (%s)" % _focused_label())
	root.push_input(_action(&"ui_cancel"))
	for i in 4: await process_frame
	ck(not priest.npc_menu.visible, "ui_cancel closes it, and it stays closed while the hero stands there")
	ck(not _hero.event, "D735: closing lets the hero go")
	root.push_input(_action(&"interact"))
	for i in 4: await process_frame
	ck(priest.npc_menu.visible, "E opens it again")
	ck(_focused_label() == "Talk", "Talk is the first row")
	root.push_input(_action(&"interact"))
	for i in 4: await process_frame
	ck(dm.is_dialogue_active() and not priest.npc_menu.visible, "Interact picks: Talk starts the dialogue")
	await _drain(dm)
	for i in 4: await process_frame
	ck(priest.npc_menu.visible, "after the talk, the hero still there: the menu is back")
	await _leave()
	await process_frame
	ck(not priest.npc_menu.visible, "leaving the range closes it")
	await _go(priest)
	await process_frame
	await process_frame
	ck(priest.npc_menu.visible, "coming back opens it again")
	await _leave()

	print("[4b] Swearing an oath takes the crest off every keeper")
	var xp: Node = sl.get_xp_manager()
	while xp.get_level() < 5:
		xp.add_xp(xp.xp_for_next_level - xp.current_xp)
	sl.get_skill_manager().swear_oath(priest.oath_id)
	await process_frame
	ck(not priest.marker.visible and not witch.marker.visible and priest.marker.kind == &"" and witch.marker.kind == &"",
			"no crest once sworn (on the priestess and the witch)")

	for i in 4: await process_frame
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
