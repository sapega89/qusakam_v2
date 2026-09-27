extends SceneTree

## Самоперевірка slice 5 (частина 1): екран Game Over.
##   godot --headless --path . --script res://SampleProject/UI/verify_game_over.gd
##
## Figma: game-over-screen 41:83. Q6: Resume = останній слот; Return to title.
## Сейви — в окремій теці user://verify_gameover_saves.

const SCENE := "res://SampleProject/Scenes/UI/game_over_screen.tscn"
const TEST_DIR := "user://verify_gameover_saves/"

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

var ss: Node


## Замінник гравця: рахує виклики kill() (старий респавн).
class FakePlayer extends Node2D:
	var kills := 0
	func kill() -> void:
		kills += 1


func _wipe() -> void:
	for f in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)


func _screen() -> GameOverScreen:
	return get_first_node_in_group(&"game_over_screen") as GameOverScreen


func _open(player: Node) -> GameOverScreen:
	GameOverScreen.present(player)
	for i in 3: await process_frame
	var s := _screen()
	if s:
		s.change_scenes = false
	return s


func _initialize() -> void:
	await process_frame
	await process_frame
	ss = root.get_node("ServiceLocator").get_save_system()
	ss.set_save_dir(TEST_DIR)
	_wipe()
	ss.set_save_dir(TEST_DIR)
	var theme: Theme = load("res://SampleProject/UI/Themes/GameUITheme.tres")
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	print("[1] Figma 41:83 structure and copy")
	var txt := FileAccess.open(SCENE, FileAccess.READ).get_as_text()
	ck(txt.find("theme_override") == -1 and txt.find("StyleBox") == -1 and txt.find("Color(") == -1,
			"no local styles or colours in the scene")
	ck(theme.get_font_size("font_size", "GameOverTitle") == UITokens.SIZE_GAME_OVER
			and theme.get_color("font_color", "GameOverTitle") == UITokens.GAME_OVER_RED, "\"Game Over\" Bold 144, #9e1b1b")
	var player := FakePlayer.new()
	world.add_child(player)
	var s := await _open(player)
	ck(s != null, "present() shows the screen")
	if s == null:
		_done()
		return
	ck(paused, "game paused behind it")
	ck(s.get_node("%TitleLabel").text == "Game Over", "title copy")
	ck(s.get_node("%ResumeButton").text == "Resume from last save point"
			and s.get_node("%TitleButton").text == "Return to title", "option copy from Figma")
	ck(s.get_viewport().gui_get_focus_owner() == s.get_node("%ResumeButton"), "Resume focused")
	ck(s.get_node("%ResumeButton").theme_type_variation == &"NpcMenuItemOn", "focused option uses the active UI/Menu Item style")
	ck((s.get_node("%Vignette") as TextureRect).texture is GradientTexture2D, "radial vignette built from tokens")
	GameOverScreen.present(player)
	await process_frame
	ck(get_nodes_in_group(&"game_over_screen").size() == 1, "a second death does not stack screens")

	print("[2] Resume without a save → old respawn")
	s.resume()
	ck(s.last_action == "respawn" and player.kills == 1, "falls back to the room-entrance respawn")
	for i in 3: await process_frame
	ck(_screen() == null and not paused, "screen closes, game resumes")

	print("[3] Resume with a save → load the last slot (Q6)")
	ss.set_current_slot(2)
	var f := FileAccess.open(ss.get_slot_path(2), FileAccess.WRITE)
	f.store_string(var_to_str({"current_room": "Canyon"}))
	f.close()
	s = await _open(player)
	s.resume()
	await process_frame
	ck(s.last_action == "load", "loads the last saved/loaded slot")
	ck(get_meta("save_file_path", "") == ss.get_slot_path(2) and get_meta("start_new_game", true) == false,
			"hands slot 2 to Game")
	ck(not paused, "unpaused before changing scene")
	remove_meta("save_file_path")
	remove_meta("start_new_game")
	s.get_parent().queue_free()
	await process_frame

	print("[4] Return to title")
	s = await _open(player)
	s.get_node("%TitleButton").pressed.emit()
	await process_frame
	ck(s.last_action == "title" and get_meta("show_title_screen", false) == true, "goes to the title screen")
	ck(not paused, "unpaused")
	remove_meta("show_title_screen")
	s.get_parent().queue_free()

	print("[5] Player death uses it")
	var psrc := FileAccess.open("res://SampleProject/Scripts/Player.gd", FileAccess.READ).get_as_text()
	var i_present := psrc.find("GameOverScreen.present(self)")
	ck(i_present != -1 and i_present < psrc.find("\tkill()\n", i_present), "Player.die() shows Game Over before the old respawn")
	current_scene = null
	var orphan := FakePlayer.new()
	root.add_child(orphan)
	ck(not GameOverScreen.present(orphan), "no current scene → falls back (old behaviour)")

	ss.set_save_dir(ss.SAVE_DIR)
	_wipe()
	DirAccess.remove_absolute(TEST_DIR)
	_done()


func _done() -> void:
	print("")
	if fails.is_empty():
		print("RESULT: ALL PASS")
	else:
		print("RESULT: %d FAIL" % fails.size())
		for f in fails:
			print("    : " + f)
	quit(0 if fails.is_empty() else 1)
