extends SceneTree

## Hints like Lineage II (BACKLOG 12, D289, D718), every tip a «?» (D726), real input:
##   godot --headless --path . --script res://SampleProject/UI/verify_tutorial_hints.gd
##   1. After the Canyon intro the movement tip (WASD) is a «?» like any other — no banner; its window names A / D.
##   2. The first enemy: the attack «?»; its window names the pad button (X) after pad input, Left Mouse after a key.
##   3. The hero is hit, then a kill: more glowing «?» stack at the left edge, the game never stops; the open key is on the
##      top one; T / D-pad left opens the oldest (paused, LB after pad input), a click opens another; each «?» goes.
##   4. Game Menu → Misc → Tutorial (mouse): the seen topics are listed after the general ones, unseen are not;
##      a click opens that topic.
##   5. D728: Settings → Game → Hints: Off (mouse click) clears the waiting «?»; a route that would fire several tips
##      (kill, level up, every glint colour, Healing Palm) puts none and marks none seen; an interaction prompt
##      («Open» at a chest) still shows; Off survives a save and a load. On again: new tips from then on, no flood.
##   6. D726: no tip text ever shows outside the «?» delivery — every hint topic, en and uk, leaves no label on screen
##      with its text, and no script but the tip tray and the tutorial screens reads a topic's text.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const TextFit = preload("res://SampleProject/UI/text_fit.gd")
## load() у _initialize(): preload компілював би скрипт до автозавантажень (ServiceLocator).
var TutorialTopics: GDScript

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _window() -> Node:
	var modal: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal
	return modal if modal != null and modal.has_method("open_id") else null


func _title() -> String:
	return _window().get_node("%Title").text if _window() else ""


func _body() -> String:
	return _window().get_node("%Body").text if _window() else ""


func _topics_listed(menu: Node) -> Array:
	return menu.get_node("%TutorialComponent").get_node("%TopicList").get_children().filter(
			func(r: Control) -> bool: return r.visible).map(func(r: Button) -> String: return r.text)


func _initialize() -> void:
	await process_frame
	TutorialTopics = load("res://SampleProject/Scripts/UI/tutorial_topics.gd")
	var settings: Dictionary = root.get_node("SaveSystem").settings_module.settings
	settings.hints = true
	var game: Node = await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	await Kit.key(self, KEY_RIGHT)  # клавіатура — останній пристрій

	var tray: Node = get_first_node_in_group(&"tip_tray")

	print("[1] Movement (WASD) tip: a «?», no banner, the game runs (D726)")
	for i in 600:
		if tray.has("movement"):
			break
		await process_frame
	ck(tray.ids() == ["movement"], "movement waits as a «?» (%s)" % [tray.ids()])
	ck(_window() == null and not paused, "no window, the game is not paused")
	ck(_tip_text_on_screen("movement") == "", "no movement text on screen (%s)" % _tip_text_on_screen("movement"))
	await Kit.key(self, KEY_T)
	await Kit.frames(self, 3)
	ck(_title() == "Moving and Jumping" and _body().contains("A / D") and _body().contains("Space"), "T opens it, keyboard names (%s)" % _body())
	await Kit.key(self, KEY_ESCAPE)
	ck(_window() == null and not paused and tray.ids().is_empty(), "closed, its «?» gone")

	print("[2] The first enemy: the attack «?», its window follows the device")
	root.get_node("EventBus").enemy_spawned.emit("test_enemy", Vector2.ZERO)
	await Kit.frames(self, 4)
	ck(tray.ids() == ["attack"] and _window() == null and not paused, "attack waits as a «?» (%s)" % [tray.ids()])
	await Kit.pad(self, JOY_BUTTON_DPAD_LEFT)  # геймпад — останній пристрій, D-pad left відкриває найстаріший «?»
	await Kit.frames(self, 3)
	ck(_title() == "Attacking" and _body().contains("Press X"), "its window names X on the pad (%s)" % _body())
	await Kit.pad(self, JOY_BUTTON_B)
	root.get_node("EventBus").enemy_spawned.emit("test_enemy_2", Vector2.ZERO)
	await Kit.frames(self, 10)
	ck(tray.ids().is_empty(), "a seen topic does not come back (%s)" % [tray.ids()])
	await Kit.key(self, KEY_RIGHT)  # клавіатура — останній пристрій

	print("[3] D732: a hit and a kill — two «?» at the left edge, opened when the player wants")
	root.get_node("EventBus").player_staggered.emit(0.3)
	root.get_node("EventBus").enemy_died.emit("e0", Vector2.ZERO)
	await Kit.frames(self, 6)
	ck(tray.ids() == ["block", "first_kill"], "two tips wait, oldest first (%s)" % [tray.ids()])
	ck(_window() == null and not paused, "no window, the game runs")
	var top: Control = tray.icon_of("block")
	var second: Control = tray.icon_of("first_kill")
	var screen: Rect2 = tray.get_viewport_rect()
	ck(top.is_visible_in_tree() and top.get_global_rect().position.x < screen.size.x * 0.1 and second.get_global_rect().position.y > top.get_global_rect().end.y - 1.0,
			"at the left edge, stacked (%s, %s)" % [top.get_global_rect(), second.get_global_rect()])
	ck(top.get_node(^"Badge/Mark").text == "?" and top.get_node(^"Key").visible and top.get_node(^"Key").text == "T" and not second.get_node(^"Key").visible,
			"«?» with the open key on the top one only (%s)" % top.get_node(^"Key").text)
	var glow_from: Color = top.get_node(^"Badge").modulate
	await Kit.frames(self, 20)
	ck(top.get_node(^"Badge").modulate != glow_from, "it glows (modulate %s → %s)" % [glow_from, top.get_node(^"Badge").modulate])
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(top.get_node(^"Key").text == "D-pad", "after pad input the key reads D-pad (%s)" % top.get_node(^"Key").text)
	await Kit.pad(self, JOY_BUTTON_DPAD_LEFT)
	await Kit.frames(self, 3)
	ck(_title() == "Block and Parry" and paused, "D-pad left opens the oldest, the game paused (%s)" % _title())
	ck(_body().contains("Hold LB"), "block topic names LB (%s)" % _body())
	# B143, D573/D574: жовтий відблиск — парирування, червоний — ухилитися
	ck(_body().contains("glints yellow") and _body().contains("A red glint cannot be blocked or parried") and not _body().contains("glints red"),
			"block topic: yellow = parry, red = roll (B143)")
	# D474: вікно туторіалу ×1.5 (тіло ≥ 24, клавіша ≥ 20), уміщається в екран — нічого не обрізано.
	var win: Control = _window()
	ck(win.get_node("%Body").get_theme_font_size(&"font_size") >= UITokens.INGAME_BODY_MIN
			and win.get_node("%Key").get_theme_font_size(&"font_size") >= UITokens.INGAME_LABEL_MIN,
			"D474: window body %d px, key %d px" % [win.get_node("%Body").get_theme_font_size(&"font_size"), win.get_node("%Key").get_theme_font_size(&"font_size")])
	var win_clip: String = TextFit.clipped(win)
	ck(win_clip == "", "D474: nothing clipped in the tutorial window (%s)" % win_clip)
	ck(tray.ids() == ["first_kill"], "its «?» is gone (%s)" % [tray.ids()])
	await Kit.key(self, KEY_ESCAPE)
	ck(_window() == null and not paused, "Esc closed it, the game runs")
	ck(get_first_node_in_group("game_menu") == null, "Esc did not open the Game Menu")
	ck(tray.icon_of("first_kill").get_node(^"Key").visible, "the open key moved to the next «?»")
	await Kit.key(self, KEY_ALT)  # D417: у грі курсор схований — Alt показує його, тоді клік доходить до «?»
	await Kit.mouse(self, tray.icon_of("first_kill"))
	ck(_title() == "Experience and Coins" and paused, "a click on the «?» opens its topic (%s)" % _title())
	await Kit.pad(self, JOY_BUTTON_B)
	ck(_window() == null and not paused and tray.ids().is_empty(), "pad B closed it; no «?» left")
	await Kit.key(self, KEY_ALT)
	await Kit.key(self, KEY_T)
	ck(_window() == null, "T with no tip waiting opens nothing")

	print("[4] Seen topics are in the Tutorial list")
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 14)
	var menu: Node = get_first_node_in_group("game_menu")
	ck(menu != null, "Esc opens the Game Menu")
	await Kit.mouse(self, menu.misc_button)
	await Kit.frames(self, 6)
	var misc: Node = ui.get_modal_layer().active_modal
	await Kit.mouse(self, misc.tutorial_button)
	await Kit.frames(self, 6)
	var listed: Array = _topics_listed(menu)
	ck(listed.slice(0, 4) == ["Basic Controls", "The Map", "Saving Your Progress", "The Journal"], "general topics first (%s)" % [listed])
	ck(listed.slice(4) == ["Moving and Jumping", "Attacking", "Block and Parry", "Experience and Coins"], "then the seen hints (%s)" % [listed.slice(4)])
	var rows: Array = menu.get_node("%TutorialComponent").get_node("%TopicList").get_children().filter(func(r: Control) -> bool: return r.visible)
	await Kit.mouse(self, rows[6])
	ck(_title() == "Block and Parry", "a click opens that topic (%s)" % _title())
	await Kit.pad(self, JOY_BUTTON_DPAD_UP)
	ck(_title() == "Attacking", "D-pad up: previous topic (%s)" % _title())
	await Kit.pad(self, JOY_BUTTON_B)
	ck(_window() == null and get_first_node_in_group("game_menu") != null, "B back to the list, menu open")

	print("[5] D728: Settings → Game → Hints Off — no «?» at all, prompts stay")
	await Kit.mouse(self, menu.misc_button)
	await Kit.frames(self, 6)
	await Kit.mouse(self, ui.get_modal_layer().active_modal.settings_button)
	await Kit.frames(self, 6)
	var options: Node = menu.find_child("OptionsComponent", true, false)
	options.switch_to_tab("game")
	await Kit.frames(self, 4)
	tray.show_tip("level_up")  # «?», що чекає, коли підказки вимикають
	ck(tray.has("level_up"), "a «?» waits before the switch")
	var off: Button = options.find_children("Cell1", "Button", true, false).filter(
			func(b: Button) -> bool: return b.get_parent().get_parent().get_parent().find_children("*", "Label", true, false).any(
				func(l: Label) -> bool: return l.text == "Hints"))[0]
	await Kit.mouse(self, off)
	ck(settings.hints == false, "a click on Off turns the hints off")
	ck(tray.ids().is_empty(), "turning them off mid-game clears the waiting «?» (%s)" % [tray.ids()])
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 6)
	ck(get_first_node_in_group("game_menu") == null, "menu closed")
	var seen: Array = sl.get_game_manager().player_state.seen_tutorials
	var seen_before: Array = seen.duplicate()
	var bus: Node = root.get_node("EventBus")
	bus.enemy_died.emit("e2", Vector2.ZERO)  # друге вбивство — важкий удар
	var enemy: Node2D = _enemy_by(game.player)
	for kind in [&"block", &"parry", &"dodge"]:
		enemy.enemy_logic.tell_kind = kind
		enemy._on_logic_attack_telegraphed()
	sl.get_xp_manager().add_xp(100)  # другий рівень — Длань лікування
	await create_timer(4.0).timeout
	ck(tray.ids().is_empty() and tray.get_child_count() == 1, "kill, three glints, a level-up: no «?» (%s)" % [tray.ids()])
	ck(seen == seen_before, "…and nothing is marked seen (%s)" % [seen])
	var chest: Node2D = load("res://SampleProject/Objects/Chest.tscn").instantiate()
	chest.persistent = false  # скриня теста — не кімнати, стану в сейві не має
	chest.charm = "grandfathers_ring"  # як verify_charms: скриня з чимось, інакше її не відкрити
	game.map.add_child(chest)
	chest.global_position = game.player.global_position
	for i in 20: await physics_frame
	var interactable: Node = chest.get_node(^"Interactable")
	ck(interactable.get_prompt().visible and interactable.get_prompt().action_text == "Open",
			"the chest's «Open» prompt still shows (nearby %s, enabled %s)" % [interactable.player_nearby, interactable.enabled])
	chest.queue_free()
	enemy.queue_free()
	var saved: Dictionary = root.get_node("SaveSystem").player_data_module.save()
	ck(saved.seen_tutorials == seen and saved.has("playthrough_id"), "seen topics and the playthrough are saved with the player (D727)")
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings = save_system.settings_module.default_settings.duplicate()
	save_system.load_game_settings()
	ck(save_system.settings_module.settings.hints == false, "Hints Off survives a save and a load of the settings")
	settings = save_system.settings_module.settings
	settings.hints = true
	await Kit.frames(self, 4)
	ck(tray.ids().is_empty(), "On again: no flood of the missed tips")
	bus.enemy_died.emit("e3", Vector2.ZERO)
	await Kit.frames(self, 4)
	ck(tray.ids() == ["heavy_attack"], "…a new occasion shows its tip from then on (%s)" % [tray.ids()])
	tray.clear()
	save_system.save_game_settings()

	await _no_tip_text_outside()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)


## Звичайний бандит поруч із героєм — у кадрі камери.
func _enemy_by(hero: Node2D) -> Node2D:
	var enemy: Node2D = load("res://SampleProject/Scenes/Characters/Enemies/default_enemy.tscn").instantiate()
	enemy.enemy_stats = load("res://SampleProject/Resources/Enemies/enemy_stats_melee.tres")
	hero.get_parent().add_child(enemy)
	enemy.global_position = hero.global_position + Vector2(120, 0)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED  # стоїть: відблиск кличемо самі, тим самим шляхом, що й замах
	return enemy


## Видимий текст на екрані (Label, RichTextLabel, Button), що містить текст, підказку чи назву теми [param id].
func _tip_text_on_screen(id: String) -> String:
	var topic: Dictionary = TutorialTopics.resolved(TutorialTopics.by_id(id))
	var needles: Array[String] = []
	for field in ["text", "hint"]:
		if String(topic[field]).length() > 12:
			needles.append(String(topic[field]))
	for node in root.find_children("*", "Control", true, false):
		var c := node as Control
		if not c.is_visible_in_tree():
			continue
		var shown := ""
		if c is Label:
			shown = (c as Label).text
		elif c is RichTextLabel:
			shown = (c as RichTextLabel).get_parsed_text()
		elif c is Button:
			shown = (c as Button).text
		for needle in needles:
			if shown != "" and (shown.contains(needle) or needle.contains(shown) and shown.length() > 12):
				return "%s: %s" % [c.get_path(), shown]
	return ""


## D726: кожна тема-підказка, en і uk, — лише «?»: жодного її тексту на екрані; і жоден скрипт гри, крім TipTray
## і екранів туторіалу, не читає текст теми (TutorialTopics.resolved).
func _no_tip_text_outside() -> void:
	print("[6] D726: no tip text outside the «?» delivery (en, uk; code)")
	var tray: Node = get_first_node_in_group(&"tip_tray")
	var loc: Node = root.get_node("LocalizationManager")
	var seen: Array = root.get_node("ServiceLocator").get_game_manager().player_state.seen_tutorials
	var bad: Array[String] = []
	var checked := 0
	for lang in ["en", "uk"]:
		loc.apply_language(lang)
		for topic: Dictionary in TutorialTopics.all().filter(func(t: Dictionary) -> bool: return t.get("hint_topic", false)):
			seen.erase(topic.id)
			tray.show_tip(topic.id)
			await Kit.frames(self, 3)
			checked += 1
			if not tray.has(topic.id):
				bad.append("%s %s: no «?»" % [lang, topic.id])
			var on_screen := _tip_text_on_screen(topic.id)
			if on_screen != "":
				bad.append("%s %s: %s" % [lang, topic.id, on_screen])
			tray.clear()
	loc.apply_language("en")
	ck(checked > 0 and bad.is_empty(), "%d tips: each a «?», none of their text on screen (%s)" % [checked, "; ".join(bad.slice(0, 3))])
	var readers: Array[String] = []
	_scripts_reading_topics("res://SampleProject/Scripts", readers)
	_scripts_reading_topics("res://SampleProject/UI/Components", readers)
	ck(readers == ["res://SampleProject/Scripts/Menus/Game/tutorial_menu.gd"], "only the tutorial window resolves a topic's text (%s)" % [readers])
	ck(not ResourceLoader.exists("res://SampleProject/Scenes/UI/TutorialHintDisplay.tscn")
			and not ResourceLoader.exists("res://SampleProject/Scripts/UI/TutorialHintDisplay.gd")
			and get_nodes_in_group(&"tutorial_hint_display").is_empty(), "the old hint window is gone (scene, script, group)")


func _scripts_reading_topics(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scripts_reading_topics(dir.path_join(sub), out)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") and FileAccess.get_file_as_string(dir.path_join(file)).contains("TutorialTopics.resolved("):
			out.append(dir.path_join(file))
	out.sort()
