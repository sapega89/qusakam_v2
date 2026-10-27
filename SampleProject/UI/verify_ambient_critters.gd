extends SceneTree

## Жива дрібнота на передньому плані (D774, ambient_critters_plan slice 1):
##   godot --headless --path . --script res://SampleProject/UI/verify_ambient_critters.gd
##   1. У печері ящурів дві кажани під FrontDark, висять під корінням, ні з чим не стикаються; герой біля дверей їх
##      не лякає.
##   2. Герой іде до кажана (справжнє move_right) → вона злітає й зникає за краєм кадру.
##   3. Поки її місце в кадрі, вона не вертається, хоч затримка й минула; поза кадром — не раніше затримки;
##      після затримки з місцем поза кадром — знову висить.
##   4. Вихід з кімнати й повернення не скидає часу: кажан і далі відсутня, поки затримка не мине.
## Затримка вкорочується через експортовану змінну — тест не чекає 30 с. Пише лише в user://verify_ambient_critters/.

const Kit = preload("res://SampleProject/UI/input_kit.gd")
const Critter = preload("res://SampleProject/Scripts/Gameplay/AmbientCritter.gd")
const CAVE := "res://SampleProject/Maps/LizardCave.tscn"
const CANYON := "res://SampleProject/Maps/Canyon.tscn"
const TEST_DIR := "user://verify_ambient_critters/"

var fails: Array[String] = []
var game: Node


func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)


func _initialize() -> void:
	await process_frame
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	save_system.settings_module.settings.tutorial_windows = false
	save_system.set_save_dir(TEST_DIR)
	save_system.set_current_slot(1)
	game = await Kit.boot(self)
	Critter.left_at.clear()

	print("[1] Two bats hang in the Lizard Cave's foreground")
	await _visit(CAVE, ^"ExitDoor")
	var bats := _bats()
	ck(bats.size() == 2, "two bats under FrontDark (%d)" % bats.size())
	for bat: Node2D in bats:
		ck(bat.get_parent().name == &"FrontDark", "%s lives on the dark foreground layer" % bat.name)
		ck(bat.find_children("*", "CollisionObject2D", true, false).is_empty(), "%s has no body or area: it touches nothing" % bat.name)
		ck(not bat.is_away() and bat.sprite.visible and bat.sprite.flip_v, "%s hangs perched (upside down) at the start" % bat.name)
		ck(bat.scare_distance == 160.0 and bat.return_delay == 30.0, "%s: the plan's defaults, 160 px and 30 s" % bat.name)
	await _frames(30)
	ck(bats.all(func(b: Node2D) -> bool: return not b.is_away() and not b.is_flying()), "the hero at the door scares nobody")

	print("[2] The hero walks up: the bat leaves the view")
	var bat: Node2D = bats[0]
	bat.return_delay = 2.0
	game.place_player(Vector2(bat.global_position.x - 320.0, game.player.global_position.y))
	await _frames(40)
	ck(not bat.is_flying() and not bat.is_away(), "still perched with the hero 320 px away")
	Input.action_press(&"move_right")
	var took_off := false
	for i in 300:
		await physics_frame
		if bat.is_flying():
			took_off = true
			break
	Input.action_release(&"move_right")
	var gap: float = absf(bat.global_position.x - game.player.global_position.x)
	ck(took_off, "the bat takes off as the hero comes near (%.0f px)" % gap)
	ck(gap <= bat.scare_distance + 8.0, "…within the scare distance, not before")
	ck(bat.sprite.is_playing() and bat.sprite.animation == &"fly", "it flaps (the fly row plays)")
	var away_dir: float = signf(bat.global_position.x - game.player.global_position.x)
	for i in 200:
		await physics_frame
		if bat.is_away():
			break
	ck(bat.is_away() and not bat.sprite.visible, "it is gone, hidden")
	ck(signf(bat.sprite.position.x) == away_dir and bat.sprite.position.y < 0.0, "it flew up and away from the hero")
	var drawn: Rect2 = bat.sprite.get_global_transform_with_canvas() * Rect2(-32, -32, 64, 64)
	ck(not root.get_visible_rect().intersects(drawn), "where it ended is out of the camera's view (%s)" % drawn)
	ck(Critter.left_at.size() == 1, "its leaving time is remembered")

	print("[3] It comes back only after the delay and with its perch out of view")
	ck(bat._perch_on_screen(), "the hero stays: the perch is on screen")
	await _seconds(2.6)
	ck(bat.is_away(), "the delay (2 s) is over, but the perch is on screen: still away")
	bat.return_delay = 8.0
	await _hero_far_from(bat)
	ck(not bat._perch_on_screen(), "the hero walked off: the perch is out of view")
	ck(bat.is_away(), "…and before the delay (8 s) it is still away")
	var since: float = (Time.get_ticks_msec() - Critter.left_at[bat._key]) / 1000.0
	await _seconds(8.2 - since)
	await _frames(2)
	ck(not bat.is_away() and bat.sprite.visible and bat.sprite.position == Vector2.ZERO and bat.sprite.flip_v,
			"after the delay with the perch out of view it hangs there again (no fly-in)")
	ck(not bat.sprite.is_playing(), "…holding one frame")
	ck(Critter.left_at.is_empty(), "its leaving time is cleared")

	print("[4] Leaving the room and coming back keeps it away until the delay")
	game.place_player(Vector2(bat.global_position.x - 40.0, game.player.global_position.y))
	for i in 200:
		await physics_frame
		if bat.is_away():
			break
	ck(bat.is_away(), "scared off again")
	var path: NodePath = game.map.get_path_to(bat)
	await _visit(CANYON, ^"LizardCaveDoor")
	await _visit(CAVE, ^"ExitDoor")
	var again: Node2D = game.map.get_node(path)
	ck(again != bat and again.is_away() and not again.sprite.visible, "a fresh room, the same bat: still away")
	await _hero_far_from(again)
	ck(not again._perch_on_screen() and again.is_away(), "perch out of view, but the 30 s are not over: still away")
	var other: Node2D = game.map.get_node(game.map.get_path_to(_bats()[1]))
	ck(not other.is_away() and other.sprite.visible, "the other bat, never scared, hangs as before")
	again.return_delay = 0.5
	await _frames(4)
	ck(not again.is_away() and again.sprite.visible, "with the delay over it is back")

	print("RESULT: " + ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit()


func _bats() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for n: Node in game.map.find_children("*", "Node2D", true, false):
		if n.get_script() == Critter:
			out.append(n)
	return out


func _visit(room: String, arrival: NodePath) -> void:
	await game.teleport_to_room(room, arrival)
	await _frames(20)
	await Kit.drain(self)
	# Бій ящурів тримає камеру й героя — тут перевіряється кажан, не бій.
	for n: Node in game.map.get_children():
		if String(n.name).begins_with("Fight_"):
			n.free()


## Герой далеко від кажана, камера доїхала — її місце поза кадром.
func _hero_far_from(bat: Node2D) -> void:
	var far: float = bat.global_position.x + 900.0
	game.place_player(Vector2(far, game.player.global_position.y - 40.0))
	await _frames(90)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame
