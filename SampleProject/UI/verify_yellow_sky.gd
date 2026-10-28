extends SceneTree

## D864: небо жовте в кожній відкритій кімнаті, доки герой не вийде з Лабораторії; вихід у двір (lab_outside_complete)
## робить його синім — у тій самій кімнаті й далі. Одне місце: спільний матеріал sky_tint.tres (SkyTint.gd).
##   1. Дорога пустелею (задник) і Гірська стежка (Back/Sky): площини неба під спільним матеріалом, він жовтий, хмари кремові.
##   2. Печера — без неба: матеріалу в ній немає ніде.
##   3. Двір Лабораторії: сам вихід ставить прапорець, і небо синіє тут же; хмари білі; градієнт HighSky лишився синім.
##   4. Місто після прапорця — синє.
##   godot --headless --path . --script res://SampleProject/UI/verify_yellow_sky.gd

## Вантажиться в _initialize: SkyTint.gd знає Game, а той — автозавантаження, яких ще немає під час компіляції тесту.
var SkyTint: GDScript

var fails: Array[String] = []

func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

func _until(cond: Callable, max_s: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_s * 1000)
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await process_frame

func _enter(game: Node, room: String, arrival: NodePath = ^"Arrival") -> void:
	await game.teleport_to_room("res://SampleProject/Maps/%s.tscn" % room, arrival)
	for i in 10: await process_frame

func _tinted(room: Node) -> Array[Node]:
	var out: Array[Node] = []
	for node in room.find_children("*", "CanvasItem", true, false):
		if (node as CanvasItem).material == SkyTint.MATERIAL:
			out.append(node)
	return out

func _clouds(room: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for node in room.find_children("*", "Sprite2D", true, false):
		var texture: Texture2D = (node as Sprite2D).texture
		if texture != null and (texture.resource_path.begins_with(SkyTint.CLOUD_DIR) or texture.resource_path == SkyTint.CLOUD_BANK):
			out.append(node as Sprite2D)
	return out

func _clouds_are(room: Node, tint: Color) -> bool:
	var clouds := _clouds(room)
	return not clouds.is_empty() and clouds.all(func(c: Sprite2D) -> bool: return c.self_modulate == tint)

func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false
	set_meta("start_new_game", true)
	SkyTint = load("res://SampleProject/Scripts/Gameplay/SkyTint.gd")
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 40: await process_frame

	print("[0] The shared sky colours are a warm, dusty yellow; the clouds cream")
	for c: Color in [UITokens.SKY_DUST_DEEP, UITokens.SKY_DUST_PALE, UITokens.SKY_CLOUD_CREAM]:
		ck(c.r > c.b + 0.1 and c.g > c.b, "yellow, not blue: %s" % c.to_html(false))

	print("[1] Before the Laboratory exit: the desert road and the mountain path are yellow")
	ck(game.get_quest_flag(SkyTint.LAB_EXIT_FLAG) != true, "new game: the Laboratory exit flag is not set")
	await _enter(game, "DesertRoad", ^"Arrival_Start")
	var road_skies := _tinted(game.map)
	ck(road_skies.size() == 2, "DesertRoad: both backdrop sky planes are under the shared tint (%d)" % road_skies.size())
	ck(SkyTint.is_yellow(), "DesertRoad: the sky is yellow")
	ck(_clouds_are(game.map, UITokens.SKY_CLOUD_CREAM), "DesertRoad: every cloud is cream (%d)" % _clouds(game.map).size())
	await _enter(game, "MountainPath")
	ck(game.map.get_node(^"Back/Sky").material == SkyTint.MATERIAL, "MountainPath: its own Back/Sky gets the shared tint")
	ck(SkyTint.is_yellow(), "MountainPath: the sky is yellow")

	print("[2] A cave has no sky")
	await _enter(game, "CaveUnderBridge")
	ck(_tinted(game.map).is_empty(), "CaveUnderBridge: nothing under the sky tint")

	print("[3] The Laboratory exit itself turns the sky blue, in the courtyard")
	await _enter(game, "LaboratoryOutside")
	await _until(func() -> bool: return game.get_quest_flag(SkyTint.LAB_EXIT_FLAG) == true, 5.0)
	ck(game.get_quest_flag(SkyTint.LAB_EXIT_FLAG) == true, "the courtyard sets the Laboratory exit flag")
	ck(not SkyTint.is_yellow(), "courtyard: the sky is blue at once")
	ck(game.map.get_node(^"HighSky").material == SkyTint.MATERIAL, "courtyard: the finale's high sky is under the shared tint")
	var high: Color = (game.map.get_node(^"HighSky") as Sprite2D).texture.gradient.sample(0.0)
	ck(high.b > high.r + 0.3, "courtyard: the painted finale sky is the experiment's blue (%s)" % high)
	ck(_clouds_are(game.map, Color.WHITE), "courtyard: the clouds are white again")

	print("[4] After the flag the city is blue too")
	await _enter(game, "City", ^"ForgeDoor")
	ck(not SkyTint.is_yellow(), "City: the sky is blue")
	ck(_clouds_are(game.map, Color.WHITE), "City: white clouds")

	print("RESULT:" + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
