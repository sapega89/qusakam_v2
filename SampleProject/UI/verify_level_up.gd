extends SceneTree

## Сповіщення про рівень (D436): кожен рівень — панель угорі по центру з нагородами одного рівня
## (attributes.json, SkillManager.JP_PER_LEVEL; HP і шкоди рівень сам не дає, D841); з'являється й гасне;
## кілька рівнів — у черзі; на кепі (D541) сповіщення немає.
##   godot --headless --path . --script res://SampleProject/UI/verify_level_up.gd

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _initialize() -> void:
	await process_frame
	await process_frame
	var sl: Node = root.get_node("ServiceLocator")
	var xp: Node = sl.get_xp_manager()
	xp.reset()
	var note: Control = load("res://SampleProject/Scenes/UI/level_up_notification.tscn").instantiate()
	root.add_child(note)
	await process_frame
	var Note: Script = note.get_script()  # константи часу; preload не компілюється до автозавантажень
	var panel: Control = note.get_node("Panel")
	var rows: Node = note.get_node("Panel/Column/Rows")
	var attr_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://SampleProject/Resources/Data/attributes.json"))

	print("[1] Hidden until a level-up")
	ck(not note.visible and note.pending() == 0, "hidden at start")

	print("[2] One level: the panel fades in at the top centre with one level's rewards")
	xp.add_xp(xp.xp_for_next_level)
	await process_frame
	ck(note.visible and note.pending() == 1, "shown on level-up")
	ck(note.modulate.a < 1.0, "starts transparent (fade in)")
	ck(note.get_node("%LevelLabel").text == "Level 2", "Level 2 (%s)" % note.get_node("%LevelLabel").text)
	ck(rows.get_children().map(func(r: Node) -> String: return r.name) == ["AttributePoints", "JobPoints"],
			"only the points the player spends, no automatic Max HP or Damage (D841: %s)" % [rows.get_children().map(func(r: Node) -> String: return r.name)])
	ck(rows.get_node("AttributePoints/Value").text == "+%d" % int(attr_data.points_per_level), "Attribute Points from attributes.json (%s)" % rows.get_node("AttributePoints/Value").text)
	ck(rows.get_node("JobPoints/Value").text == "+%d" % sl.get_skill_manager().JP_PER_LEVEL, "Job Points from SkillManager (%s)" % rows.get_node("JobPoints/Value").text)
	await _wait(Note.FADE_IN + 0.2)
	ck(is_equal_approx(note.modulate.a, 1.0), "fully shown after the fade in")
	var r := panel.get_global_rect()
	var view := root.get_visible_rect().size
	ck(absf(r.get_center().x - view.x / 2.0) < 1.0, "centred horizontally (%.0f of %.0f)" % [r.get_center().x, view.x])
	ck(is_equal_approx(r.position.y, UITokens.LEVEL_UP_TOP), "120 px from the top (%.0f)" % r.position.y)
	ck(is_equal_approx(r.size.x, UITokens.LEVEL_UP_WIDTH), "320 px wide (%.0f)" % r.size.x)
	ck(note.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "clicks pass through")
	ck(not paused, "the game is not paused")
	await _wait(Note.HOLD + Note.FADE_OUT + 0.2)
	ck(not note.visible and note.pending() == 0, "faded out and hidden")

	print("[3] Two levels at once: they queue")
	xp.add_xp(xp.xp_for_next_level + xp._calculate_xp_requirement(xp.current_level + 1))
	await process_frame
	ck(xp.current_level == 4 and note.pending() == 2, "two queued (level %d, %d pending)" % [xp.current_level, note.pending()])
	ck(note.get_node("%LevelLabel").text == "Level 3", "Level 3 first")
	await _wait(Note.FADE_IN + Note.HOLD + Note.FADE_OUT + 0.2)
	ck(note.visible and note.pending() == 1 and note.get_node("%LevelLabel").text == "Level 4", "then Level 4")
	await _wait(Note.FADE_IN + Note.HOLD + Note.FADE_OUT + 0.2)
	ck(not note.visible and note.pending() == 0, "queue drained")

	print("[4] Reaching the cap shows once; XP at the cap shows nothing (D541)")
	xp.restore(xp.MAX_LEVEL - 1, 0)
	xp.add_xp(xp.xp_for_next_level)
	await process_frame
	ck(xp.is_max_level() and note.pending() == 1, "level %d shown" % xp.MAX_LEVEL)
	await _wait(Note.FADE_IN + Note.HOLD + Note.FADE_OUT + 0.2)
	xp.add_xp(100000)
	await process_frame
	ck(not note.visible and note.pending() == 0, "no notification at the cap")

	print("[5] Uses the kit theme, no hardcoded colours")
	var src := FileAccess.get_file_as_string("res://SampleProject/Scenes/UI/level_up_notification.tscn")
	ck(not src.contains("theme_override_colors") and not src.contains("theme_override_font_sizes") and not src.contains("notification_panel.tres"), "no overrides in the scene")
	ck(note.get_node("Panel/Column/Title").get_theme_color("font_color") == UITokens.ACCENT, "title in accent")
	ck(rows.get_node("AttributePoints/Value").get_theme_color("font_color") == UITokens.STATUS_INCREASE, "values in status/increase")
	ck(rows.get_node("AttributePoints/Label").get_theme_color("font_color") == UITokens.TEXT_SECONDARY, "labels in text-secondary")

	xp.reset()
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
