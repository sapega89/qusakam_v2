extends SceneTree

## Навчання (BACKLOG 28, design/onboarding_plan.md, D-28e…D-28h), справжнім вводом: вікна туторіалу крутять кадри з
## гри; Misc → Controls відкривається кліками й називає кожну дію для обох пристроїв; ціль на плашці веде до мітки.
## Тренування бою в селі прибрано (D725) — що перший бій звичайний, перевіряє verify_village_fight.
##   godot --headless --path . --script res://SampleProject/UI/verify_onboarding.gd

## Скрипти гри — load() уже в _initialize(): preload компілював би їх до автозавантажень (EventBus, ServiceLocator).
var TutorialTopics: GDScript
const TUTORIAL_TOPICS := "res://SampleProject/Scripts/UI/tutorial_topics.gd"
var TopicWindow: PackedScene
const TOPIC_WINDOW := "res://SampleProject/Scenes/Menus/Game/tutorial_menu.tscn"
var TutorialMenu: GDScript
const TUTORIAL_MENU := "res://SampleProject/Scripts/Menus/Game/tutorial_menu.gd"
const Kit = preload("res://SampleProject/UI/input_kit.gd")

## Дії InputMap, яких немає на сторінці Controls, і чому.
const NOT_GAMEPLAY := {
	&"save_delete": "Load Game menu only (delete a save)",
	&"menu_next_tab": "shares the Previous / next menu tab row with menu_prev_tab",
	&"toggle_mouse": "keyboard & mouse only (D417): a pad never moves the cursor; rebindable in Settings → Controls",
}

## Ранні кроки сюжету (D-28h): кімната → її скрипт. Кожна ціль там або веде на мітку ObjectiveTargets/<id> цієї
## кімнати, або в NO_WALK — крок, де йти нікуди (бій перед очима, розмова, кат-сцена).
const EARLY_ROOMS := {
	"Canyon": "res://SampleProject/Scripts/Gameplay/Scenes/Canyon.gd",
	"Village": "res://SampleProject/Scripts/Gameplay/Scenes/Village.gd",
	"ElderHouse": "res://SampleProject/Scripts/Gameplay/Scenes/ElderHouse.gd",  # розмова з дідом (D438)
	"DesertRoad": "res://SampleProject/Scripts/Gameplay/Scenes/DesertRoad.gd",
	"CityGates": "res://SampleProject/Scripts/Gameplay/Scenes/CityGates.gd",
}
const NO_WALK := ["Find a way forward", "Descend to the road", "Defeat the bandit in the street",
		"Make a decision", "Defeat the enemies on the road", "Defeat the bandits"]
## Уже за ранніми кроками: ціль у місті (City), мітки — разом із планом міста.
const BEYOND_EARLY := ["Find the laboratory"]
## Цілі, що лишаються в наступній кімнаті: мітка з тим самим id мусить бути і там.
const CARRIED := {"canyon_bridge": ["ElderHouse", "Village", "Canyon"], "city_gates": ["DesertRoad", "CityGates"]}

var fails: Array[String] = []
var game: Node
var hero: Node


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	TutorialTopics = load(TUTORIAL_TOPICS)
	TopicWindow = load(TOPIC_WINDOW)
	TutorialMenu = load(TUTORIAL_MENU)
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D728: no «?» tips in this run
	await process_frame
	root.size = Vector2i(1920, 1080)  # кліки влучають туди, де намальовано (input_kit)
	set_meta("start_new_game", true)
	var sl: Node = root.get_node("ServiceLocator")
	sl.get_dialogue_manager().bubble_time_scale = 0.0
	game = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame
	var dm: Node = sl.get_dialogue_manager()
	await _drain(dm)
	var flags: Dictionary = game.get_quest_flags().duplicate()
	for f in ["canyon_intro_complete", "canyon_exploration_complete", "canyon_abduction_complete"]:
		flags[f] = true
	game.set_quest_flags(flags)

	await game.teleport_to_room("res://SampleProject/Maps/Village.tscn", ^"Arrival")
	await create_timer(1.0).timeout
	var village: Node = game.map
	hero = game.player

	print("[1] Tutorial windows play frames recorded from the game (D-28e)")
	await _check_frames()

	print("[2] Misc → Controls by real clicks (D-28f)")
	await _check_controls(sl)

	print("[4] Where to go next: the plaque arrow points at the objective's marker (D-28h)")
	_check_objective_markers()
	await _check_arrow(village)

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit(0)


func _check_frames() -> void:
	for topic in TutorialTopics.all():
		TutorialTopics.mark_seen(topic.id)
	var layer: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer()
	var with_frames: Array = TutorialTopics.all().filter(func(t: Dictionary) -> bool: return t.has("frames"))
	var sets: Array = []
	for topic in with_frames:
		if not topic.frames in sets:
			sets.append(topic.frames)
	ck(sets.size() >= 8, "eight frame sets: move, combo, dodge, block, parry, heavy, heal, assist (%s)" % [sets])
	for id in ["movement", "attack", "heavy_attack", "block", "tell_block", "tell_parry", "tell_dodge",
			"healing_palm", "call_guard"]:
		ck(with_frames.any(func(t: Dictionary) -> bool: return t.id == id), "%s has a picture" % id)
	for topic in with_frames:
		var frames: Array[Texture2D] = TutorialMenu.load_frames(topic.frames)
		ck(frames.size() >= 6, "%s: %d frames of '%s'" % [topic.id, frames.size(), topic.frames])
	for id: String in with_frames.map(func(t: Dictionary) -> String: return t.id):
		layer.show_custom_modal(TopicWindow)
		var window: Node = layer.active_modal
		window.open_id(id)
		var shot: TextureRect = window.get_node(^"%Shot")
		var first: Texture2D = shot.texture
		ck(first != null and first == window.frames[0] and window.get_node(^"%ShotFrame").visible, "%s window shows frame 0" % id)
		await create_timer(0.35).timeout
		ck(shot.texture != first and shot.texture in window.frames, "%s window plays the frames" % id)
		ck(window.get_node(^"%Key").text != "", "%s window names the button (%s)" % [id, window.get_node(^"%Key").text])
		window.cancelled.emit()
		for i in 4: await process_frame


func _check_controls(sl: Node) -> void:
	var ui: Node = sl.get_ui_manager()
	ui.open_game_menu()
	for i in 16: await process_frame
	var menu: Node = get_first_node_in_group("game_menu")
	ck(menu != null, "game menu open")
	await Kit.mouse(self, menu.misc_button)
	var modal: Node = get_first_node_in_group("misc_menu_modal")
	ck(modal != null, "Misc opened by a click")
	await Kit.mouse(self, modal.controls_button)
	var page: Node = menu.find_child("ControlsComponent", true, false)
	ck(page.is_visible_in_tree(), "Controls opened by a click")
	ck(not menu.find_child("TutorialComponent", true, false).is_visible_in_tree(), "only the Controls panel shows")
	var missing: Array = []
	for i in page.ACTIONS.size():
		var texts: Array[String] = page.row_texts(i)
		if texts[1] == "—" or texts[2] == "—":
			missing.append(texts)
	ck(missing.is_empty(), "every action has a keyboard and a pad button (%s)" % [missing])
	var listed: Array = page.ACTIONS.map(func(a: Array) -> StringName: return a[1])
	var unlisted: Array = []
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_") and not action in NOT_GAMEPLAY and not action in listed:
			unlisted.append(action)
	ck(unlisted.is_empty(), "every gameplay action in the InputMap is listed (missing %s)" % [unlisted])
	ck(not &"weapon_next" in listed and not &"weapon_prev" in listed, "D475: no weapon-switch rows")
	var block_row: Array[String] = page.row_texts(8)
	ck(block_row[1].contains("Ctrl") and block_row[2] == "LB", "block: Ctrl / LB (%s)" % [block_row])
	ck(root.gui_get_focus_owner() == page.get_node(^"%ActionList").get_child(0), "focus on the first row (pad / arrows scroll)")
	ui.close_game_menu()
	for i in 16: await process_frame

	print("[3] The same page by gamepad: Start → Misc → Controls")
	await Kit.pad(self, JOY_BUTTON_START)
	await Kit.frames(self, 16)
	menu = get_first_node_in_group("game_menu")
	ck(menu != null, "Start opens the game menu")
	for i in 8:
		if root.gui_get_focus_owner() == menu.misc_button:
			break
		await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(root.gui_get_focus_owner() == menu.misc_button, "D-pad reaches Misc")
	await Kit.pad(self, JOY_BUTTON_A)
	await Kit.frames(self, 6)
	modal = get_first_node_in_group("misc_menu_modal")
	ck(modal != null, "A opens Misc")
	for i in 6:
		if root.gui_get_focus_owner() == modal.controls_button:
			break
		await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(root.gui_get_focus_owner() == modal.controls_button, "D-pad reaches Controls")
	await Kit.pad(self, JOY_BUTTON_A)
	await Kit.frames(self, 6)
	page = menu.find_child("ControlsComponent", true, false)
	ck(page.is_visible_in_tree(), "A opens Controls")
	var rows: Node = page.get_node(^"%ActionList")
	await Kit.pad(self, JOY_BUTTON_DPAD_DOWN)
	ck(root.gui_get_focus_owner() == rows.get_child(1), "D-pad down scrolls the list")
	ui.close_game_menu()


func _check_objective_markers() -> void:
	var calls := RegEx.create_from_string('set_objective\\("([^"]+)"(?:, &"(\\w+)")?\\)')
	for room: String in EARLY_ROOMS:
		var markers := _markers("res://SampleProject/Maps/%s.tscn" % room)
		var source := FileAccess.get_file_as_string(EARLY_ROOMS[room])
		var seen := {}
		for m in calls.search_all(source):
			var text := m.get_string(1)
			var id := m.get_string(2)
			if seen.has(text + id):
				continue
			seen[text + id] = true
			if text in BEYOND_EARLY:
				continue
			if id == "":
				ck(text in NO_WALK, "%s: «%s» has no marker and is a fight / talk / cutscene" % [room, text])
			else:
				ck(id in markers, "%s: «%s» → ObjectiveTargets/%s (%s)" % [room, text, id, markers])
	for id: String in CARRIED:
		for room: String in CARRIED[id]:
			ck(id in _markers("res://SampleProject/Maps/%s.tscn" % room), "%s is marked in %s too (the route crosses rooms)" % [id, room])


## Імена міток ObjectiveTargets/* у сцені кімнати — зі стану сцени, без запуску кімнати.
func _markers(path: String) -> Array[String]:
	var state: SceneState = (load(path) as PackedScene).get_state()
	var out: Array[String] = []
	for i in state.get_node_count():
		if String(state.get_node_path(i, true)) == "./ObjectiveTargets":
			out.append(String(state.get_node_name(i)))
	return out


func _check_arrow(village: Node) -> void:
	var hud: Node = get_first_node_in_group("combat_hud_top")
	var arrow: Label = hud.get_node(^"%Direction")
	game.set_objective("Check on the house", &"house")
	var house: Vector2 = village.get_node(^"ObjectiveTargets/house").global_position
	for case: Array in [[-600.0, "→"], [600.0, "←"], [0.0, ""]]:
		hero.global_position = Vector2(house.x + case[0], house.y - 20.0)
		hero.velocity = Vector2.ZERO
		for i in 3: await process_frame
		var shown: String = arrow.text if arrow.visible else ""
		ck(shown == case[1], "hero %+d px from the house: arrow «%s» (%s)" % [case[0], case[1], shown])
	game.set_objective("Make a decision")
	for i in 3: await process_frame
	ck(not arrow.visible, "a talk step has no arrow")


func _drain(dm: Node) -> void:
	for round in 10:
		for i in 200:
			if not dm.is_dialogue_active():
				break
			dm.current_dialogue_box.finish()
			dm.current_dialogue_player.accept()
			for f in 6: await process_frame
		for i in 10: await process_frame
		if not dm.is_dialogue_active():
			return

