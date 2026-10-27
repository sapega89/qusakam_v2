extends SceneTree

## Самоперевірка бойового HUD (Phase 5.12 — виправлення після код-рев'ю).
##   godot --headless --path . --script res://SampleProject/UI/verify_combat_hud.gd
##
## Покриває три підтверджені дефекти:
##   1. HP бралося з неіснуючого HealthComponent і бар завжди був повний
##   2. панель заповнювалась один раз у _ready() і більше не оновлювалась
##   3. HUD стояв поза піддеревом GameUITheme

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _hp_text(panel: Node) -> String:
	return panel._rows_by_id["HP"].get_node(^"Value").text

func _row_value(panel: Node, id: String) -> String:
	return panel._rows_by_id[id].get_node(^"Value").text

func _row_bar(panel: Node, id: String) -> ProgressBar:
	return panel._rows_by_id[id].get_node(^"Bar")


func _initialize() -> void:
	load("res://SampleProject/Scripts/Combat/CombatRolls.gd").calm()  # D393: без крита й ухилення — шкода точна
	await process_frame
	await process_frame
	var sl: Node = root.get_node_or_null("ServiceLocator")
	var tokens = load("res://SampleProject/UI/Tokens/UITokens.gd")

	print("[1] game scene boots with the HUD attached")
	# Нова гра, а не slot_01 з user:// — інакше герой локального сейву (пасивки, щит) ріже шкоду й SP.
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	# Player._initialize_health_bar() рекурсивно відкладає себе без current_scene.
	current_scene = game
	for i in 30: await process_frame
	var hud_root: Node = game.get_node_or_null(^"UICanvas/CombatHUD")
	ck(hud_root != null, "CombatHUD wrapper exists under UICanvas")
	var vitals: Node = get_first_node_in_group("player_vitals_panel")
	ck(vitals != null, "vitals panel present")
	if vitals == null or hud_root == null:
		_done()
		return
	ck(vitals.get_parent() == hud_root, "vitals panel lives inside the themed wrapper")

	print("[2] HP is bound to the authoritative player state")
	var player: Node = get_first_node_in_group(&"player")
	ck(player != null, "player node resolved")
	if player == null:
		_done()
		return
	ck("current_health" in player, "player carries current_health (CombatBody2D)")
	ck(player.get_node_or_null(^"HealthComponent") == null,
			"player has no HealthComponent — the old HUD path was reading nothing")
	ck(vitals._player == player, "HUD binds the same node gameplay damages")
	var max_hp: int = int(player.Max_Health)
	ck(_hp_text(vitals) == "%d / %d" % [int(player.current_health), max_hp],
			"HUD shows the real starting HP (%s)" % _hp_text(vitals))

	print("[3] damage moves the HUD value live")
	var before_hp: int = int(player.current_health)
	player.take_damage(30)
	for i in 4: await process_frame
	ck(int(player.current_health) == before_hp - 30, "gameplay applied the damage")
	ck(_hp_text(vitals) == "%d / %d" % [before_hp - 30, max_hp],
			"HUD followed the damage without a manual refresh (%s)" % _hp_text(vitals))
	ck(_row_bar(vitals, "HP").value == float(before_hp - 30), "HP bar fill tracks the value")
	ck(_row_bar(vitals, "HP").value < _row_bar(vitals, "HP").max_value,
			"bar is no longer pinned full")

	print("[4] healing moves it back")
	player.heal_damage(20)
	for i in 4: await process_frame
	ck(_hp_text(vitals) == "%d / %d" % [before_hp - 10, max_hp],
			"HUD followed the heal (%s)" % _hp_text(vitals))

	print("[5] max HP changes are reflected")
	player.Max_Health = max_hp + 50
	player.health_changed.emit(player.current_health, player.Max_Health, false)
	for i in 4: await process_frame
	ck(_hp_text(vitals).ends_with("/ %d" % (max_hp + 50)),
			"HUD shows the new maximum (%s)" % _hp_text(vitals))
	ck(_row_bar(vitals, "HP").max_value == float(max_hp + 50), "bar max tracks Max_Health")
	# Рівень підіймає Max_Health у Player.gd — раніше без сигналу.
	var lvl_src: String = FileAccess.open(
		"res://SampleProject/Scripts/Player.gd", FileAccess.READ).get_as_text()
	ck(lvl_src.find("health_changed.emit(current_health, Max_Health, true)") != -1,
			"level-up path emits health_changed")

	print("[6] HUD and gameplay never diverge")
	player.take_damage(15)
	for i in 4: await process_frame
	ck(_hp_text(vitals) == "%d / %d" % [int(player.current_health), int(player.Max_Health)],
			"single source of truth after three mutations")
	var panel_src: String = FileAccess.open(
		"res://SampleProject/UI/Components/player_vitals_panel.gd", FileAccess.READ).get_as_text()
	ck(panel_src.find("HealthComponent") == -1, "dead HealthComponent path removed")
	ck(panel_src.find("func _process") == -1, "no per-frame polling")

	print("[7] unresolvable source reads honestly, not full")
	var stash_player: Node = vitals._player
	vitals._player = null
	player.remove_from_group(&"player")
	vitals.refresh()
	await process_frame
	ck(_hp_text(vitals) == "— / —", "HP shows unknown when the player cannot be resolved (%s)" % _hp_text(vitals))
	ck(_row_bar(vitals, "HP").value == 0.0, "bar empty, not full, when unresolved")
	player.add_to_group(&"player")
	vitals._player = stash_player
	vitals.refresh()
	await process_frame

	print("[8] SP updates live")
	var skills: Node = sl.get_skill_manager()
	ck(skills != null, "skill manager present")
	if skills:
		# Продакшн skills.json порожній, тож SP-пул тут задаємо як фікстуру.
		skills.set_max_sp(50)
		skills.restore_sp(50)
		for i in 3: await process_frame
		var sp_before: String = _row_value(vitals, "SP")
		ck(sp_before == "50 / 50", "SP row picked up the pool (%s)" % sp_before)
		ck(skills.spend_sp(5), "gameplay spent SP")
		for i in 4: await process_frame
		ck(_row_value(vitals, "SP") != sp_before,
				"SP row changed on sp_changed (%s -> %s)" % [sp_before, _row_value(vitals, "SP")])
		ck(_row_value(vitals, "SP") == "%d / %d" % [skills.get_current_sp(), skills.get_max_sp()],
				"SP matches SkillManager")

	print("[9] XP and level: the full-width bar along the bottom and the level diamond (D552)")
	var xp: Node = sl.get_xp_manager()
	ck(xp != null, "xp manager present")
	ck(not vitals._rows_by_id.has("XP") and vitals._rows_by_id.keys() == ["HP", "SP", "ST"], "the hero panel has HP, SP and ST, no XP (D775, D552)")
	var xp_bar: ProgressBar = get_first_node_in_group("hud_xp_bar")
	ck(xp_bar != null and xp_bar.get_parent() == hud_root, "the XP bar lives in the themed HUD")
	if xp and xp_bar:
		var view: Vector2 = hud_root.size
		ck(xp_bar.size == Vector2(view.x, 10) and xp_bar.position == Vector2(0, view.y - 10),
				"full width, 10 px, at the bottom edge (%s at %s, view %s)" % [xp_bar.size, xp_bar.position, view])
		ck(not xp_bar.show_percentage and xp_bar.get_children().is_empty(), "no label and no numbers")
		ck(xp_bar.theme_type_variation == &"HudXpBar", "drawn by the theme, no texture")
		var fill: StyleBoxFlat = xp_bar.get_theme_stylebox("fill")
		var track: StyleBoxFlat = xp_bar.get_theme_stylebox("background")
		ck(fill.bg_color == tokens.ACCENT and fill.border_width_top == tokens.HUD_BAR_HIGHLIGHT_XP, "gold fill, 2 px highlight")
		ck(track.bg_color == tokens.HUD_BAR_BG and track.border_width_top == 1 and track.border_color == tokens.HUD_RIM
				and track.border_width_left == 0, "black 60 % track with a 1 px top rim")
		var ratio_before: float = xp_bar.value
		xp.add_xp(10)
		for i in 4: await process_frame
		ck(xp_bar.value != ratio_before, "XP bar moved on xp_gained (%.3f -> %.3f)" % [ratio_before, xp_bar.value])
		ck(is_equal_approx(xp_bar.value, xp.get_xp_percentage()), "XP bar = XPManager share to the next level")
		var lvl_before: String = vitals._level_label.text
		xp.add_xp(100000)
		for i in 6: await process_frame
		ck(vitals._level_label.text != lvl_before,
				"level diamond followed the level-up (%s -> %s)" % [lvl_before, vitals._level_label.text])
		ck(vitals._level_label.text == str(xp.get_level()), "level diamond matches XPManager")
		if xp.is_max_level():
			ck(xp_bar.value == xp_bar.max_value, "at the cap the XP bar stays full (D541)")
	var hotbar_node: Control = get_first_node_in_group("skill_hotbar")
	if hotbar_node and xp_bar:
		var gap: float = xp_bar.global_position.y - (hotbar_node.global_position.y + hotbar_node.size.y)
		ck(is_equal_approx(gap, 4.0) and is_equal_approx(hotbar_node.global_position.x + hotbar_node.size.x / 2.0, hud_root.size.x / 2.0),
				"hotbar centred, 4 px above the XP bar (gap %.1f)" % gap)

	print("[9b] the hero panel v2: layout, portrait, class, Q chip")
	ck(vitals.position == Vector2(24, 24) and vitals.size == Vector2(520, 220), "panel at (24, 24), 520 × 220 (the ST row, plate 144 tall, D775)")
	ck(vitals.get_node(^"%Portrait").texture == load("res://SampleProject/Sprites/Player/portrait.tres"), "hero portrait (D534)")
	ck(vitals.get_node(^"%Portrait").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "portrait nearest-filtered")
	ck((vitals.get_node(^"%PortraitMask") as Polygon2D).clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW, "portrait clipped to the hexagon")
	var oath: String = sl.get_skill_manager().get_oath()
	ck(vitals._class_label.text == (tr(root.get_node(^"SkillDatabase").class_name_trunk) if oath == "" else tr(String(root.get_node(^"SkillDatabase").get_oath(oath).name))),
			"class reads the oath or Holy Warrior (%s)" % vitals._class_label.text)
	ck(vitals.get_node(^"Curl").flip_h, "curl mirrored on the right end")
	var chip: Control = vitals.get_node(^"%PotionChip")
	ck(chip.get_node(^"Pill/Count").text == "×%d" % load("res://SampleProject/Scripts/Combat/QuickPotion.gd").count(), "Q chip counts the potions")
	ck(chip.get_node(^"Badge/Key").text == "Q", "Q chip badge names the key")
	ck(vitals.get_node(^"%AssistChip").position == Vector2(134, 158) and chip.position == Vector2(200, 158), "F and Q chips under the plate")
	var hp_fill: StyleBoxFlat = _row_bar(vitals, "HP").get_theme_stylebox("fill")
	ck(hp_fill.bg_color == tokens.HP_FILL and hp_fill.border_width_top == tokens.HUD_BAR_HIGHLIGHT_ROW, "HP fill with a 3 px highlight")

	print("[10] Combat HUD resolves GameUITheme at runtime")
	ck(hud_root.theme != null, "wrapper carries a theme")
	ck(hud_root.theme.resource_path.ends_with("GameUITheme.tres"), "it is the shared theme")
	# has_theme_*() марне як проба: дефолтна тема відповідає true на будь-який тип.
	# Єдиний чесний доказ — збіг РЕЗОЛЬВНУТОГО значення з токеном.
	var name_label: Label = vitals._name_label
	ck(name_label.get_theme_font_size("font_size", "VitalsName") == tokens.SIZE_HUD_NAME,  # HUD v2: Figma-розмір як є
			"font size from tokens (%d)" % name_label.get_theme_font_size("font_size", "VitalsName"))
	ck(name_label.get_theme_color("font_color", "VitalsName") == tokens.HUD_GOLD_LIGHT, "colour from tokens")
	ck(name_label.get_theme_font("font", "VitalsName") != null, "font resource resolves")
	var hotbar: Node = get_first_node_in_group("skill_hotbar")
	if hotbar:
		ck(hotbar.get_theme_font_size("font_size", "BindBadge") == tokens.SIZE_HUD_KEY,  # HUD v2
				"bind badge size from tokens")
		ck(hotbar.get_theme_color("font_color", "CooldownLabel") == tokens.TEXT_PRIMARY,
				"cooldown colour from tokens")
	var top: Node = game.get_node_or_null(^"UICanvas/CombatHUD/CombatHudTop")
	# HUD-панелі (QuestPanel, CurrencyDisplay) — звичайний PanelContainer; SidePanel — поверхня меню (MENU_SURFACE, B8).
	var hud_box: StyleBox = top.get_node(^"QuestPanel").get_theme_stylebox("panel") if top else null
	ck(hud_box is StyleBoxFlat and (hud_box as StyleBoxFlat).bg_color == UITokens.SURFACE,
			"stylebox resolves to the token surface for HUD chrome")

	print("[11] isolation preserved")
	var minimap: Node = game.find_child("Minimap", true, false)
	ck(minimap != null, "third-party MetSys Minimap present for comparison")
	if minimap:
		ck(minimap.get_theme_font_size("font_size", "VitalsName") != tokens.SIZE_HUD_NAME,
				"addon UI does NOT resolve GameUITheme sizes (%d)"
				% minimap.get_theme_font_size("font_size", "VitalsName"))
		ck(minimap.get_theme_color("font_color", "VitalsName") != tokens.ACCENT,
				"addon UI does NOT resolve GameUITheme colours")
	var legacy: Node = game.get_node_or_null(^"UICanvas/CoinCounter")
	ck(legacy != null, "legacy CoinCounter still under UICanvas, outside the wrapper")
	if legacy:
		ck(legacy.get_theme_font_size("font_size", "VitalsName") != tokens.SIZE_HUD_NAME,
				"legacy UICanvas widgets keep their own look")
	var proj_theme: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	ck(proj_theme == "", "theme is still not project-global")
	_done()


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
