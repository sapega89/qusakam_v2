extends SceneTree

## Дві мови скрізь (BACKLOG 31, design/localization_plan.md, частина 1 — інтерфейс).
##   godot --headless --path . --script res://SampleProject/UI/verify_locale.gd
##
## Для кожної мови обходить усі тексти, які бачить гравець, і падає:
##   en — на будь-якій кирилиці;
##   uk — на будь-якому латинському слові, крім назв клавіш і кнопок (Tab, Esc, LB, RT, A/B/X/Y…)
##        і HP / SP / XP (Sapega 2026-10-21 «HP, SP, XP так і залиш»).
##
##   [0] переклади зареєстровані з коду (без project.godot); en.po і uk.po мають ті самі ключі, кожен перекладений
##   [1] кожна сцена з текстом (.tscn): text / tooltip / placeholder через переклад
##   [2] Settings → Game → Language перемикає мову мишею, клавіатурою і геймпадом — одразу, і мова зберігається
##   [3] обхід екранів у кожній мові: головне меню, Load, HUD, усі вкладки ігрового меню, Misc, усі вкладки Settings,
##       Tutorial (список і вікно теми), Controls, підтвердження виходу, усі модалки ModalTemplates, екран збереження,
##       магазин, крафт (усі станції), меню NPC і зачарування в коваля, Game Over, кінець демо
##
## ЧАСТИНА 2 (дані й діалоги) ЩЕ НЕ ЗРОБЛЕНА: тексти з Resources/Data/*.json і dialogue_quest/*.dqd вирізаються з
## перевіреного рядка (DATA_DEFERRED) і лише рахуються. Частина 2 видаляє цей виняток — тоді verify ловить і їх.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const TEST_DIR := "user://verify_locale/"
const DATA_DIR := "res://SampleProject/Resources/Data/"
const DIALOGUE_DIR := "res://dialogue_quest/"
const PO_DIR := "res://SampleProject/Resources/Translations/"
## Частина 2 вимикає: тоді тексти даних і діалогів перевіряються як усі інші.
const DATA_DEFERRED := true
## Де шукати сцени з текстом для [1].
const SCENE_DIRS := ["res://SampleProject/Scenes/", "res://SampleProject/UI/", "res://SampleProject/Maps/"]
const SCENE_FILES := ["res://SampleProject/MainMenu.tscn", "res://SampleProject/Game.tscn"]
## Заглушки в сценах, які скрипт завжди перезаписує даними (ім'я супутника, репліка) — частина 2 (дані й діалоги).
const RUNTIME_FILLED := {
	"res://SampleProject/Scenes/UI/dialogue_box.tscn": ["DialogueText", "Name"],
	"res://SampleProject/Scenes/UI/companion_joined_notification.tscn": ["NameLabel"],
}

## Латинські слова, дозволені в українській версії: назви кнопок геймпада й клавіш, HP/SP/XP.
## Назви клавіш клавіатури, на які щось призначено, додаються з InputMap (OS.get_keycode_string). Регістр не важить
## (ENTER, SPACE на кнопках).
## L / R — плечові кнопки на нижній панелі магазину й крафту («L/R Switch Category»).
const ALLOW_UK := ["HP", "SP", "XP", "Tab", "Esc", "A", "B", "X", "Y", "LB", "RB", "LT", "RT", "L3", "R3", "L", "R",
	"LS", "RS", "Start", "Back", "Guide"]

var fails: Array[String] = []
var _allow: Dictionary = {}
var _data: Array[String] = []
var _cyrillic := RegEx.create_from_string("[\\x{0400}-\\x{04FF}]")
var _latin_word := RegEx.create_from_string("[A-Za-z]+")
## Мова поточного обходу і знахідки: "текст" → де.
var _locale := ""
var _problems: Dictionary = {}
var _checked := 0
var _deferred := 0
## Екрани обходу, яких не знайшли або на яких не було тексту — обхід мусить їх бачити.
var _missing: Array[String] = []


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	var settings: Dictionary = root.get_node("SaveSystem").settings_module.settings
	settings.tutorial_windows = false  # D289: підказки — плашки, гра не стає на паузу під вікном
	root.get_node("SaveSystem").set_save_dir(TEST_DIR)  # мова пишеться у файл слота — не в справжні сейви
	var loc: Node = root.get_node("LocalizationManager")
	var saved_language: String = loc.get_language()
	_build_allow()
	if DATA_DEFERRED:
		_collect_data_strings()

	print("[0] translations are registered from code, en.po and uk.po carry the same keys")
	ck(TranslationServer.get_loaded_locales().has("en") and TranslationServer.get_loaded_locales().has("uk"),
			"en and uk are loaded (%s)" % str(TranslationServer.get_loaded_locales()))
	var project_list: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	ck(not Array(project_list).any(func(p: String) -> bool: return p.begins_with(PO_DIR)),
			"not through project.godot (runtime TranslationServer.add_translation, D270 pattern)")
	_check_po_files()

	print("[1] every scene text through the translation")
	for lang in ["en", "uk"]:
		_begin(lang)
		TranslationServer.set_locale(lang)
		for path in _scene_paths():
			_scan_packed(path)
		_report("[1] scenes")
	TranslationServer.set_locale(saved_language)

	print("[3a] title screen and Load menu in each language")
	for lang in ["en", "uk"]:
		loc.set_language(lang)
		_begin(lang)
		for path in ["res://SampleProject/MainMenu.tscn", "res://SampleProject/Scenes/Menus/LoadGameMenu.tscn"]:
			var screen: Node = load(path).instantiate()
			root.add_child(screen)
			await Kit.frames(self, 6)
			_scan(screen, path.get_file())
			screen.queue_free()
			await Kit.frames(self, 2)
		_report("[3a] title")

	loc.set_language("en")
	var game: Node = await Kit.boot(self)
	_unlock_tabs(game)

	print("[2] Settings → Game → Language: mouse, keyboard and gamepad switch at once and persist")
	await _language_switch(loc)

	for lang in ["en", "uk"]:
		loc.set_language(lang)
		await Kit.frames(self, 3)
		print("[3] every screen in %s" % lang)
		_begin(lang)
		_missing.clear()
		await _walk(game)
		_report("[3] screens")
		ck(_missing.is_empty(), "[3] %s: every walked screen was found and shows text (missing: %s)" % [lang, str(_missing)])

	loc.set_language(saved_language)
	print("data and dialogue strings left for part 2 (deferred, not checked): %d occurrences" % _deferred)
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


# ── Правила ──────────────────────────────────────────────────────────────────

func _build_allow() -> void:
	for word in ALLOW_UK:
		_allow[word.to_lower()] = true
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
				for m in _latin_word.search_all(OS.get_keycode_string(code)):
					_allow[m.get_string().to_lower()] = true


## Рядки даних і діалогів (частина 2): усі рядкові значення JSON і репліки .dqd, шматками між {дія}.
func _collect_data_strings() -> void:
	var found: Dictionary = {}
	for file in DirAccess.get_files_at(DATA_DIR):
		if file.ends_with(".json"):
			_json_strings(JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + file)), found)
	for dir in DirAccess.get_directories_at(DATA_DIR):
		for file in DirAccess.get_files_at(DATA_DIR + dir):
			if file.ends_with(".json"):
				_json_strings(JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + dir + "/" + file)), found)
	for file in DirAccess.get_files_at(DIALOGUE_DIR):
		if file.ends_with(".dqd"):
			for line in FileAccess.get_file_as_string(DIALOGUE_DIR + file).split("\n"):
				for part in line.split("|"):
					_add_fragments(part.strip_edges(), found)
	_data.assign(found.keys())
	_data.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())


func _json_strings(value: Variant, found: Dictionary) -> void:
	if value is Dictionary:
		for key in value:
			_json_strings(value[key], found)
	elif value is Array:
		for item in value:
			_json_strings(item, found)
	elif value is String:
		_add_fragments(value, found)


func _add_fragments(text: String, found: Dictionary) -> void:
	if text.begins_with("res://") or text.length() < 2:
		return
	var plain := RegEx.create_from_string("\\{[^}]*\\}|\\[[^\\]]*\\]").sub(text, "\n", true)
	for part in plain.split("\n"):
		var piece := part.strip_edges()
		if piece.length() >= 2 and (_latin_word.search(piece) or _cyrillic.search(piece)):
			found[piece] = true


func _begin(lang: String) -> void:
	_locale = lang
	_problems = {}
	_checked = 0


func _check(text: String, where: String) -> void:
	if text.strip_edges().is_empty():
		return
	_checked += 1
	if _ok(text):
		return
	if DATA_DEFERRED:
		var rest := text
		for piece in _data:
			var at := rest.findn(piece)
			while at >= 0:
				rest = rest.substr(0, at) + " " + rest.substr(at + piece.length())
				at = rest.findn(piece)
		if rest != text:
			_deferred += 1
		if _ok(rest):
			return
	if not _problems.has(text):
		_problems[text] = where


func _ok(text: String) -> bool:
	if _locale == "en":
		return _cyrillic.search(text) == null
	for m in _latin_word.search_all(text):
		if not _allow.has(m.get_string().to_lower()):
			return false
	return true


func _report(section: String) -> void:
	for text in _problems:
		print("    [%s] %s: %s" % [_locale, _problems[text], JSON.stringify(text)])
	var rule := "no Cyrillic" if _locale == "en" else "no Latin words outside the key-name allow-list"
	ck(_problems.is_empty(), "%s %s: %s (%d texts, %d wrong)" % [section, _locale, rule, _checked, _problems.size()])


# ── [0] .po ──────────────────────────────────────────────────────────────────

func _check_po_files() -> void:
	var en: Translation = load(PO_DIR + "en.po")
	var uk: Translation = load(PO_DIR + "uk.po")
	var en_keys: Array = Array(en.get_message_list())
	var uk_keys: Array = Array(uk.get_message_list())
	var only_en: Array = en_keys.filter(func(k: String) -> bool: return not uk_keys.has(k))
	var only_uk: Array = uk_keys.filter(func(k: String) -> bool: return not en_keys.has(k))
	ck(only_en.is_empty() and only_uk.is_empty(), "same keys in en.po and uk.po (%d; only en %s, only uk %s)"
			% [uk_keys.size(), str(only_en.slice(0, 5)), str(only_uk.slice(0, 5))])
	_begin("uk")
	# {дія} — назва кнопки, яку підставляє InputGlyphs; KEY / ACTION — підстановки аддона maaacks у його рядку.
	var placeholders := RegEx.create_from_string("\\{[a-z_]+\\}|\\bKEY\\b|\\bACTION\\b")
	for key in uk_keys:
		var value := String(uk.get_message(key))
		if value.is_empty():
			_problems[key] = "uk.po: no translation"
		else:
			_check(placeholders.sub(value, "", true), "uk.po")
	_report("[0] uk.po values")
	_begin("en")
	for key in en_keys:
		_check(String(key), "en.po key")
		_check(String(en.get_message(key)), "en.po value")
	_report("[0] en.po keys")


# ── [1] сцени ────────────────────────────────────────────────────────────────

func _scene_paths() -> Array[String]:
	var out: Array[String] = []
	out.assign(SCENE_FILES)
	for dir in SCENE_DIRS:
		_find_scenes(dir, out)
	out = out.filter(func(p: String) -> bool: return not p.contains("/Test/"))  # налагоджувальні сцени, не в грі
	var has_text := RegEx.create_from_string("(?m)^(text|tooltip_text|placeholder_text|title) = \"[^\"]")
	return out.filter(func(p: String) -> bool:
		var source := FileAccess.get_file_as_string(p)
		return has_text.search(source) != null and _loads(p, source))


## Мертві сцени, чиїх скриптів уже немає (design/scene_inventory.md), гравець не бачить — їх пропускаємо з позначкою.
func _loads(path: String, source: String) -> bool:
	for m in RegEx.create_from_string("\\[ext_resource[^\\]]* path=\"([^\"]+)\"").search_all(source):
		if not ResourceLoader.exists(m.get_string(1)) and not FileAccess.file_exists(m.get_string(1)):
			if _locale == "en":
				print("    skipped (broken, unreachable): %s → missing %s" % [path, m.get_string(1)])
			return false
	return true


func _find_scenes(dir: String, out: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn") and not out.has(dir + file):
			out.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		_find_scenes(dir + sub + "/", out)


## Без дерева: _ready не біжить, видно лише тексти, записані у .tscn. Вузли зі сцен аддонів (заглушки на кшталт
## «Lorem ipsum», які аддон завжди перезаписує) і властивості, які перевизначає скрипт, перевіряє лише обхід [3].
func _scan_packed(path: String) -> void:
	var scene: Node = load(path).instantiate()
	for node in [scene] + scene.find_children("*", "", true, false):
		if node.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
			continue
		if node.owner != null and node.owner.scene_file_path.begins_with("res://addons/"):
			continue
		var source_scene: String = node.owner.scene_file_path if node.owner != null else scene.scene_file_path
		if node != scene and RUNTIME_FILLED.get(source_scene, []).has(String(node.name)):
			continue
		var script: Script = node.get_script()
		var own: Array = script.get_script_property_list().map(func(p: Dictionary) -> String: return p.name) if script else []
		for prop in ["text", "tooltip_text", "placeholder_text", "action_text"]:
			if own.has(prop):
				continue
			var value: Variant = node.get(prop)
			if value is String and (node is Control or prop == "action_text"):
				_check(TranslationServer.translate(value), "%s:%s.%s" % [path.get_file(), node.name, prop])
	scene.free()


# ── [3] живі екрани ──────────────────────────────────────────────────────────

func _shown(c: Control, text: String) -> String:
	return c.atr(text) if c.can_auto_translate() else text


## Перевіряє видимі тексти під [param node]; повертає, скільки їх було (0 — екран не знайдено або порожній).
func _scan(node: Node, where: String) -> int:
	if node == null:
		_missing.append(where)
		return 0
	var before := _checked
	for n in [node] + node.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		var at := "%s:%s" % [where, c.name]
		if c is RichTextLabel:
			_check((c as RichTextLabel).get_parsed_text(), at)
		elif c is Label:
			_check(_shown(c, (c as Label).text), at)
		elif c is OptionButton:
			for i in (c as OptionButton).item_count:
				_check(_shown(c, (c as OptionButton).get_item_text(i)), at)
		elif c is Button:
			_check(_shown(c, (c as Button).text), at)
		elif c is LineEdit:
			_check(_shown(c, (c as LineEdit).placeholder_text), at)
		if not c.tooltip_text.is_empty():
			_check(_shown(c, c.tooltip_text), at + ".tooltip")
	if _checked == before:
		_missing.append(where)
	return _checked - before


func _ui() -> Node:
	return root.get_node("ServiceLocator").get_ui_manager()


func _modal() -> Control:
	return _ui().get_modal_layer().active_modal


func _close_modal() -> void:
	var layer: Node = _ui().get_modal_layer()
	if layer.active_modal != null:
		layer._close_with_result("cancel", layer.active_modal)
	await Kit.frames(self, 4)


func _unlock_tabs(game: Node) -> void:
	for f in ["village_abduction_complete", "village_oldman_healed", "village_oldman_gift", "village_left_complete"]:
		game.set_quest_flag(f, true)


func _walk(game: Node) -> void:
	_scan(game, "HUD")
	_scan(_ui().get_state_root().get_tree().root, "HUD root")

	_ui().open_game_menu()
	await Kit.frames(self, 16)
	var menu: Node = get_first_node_in_group("game_menu")
	for button in (menu.get_node("%InventoryButton") as Button).button_group.get_buttons():
		var tab: String = button.get_meta("tab")
		if tab == "Misc":
			continue
		menu.switch_to_tab(tab)
		await Kit.frames(self, 6)
		_scan(menu, "Game Menu/" + tab)

	print("  Misc modal")
	menu._onmisc_button_pressed()
	await Kit.frames(self, 6)
	_scan(_modal(), "Misc modal")
	await _close_modal()

	menu.switch_to_tab("Journal")
	await Kit.frames(self, 6)
	var journal: Node = menu.find_child("JournalComponent", true, false)
	for section in journal.SECTIONS:
		journal.select_section(section)
		await Kit.frames(self, 4)
		_scan(menu, "Journal/" + section)

	menu.switch_to_tab("Equipment")
	await Kit.frames(self, 6)
	var equipment: Node = menu.find_child("EquipmentComponent", true, false)
	(equipment._slot_rows["sword"] as Button).pressed.emit()
	await Kit.frames(self, 6)
	_scan(_modal(), "Equip picker")
	await _close_modal()

	menu.switch_to_tab("Misc")
	await Kit.frames(self, 6)
	var opts: Node = get_first_node_in_group("settings_screen")
	for tab in opts.TABS:
		opts.switch_to_tab(tab.id)
		await Kit.frames(self, 4)
		_scan(menu, "Settings/" + tab.id)

	menu._on_misc_tutorial_selected()
	await Kit.frames(self, 6)
	_scan(menu, "Tutorial list")
	var topics: Array = menu.get_node("%TutorialComponent").get_node("%TopicList").get_children()
	if not topics.is_empty():
		(topics[0] as Button).pressed.emit()
		await Kit.frames(self, 8)
		if _modal() != null:
			_scan(_modal(), "Tutorial window")
			await _close_modal()
	menu._on_misc_controls_selected()
	await Kit.frames(self, 6)
	_scan(menu, "Controls")

	menu.request_exit_to_main_menu()
	await Kit.frames(self, 6)
	_scan(_modal(), "Exit to title confirm")
	await _close_modal()
	menu._on_misc_exit_game_selected()
	await Kit.frames(self, 6)
	_scan(_modal(), "Exit game confirm")
	await _close_modal()
	menu._pending_exit_action = ""
	_ui().close_game_menu()
	await Kit.frames(self, 8)

	print("  modal templates")
	await _walk_templates()

	print("  save screen")
	_ui().open_save_game()
	await Kit.frames(self, 10)
	_scan(_ui().get_state_root(), "Save screen")
	_ui().close_state()
	await Kit.frames(self, 8)

	print("  shop, crafting, NPC menu, enchanting")
	await _walk_trade(game)

	print("  NPC menus: merchant, blacksmith, oath keeper (and its confirm)")
	await _walk_npcs(game)

	print("  notifications: level up, companion joined, cutscene skip prompt")
	await _walk_notifications(game)

	print("  game over, demo end")
	await _walk_end_screens(game)


func _walk_templates() -> void:
	var t: GDScript = preload("res://SampleProject/Scripts/UI/modal_templates.gd")
	var item := "Iron Sword"  # назва з даних — частина 2
	var datas: Array[Dictionary] = [t.confirm_exit(), t.unsaved_changes(), t.reset_settings(), t.delete_save(),
		t.overwrite_save(), t.buy_confirm(item, 2, "₹ 120"), t.craft_confirm(item, PackedStringArray(["Iron Ingot x3"]), "₹ 10"),
		t.cannot_craft("Not enough materials."), t.enchant_confirm(item, item + " +1", "₹ 10"),
		t.cannot_enchant("Not enough coins."), t.game_saved(), t.save_failed(), t.item_pickup(item, 2),
		t.cannot_use(item), t.confirm_exit_to_main_menu(), t.confirm_exit_game_unsaved()]
	for data in datas:
		_ui().show_modal(data)
		await Kit.frames(self, 4)
		_scan(_modal(), "Modal \"%s\"" % data.get("title", "?"))
		await _close_modal()


func _walk_trade(game: Node) -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + "merchants.json"))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var shop: Control = load("res://SampleProject/Scenes/Shop/shop_menu.tscn").instantiate()
	layer.add_child(shop)
	await process_frame
	shop.setup_shop(j.merchants.default.items)
	await Kit.frames(self, 4)
	_scan(shop, "Shop")
	var next := InputEventAction.new()
	next.action = &"menu_next_tab"
	next.pressed = true
	for i in 6:
		shop._input(next)
		await Kit.frames(self, 2)
		_scan(shop, "Shop/category %d" % i)
	shop.queue_free()

	var craft: Control = load("res://SampleProject/Scenes/Crafting/crafting_menu.tscn").instantiate()
	layer.add_child(craft)
	await Kit.frames(self, 6)
	for station in craft._station_tabs.size():
		craft._set_station(station)
		await Kit.frames(self, 3)
		_scan(craft, "Crafting/station %d" % station)
	craft.queue_free()
	layer.queue_free()
	paused = false
	await Kit.frames(self, 3)

	var smith: Node = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/blacksmith.tscn").instantiate()
	game.add_child(smith)
	await process_frame
	smith.interactable.interacted.emit()
	await Kit.frames(self, 4)
	_scan(smith.npc_menu, "Blacksmith NPC menu")
	smith.npc_menu.chosen.emit(&"enchant")
	await Kit.frames(self, 6)
	if smith.screen_instance != null:
		_scan(smith.screen_instance, "Enchanting")
		await Kit.key(self, KEY_ESCAPE)
	smith.queue_free()
	await Kit.frames(self, 4)


func _walk_npcs(game: Node) -> void:
	for npc_name in ["merchant", "blacksmith", "oath_priest"]:
		var npc: NpcBase = load("res://SampleProject/Scenes/Gameplay/Objects/NPCs/%s.tscn" % npc_name).instantiate()
		game.add_child(npc)
		await process_frame
		npc.interactable.interacted.emit()
		await Kit.frames(self, 4)
		_scan(npc.npc_menu, "NPC menu/" + npc_name)
		if npc_name == "oath_priest":
			npc.npc_menu.chosen.emit(&"oath")
			await Kit.frames(self, 4)
			_scan(npc.npc_menu, "NPC menu/oath confirm")
		npc.queue_free()
		await Kit.frames(self, 3)


func _walk_notifications(game: Node) -> void:
	var nodes: Array = game.find_children("*", "", true, false)
	var level_up: Array = nodes.filter(func(n: Node) -> bool: return n.has_method("show_notification"))
	if not level_up.is_empty():
		level_up[0].show_notification(2)
		await Kit.frames(self, 4)
		_scan(level_up[0], "Level up")
	else:
		_missing.append("Level up")
	var joined: Array = nodes.filter(func(n: Node) -> bool: return n.has_method("_on_companion_joined"))
	if not joined.is_empty():
		joined[0]._on_companion_joined("alisia")
		await Kit.frames(self, 4)
		_scan(joined[0], "Companion joined")
	else:
		_missing.append("Companion joined")
	var layer := CanvasLayer.new()
	game.add_child(layer)
	var prompt: Node = load("res://SampleProject/Scenes/UI/cutscene_skip_prompt.tscn").instantiate()
	layer.add_child(prompt)
	await Kit.frames(self, 4)
	prompt.visible = true
	_scan(prompt, "Cutscene skip prompt")
	layer.queue_free()
	await Kit.frames(self, 3)


func _walk_end_screens(game: Node) -> void:
	var player: Node = get_first_node_in_group(&"player")
	GameOverScreen.present(player)
	await Kit.frames(self, 6)
	var over: Node = get_first_node_in_group(&"game_over_screen")
	if over != null:
		over.change_scenes = false
		_scan(over, "Game Over")
		over.get_parent().queue_free()
	paused = false
	await Kit.frames(self, 3)
	var end: Node = load("res://SampleProject/Scenes/UI/DemoEndScreen.tscn").instantiate()
	game.add_child(end)
	await Kit.frames(self, 6)
	_scan(end, "Demo end")
	end.queue_free()
	paused = false
	await Kit.frames(self, 3)


# ── [2] перемикач мови ───────────────────────────────────────────────────────

func _language_cells(opts: Node) -> Array:
	for margin in opts._list.get_children():
		if margin.get_child_count() > 0 and margin.get_child(0).name == "Language":
			return margin.get_child(0).get_node(^"Segments").get_child(0).get_children()
	return []


## Текст клітинки без позначки вибраної «✓ ».
func _cell(cell: Button) -> String:
	return _shown(cell, cell.text).trim_prefix("✓ ")


func _language_switch(loc: Node) -> void:
	_ui().open_game_menu()
	await Kit.frames(self, 16)
	var menu: Node = get_first_node_in_group("game_menu")
	menu.switch_to_tab("Misc")
	await Kit.frames(self, 6)
	var opts: Node = get_first_node_in_group("settings_screen")
	opts.switch_to_tab("game")
	await Kit.frames(self, 4)
	var inventory_tab: Button = menu.get_node("%InventoryButton")
	var cells: Array = _language_cells(opts)
	ck(cells.size() == 2, "Language row has English and Ukrainian (%d cells)" % cells.size())
	if cells.size() != 2:
		_ui().close_game_menu()
		return
	ck(_cell(cells[0]) == "English" and _cell(cells[1]) == "Ukrainian",
			"in English the cells read English | Ukrainian (%s | %s)" % [_cell(cells[0]), _cell(cells[1])])

	await Kit.mouse(self, cells[1])
	ck(loc.get_language() == "uk" and TranslationServer.get_locale() == "uk", "mouse click on Ukrainian → uk")
	ck(_shown(inventory_tab, inventory_tab.text) == "Інвентар", "the tab names switch at once (%s)" % _shown(inventory_tab, inventory_tab.text))
	ck(root.get_node("SaveSystem").get_language() == "uk", "the choice is kept in the settings")
	# HUD під меню, складений ще англійською (рівень, XP, зброя), перекладається одразу, не після наступної події.
	_begin("uk")
	_missing.clear()
	_scan(get_first_node_in_group(&"player").get_tree().current_scene, "HUD after the switch")
	_report("[2] HUD under the menu right after the switch")
	cells = _language_cells(opts)
	ck(_cell(cells[0]) == "Англійська" and _cell(cells[1]) == "Українська",
			"in Ukrainian the cells read Англійська | Українська (%s | %s)" % [_cell(cells[0]), _cell(cells[1])])

	# Клавіатура як у гравця: → / Enter з вкладок переводить FocusRouter у вміст, далі фокус на клітинці.
	menu.focus_router.focus_content()
	cells[0].grab_focus()
	await Kit.frames(self, 2)
	await Kit.key(self, KEY_ENTER)
	ck(loc.get_language() == "en", "keyboard Enter on English → en")
	ck(_shown(inventory_tab, inventory_tab.text) == "Inventory", "tab back to Inventory")

	cells = _language_cells(opts)
	cells[1].grab_focus()
	await Kit.pad(self, JOY_BUTTON_A)
	ck(loc.get_language() == "uk", "gamepad A on Ukrainian → uk")
	cells = _language_cells(opts)
	cells[0].grab_focus()
	await Kit.pad(self, JOY_BUTTON_A)
	ck(loc.get_language() == "en", "gamepad A on English → en")
	# Запуск гри: збережена мова застосовується, коли SaveSystem завантажує налаштування слота.
	var module: Node = root.get_node("SaveSystem").settings_module
	module.load_data(module.save().merged({"language": "uk"}, true))
	ck(loc.get_language() == "uk" and TranslationServer.get_locale() == "uk", "a saved uk is applied when settings load")
	module.load_data(module.save().merged({"language": "en"}, true))
	_ui().close_game_menu()
	await Kit.frames(self, 8)
