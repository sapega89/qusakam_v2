extends SceneTree

## Hints like Lineage II (BACKLOG 12, D289, D718), real input:
##   godot --headless --path . --script res://SampleProject/UI/verify_tutorial_hints.gd
##   1. After the Canyon intro the movement hint is a brief banner (essential), the game runs; keyboard names (A / D).
##   2. The first enemy: the attack banner names the pad button (X) after pad input, Left Mouse after a key.
##   3. The hero is hit, then a kill: two glowing «?» stack at the left edge, the game never stops; the open key is on the
##      top one; T opens the oldest (Block and Parry, paused, LB after pad input), a click opens the other; each «?» goes.
##   4. Game Menu → Misc → Tutorial (mouse): the seen topics are listed after the general ones, unseen are not;
##      a click opens that topic.
##   5. Settings → Game → Tutorial Windows: Off (mouse click). The next hint (second kill = heavy attack) is a
##      banner, no «?», and still lands in the list. Seen topics are saved with the player.
##   6. B151: every banner fits its text in en and uk at every window size, on top, clear of the hero.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const TextFit = preload("res://SampleProject/UI/text_fit.gd")
const TutorialTopics = preload("res://SampleProject/Scripts/UI/tutorial_topics.gd")

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
	var settings: Dictionary = root.get_node("SaveSystem").settings_module.settings
	settings.tutorial_windows = true
	await Kit.boot(self)
	var sl: Node = root.get_node("ServiceLocator")
	var ui: Node = sl.get_ui_manager()
	await Kit.key(self, KEY_RIGHT)  # клавіатура — останній пристрій

	var hint: Node = get_first_node_in_group(&"tutorial_hint_display")
	var tray: Node = hint.tip_tray

	print("[1] Movement hint: a brief banner, the game runs (D718)")
	for i in 600:
		if hint.current_hint == "movement":
			break
		await process_frame
	ck(hint.is_showing and hint.current_hint == "movement", "movement banner shows (%s)" % hint.current_hint)
	ck(_window() == null and not paused, "no window, the game is not paused")
	ck(hint.hint_label.text.contains("A / D") and hint.hint_label.text.contains("Space"), "keyboard names (%s)" % hint.hint_label.text)
	ck(tray.ids().is_empty(), "an essential topic puts no «?» (%s)" % [tray.ids()])

	print("[2] The first enemy: the attack banner follows the device")
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)  # геймпад — останній пристрій
	root.get_node("EventBus").enemy_spawned.emit("test_enemy", Vector2.ZERO)
	await Kit.frames(self, 4)
	ck(hint.current_hint == "attack" and hint.hint_label.text.contains("Press X"), "attack banner names X on the pad (%s)" % hint.hint_label.text)
	ck(_window() == null and not paused, "still no window")
	await Kit.key(self, KEY_SPACE)
	ck(hint.hint_label.text.contains("Left Mouse"), "switching to the keyboard renames it (%s)" % hint.hint_label.text)
	hint.force_hide()
	root.get_node("EventBus").enemy_spawned.emit("test_enemy_2", Vector2.ZERO)
	await Kit.frames(self, 10)
	ck(not hint.is_showing and tray.ids().is_empty(), "a seen topic does not show again")

	print("[3] D718: a hit and a kill — two «?» at the left edge, opened when the player wants")
	root.get_node("EventBus").player_staggered.emit(0.3)
	root.get_node("EventBus").enemy_died.emit("e0", Vector2.ZERO)
	await Kit.frames(self, 6)
	ck(tray.ids() == ["block", "first_kill"], "two tips wait, oldest first (%s)" % [tray.ids()])
	ck(_window() == null and not paused and not hint.is_showing, "no window, no banner, the game runs")
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
	await Kit.mouse(self, tray.icon_of("first_kill"))
	ck(_title() == "Experience and Coins" and paused, "a click on the «?» opens its topic (%s)" % _title())
	await Kit.pad(self, JOY_BUTTON_B)
	ck(_window() == null and not paused and tray.ids().is_empty(), "pad B closed it; no «?» left")
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

	print("[5] Settings: windows off")
	await Kit.mouse(self, menu.misc_button)
	await Kit.frames(self, 6)
	await Kit.mouse(self, ui.get_modal_layer().active_modal.settings_button)
	await Kit.frames(self, 6)
	var options: Node = menu.find_child("OptionsComponent", true, false)
	options.switch_to_tab("game")
	await Kit.frames(self, 4)
	var off: Button = options.find_children("Cell1", "Button", true, false).filter(
			func(b: Button) -> bool: return b.get_parent().get_parent().get_parent().find_children("*", "Label", true, false).any(
				func(l: Label) -> bool: return l.text == "Tutorial Windows"))[0]
	await Kit.mouse(self, off)
	ck(settings.tutorial_windows == false, "a click on Off turns the windows off")
	await Kit.key(self, KEY_ESCAPE)
	await Kit.frames(self, 6)
	ck(get_first_node_in_group("game_menu") == null, "menu closed")
	root.get_node("EventBus").enemy_died.emit("e2", Vector2.ZERO)  # друге вбивство — важкий удар
	await Kit.frames(self, 10)
	ck(_window() == null and tray.ids().is_empty(), "no window and no «?» with the setting off")
	ck(hint.is_showing and hint.hint_label.text != "", "a banner instead (%s: %s)" % [hint.current_hint, hint.hint_label.text])
	await Kit.frames(self, 3)
	# D474: плашка ×1.5 (≥ 24 px) росте вгору під текст — нічого не обрізано.
	ck(hint.hint_label.get_theme_font_size(&"font_size") >= UITokens.INGAME_BODY_MIN, "D474: banner text %d px" % hint.hint_label.get_theme_font_size(&"font_size"))
	var banner_clip: String = TextFit.clipped(hint.panel)
	ck(banner_clip == "", "D474: nothing clipped in the banner (%s)" % banner_clip)
	var seen: Array = sl.get_game_manager().player_state.seen_tutorials
	ck("heavy_attack" in seen and "first_kill" in seen, "both still land in the list (%s)" % [seen])
	var saved: Dictionary = root.get_node("SaveSystem").player_data_module.save()
	ck(saved.seen_tutorials == seen, "seen topics are saved with the player")
	settings.tutorial_windows = true
	root.get_node("SaveSystem").save_game_settings()  # клік Off записав файл налаштувань — повертаємо

	await _banner_fits()

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)


## B151: плашка росте під свій текст у en і uk за кожного розміру вікна і стоїть угорі, не на герої й не посеред екрана.
func _banner_fits() -> void:
	print("[6] B151: every banner fits its text (en, uk; 1280×720 … 2560×1440) and keeps clear of the hero")
	var hint: Node = get_first_node_in_group(&"tutorial_hint_display")
	var loc: Node = root.get_node("LocalizationManager")
	var hero: Node2D = get_first_node_in_group(&"player")
	var sprite: Sprite2D = hero.get_node(^"Sprite2D")
	var bad: Array[String] = []
	var checked := 0
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = size
		for lang in ["en", "uk"]:
			loc.apply_language(lang)
			for topic: Dictionary in TutorialTopics.all().filter(func(t: Dictionary) -> bool: return t.get("hint_topic", false)):
				TutorialTopics.mark_seen(topic.id)  # повтор (force) — завжди плашка
				hint.show_hint(topic.id, true, true)
				await Kit.frames(self, 4)
				var box: Rect2 = hint.panel.get_global_rect()
				var screen: Rect2 = hint.get_viewport_rect()
				var hero_box: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
				var clip: String = TextFit.clipped(hint.panel)
				checked += 1
				if clip != "":
					bad.append("%s %s %s: %s" % [size, lang, topic.id, clip])
				elif not screen.encloses(box):
					bad.append("%s %s %s: %s off screen" % [size, lang, topic.id, box])
				elif box.intersects(hero_box):
					bad.append("%s %s %s: %s over the hero %s" % [size, lang, topic.id, box, hero_box])
				elif box.end.y > screen.size.y / 3.0:
					bad.append("%s %s %s: %s reaches the middle of the screen" % [size, lang, topic.id, box])
				hint.force_hide()
	loc.apply_language("en")
	root.size = Vector2i(1920, 1080)
	ck(checked > 0 and bad.is_empty(), "%d banners fit, on top, clear of the hero (%s)" % [checked, "; ".join(bad.slice(0, 3))])
