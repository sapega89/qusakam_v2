extends SceneTree

## Every hint is a tutorial window (BACKLOG 12, D289), real input:
##   godot --headless --path . --script res://SampleProject/UI/verify_tutorial_hints.gd
##   1. After the Canyon intro the movement hint opens the tutorial window, the game paused; keyboard names (A / D).
##   2. Pad B closes it, the game runs again; the next hint (first enemy) names the pad button (X) after pad input.
##   3. The hero is hit: Block and Parry names LB on the pad; Esc closes it.
##   4. Game Menu → Misc → Tutorial (mouse): the seen topics are listed after the general ones, unseen are not;
##      a click opens that topic.
##   5. Settings → Game → Tutorial Windows: Off (mouse click). The next hint (second kill = heavy attack) is a
##      banner, no window, and still lands in the list. Seen topics are saved with the player.

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


func _wait_window() -> Node:
	for i in 300:
		if _window() != null:
			break
		await process_frame
	await Kit.frames(self, 3)
	return _window()


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

	print("[1] Movement hint opens the tutorial window")
	await _wait_window()
	ck(_title() == "Moving and Jumping", "window on the movement topic (%s)" % _title())
	ck(paused, "the game is paused under it")
	ck(_body().contains("A / D") and _body().contains("Space"), "keyboard names (%s)" % _body())
	# D474: вікно туторіалу ×1.5 (тіло ≥ 24, клавіша ≥ 20), уміщається в екран — нічого не обрізано.
	var win: Control = _window()
	ck(win.get_node("%Body").get_theme_font_size(&"font_size") >= UITokens.INGAME_BODY_MIN
			and win.get_node("%Key").get_theme_font_size(&"font_size") >= UITokens.INGAME_LABEL_MIN,
			"D474: window body %d px, key %d px" % [win.get_node("%Body").get_theme_font_size(&"font_size"), win.get_node("%Key").get_theme_font_size(&"font_size")])
	var win_clip: String = TextFit.clipped(win)
	ck(win_clip == "", "D474: nothing clipped in the tutorial window (%s)" % win_clip)

	print("[2] Pad B closes; the next hint names pad buttons")
	await Kit.pad(self, JOY_BUTTON_B)
	ck(_window() == null and not paused, "pad B closed it, game runs")
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)  # геймпад — останній пристрій
	root.get_node("EventBus").enemy_spawned.emit("test_enemy", Vector2.ZERO)
	await _wait_window()
	ck(_title() == "Attacking" and _body().contains("Press X"), "attack topic names X on the pad (%s)" % _body())
	ck(_window().get_node("%Key").text == "X", "key badge X (%s)" % _window().get_node("%Key").text)
	await Kit.key(self, KEY_SPACE)
	ck(_body().contains("Left Mouse"), "switching to the keyboard renames it (%s)" % _body())
	await Kit.pad(self, JOY_BUTTON_B)
	ck(_window() == null, "closed")
	root.get_node("EventBus").enemy_spawned.emit("test_enemy_2", Vector2.ZERO)
	await Kit.frames(self, 10)
	ck(_window() == null, "a seen topic does not open again")

	print("[3] First hit on the hero: block and parry")
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	root.get_node("EventBus").player_staggered.emit(0.3)
	await _wait_window()
	ck(_title() == "Block and Parry" and _body().contains("Hold LB"), "block topic names LB (%s)" % _body())
	# B143, D573/D574: жовтий відблиск — парирування, червоний — ухилитися
	ck(_body().contains("glints yellow") and _body().contains("A red glint cannot be blocked or parried") and not _body().contains("glints red"),
			"block topic: yellow = parry, red = roll (B143)")
	await Kit.key(self, KEY_ESCAPE)
	ck(_window() == null and not paused, "Esc closed it")
	ck(get_first_node_in_group("game_menu") == null, "Esc did not open the Game Menu")

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
	ck(listed.slice(4) == ["Moving and Jumping", "Attacking", "Block and Parry"], "then the seen hints (%s)" % [listed.slice(4)])
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
	root.get_node("EventBus").enemy_died.emit("e1", Vector2.ZERO)
	root.get_node("EventBus").enemy_died.emit("e2", Vector2.ZERO)
	await Kit.frames(self, 10)
	var hint: Node = get_first_node_in_group(&"tutorial_hint_display")
	ck(_window() == null, "no window with the setting off")
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
