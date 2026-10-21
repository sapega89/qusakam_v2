extends SceneTree

## Пролог у журналі, слайс 1 (D120, design/prologue_journal_plan.md).
##   godot --headless --path . --script res://SampleProject/UI/verify_story_journal.gd
##
## Перевіряє:
##   1. story.json: етап Prologue, 7 підетапів, назви англійською (D121).
##   2. Кожен done_flag справді ставить якась сцена — інакше підетап не закриється ніколи.
##   3. Стан підетапів іде за прапорцями: done / current / locked, жива ціль під поточним.
##   4. StoryState виводиться з тих самих прапорців (B43), включно з DEMO_END.

const STORY := "res://SampleProject/Resources/Data/story.json"
const SCENES_DIR := "res://SampleProject/Scripts/Gameplay/Scenes/"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	await process_frame
	var flow: Node = root.get_node("ServiceLocator").get_game_flow()
	# Як кнопка New Game: без цього Game.tscn вантажить справжній сейв гравця.
	set_meta("start_new_game", true)
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	ck(flow != null and game != null, "GameFlow and Game present")

	print("[1] story.json")
	var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY)).stages[0]
	var titles: Array = stage.zones.map(func(z): return z.title)
	ck(stage.title == "Prologue", "stage is the Prologue")
	ck(titles == ["Canyon I", "Village", "Canyon II", "Desert Road", "City Gates", "Laboratory — Cells", "Laboratory", "Laboratory — Outside"],
			"8 sub-stages in story order: %s" % str(titles))

	print("[2] every done_flag is set by a scene")
	var source := ""
	for file in DirAccess.get_files_at(SCENES_DIR):
		if file.ends_with(".gd"):
			source += FileAccess.get_file_as_string(SCENES_DIR + file)
	for zone in stage.zones:
		for objective in zone.objectives:
			ck(source.contains('"%s"' % objective.flag), "%s objective flag %s exists in scene code" % [zone.title, objective.flag])
			# Друга частина виклику — мітка стрілки (D-28h): set_objective("…", &"id")
			ck(source.contains('set_objective("%s")' % objective.text) or source.contains('set_objective("%s", &"' % objective.text),
					"%s objective '%s' is what the game shows" % [zone.title, objective.text])
		for beat in zone.get("chronicle", []):
			ck(source.contains('"%s"' % beat.flag), "%s chronicle: %s exists in scene code" % [zone.title, beat.flag])
		ck(not zone.get("chronicle", []).is_empty(), "%s has a chronicle" % zone.title)

	print("[3] states follow the flags")
	game.set_quest_flags({})
	game.set_objective("Explore the Canyon")
	ck(_states(flow) == ["current", "locked", "locked", "locked", "locked", "locked", "locked", "locked"], "fresh game: Canyon I current")
	ck(_objectives(flow, 0) == ["current:Explore the Canyon"], "fresh game: only the first objective is visible")
	ck(_objectives(flow, 1).is_empty(), "locked sub-stage shows no objectives")
	ck(flow.journal_entries()[0].state == "active", "stage active")

	ck(flow.journal_entries()[0].zones[0].chronicle.is_empty(), "nothing happened yet: empty chronicle")
	game.set_quest_flag("canyon_intro_complete", true)
	ck(flow.journal_entries()[0].zones[0].chronicle.size() == 1, "intro done: one chronicle line")
	game.set_quest_flag("canyon_exploration_complete", true)
	ck(_objectives(flow, 0) == ["done:Explore the Canyon", "current:Find a way forward"],
			"done objective stays, the next one appears (%s)" % str(_objectives(flow, 0)))
	game.set_quest_flag("canyon_exploration_complete", false)
	game.set_quest_flag("canyon_abduction_complete", true)
	ck(_states(flow).slice(0, 3) == ["done", "current", "locked"], "left the canyon: Village current")
	var canyon_story: Array = flow.journal_entries()[0].zones[0].chronicle
	ck(canyon_story.size() == 2 and canyon_story[1].begins_with("From the ridge"),
			"chronicle keeps story order, skips the step not taken (%d lines)" % canyon_story.size())
	ck(flow.journal_entries()[0].zones[2].chronicle.is_empty(), "locked sub-stage has no chronicle")
	game.set_quest_flag("village_left_complete", true)
	ck(_states(flow).slice(1, 4) == ["done", "current", "locked"], "left the village: Canyon II current")

	print("[4] StoryState from the same flags (B43)")
	flow.sync_story_state()
	ck(flow.current_state == flow.StoryState.CANYON, "back in the canyon -> CANYON")
	game.set_quest_flag("canyon_exit_complete", true)
	flow.sync_story_state()
	ck(flow.current_state == flow.StoryState.DESERT_ROAD, "canyon exit -> DESERT_ROAD")

	for zone in stage.zones:
		for objective in zone.objectives:
			game.set_quest_flag(objective.flag, true)
	ck(_states(flow).all(func(s): return s == "done"), "all flags: every sub-stage done")
	ck(flow.journal_entries()[0].state == "complete", "stage complete")
	var all_done := true
	for i in stage.zones.size():
		all_done = all_done and _objectives(flow, i).size() == stage.zones[i].objectives.size() 				and _objectives(flow, i).all(func(o): return o.begins_with("done:"))
	ck(all_done, "completed stage: every objective listed and done")
	flow.sync_story_state()
	ck(flow.current_state == flow.StoryState.DEMO_END, "all done -> DEMO_END")

	_done()


func _objectives(flow: Node, zone: int) -> Array:
	return flow.journal_entries()[0].zones[zone].objectives.map(func(o): return "%s:%s" % [o.state, o.text])


func _states(flow: Node) -> Array:
	return flow.journal_entries()[0].zones.map(func(z): return z.state)


func _done() -> void:
	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0 if fails.is_empty() else 1)
