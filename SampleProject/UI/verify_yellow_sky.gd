extends SceneTree

## D864: небо жовте в кожній відкритій кімнаті, доки герой не вийде з Лабораторії; вихід у двір (lab_outside_complete)
## робить його синім — у тій самій кімнаті й далі. Одне місце: спільний матеріал sky_tint.tres (SkyTint.gd).
##   1. Дорога пустелею (задник) і Гірська стежка (Back/Sky): площини неба під спільним матеріалом, він жовтий, хмари кремові (sky_clouds*.tres).
##   2. Печера під мостом: перефарбоване лише небо, запечене в дальню стіну (каньйон у проломах), — ключем.
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
		if (node as CanvasItem).material in [SkyTint.SKY, SkyTint.SKY_KEYED]:
			out.append(node)
	return out

## Усі хмари кімнати (текстури хмар) — під спільним матеріалом хмар.
func _clouds_shared(room: Node) -> bool:
	var count: int = 0
	for node in room.find_children("*", "Sprite2D", true, false):
		var path: String = (node as Sprite2D).texture.resource_path if (node as Sprite2D).texture != null else ""
		if path.begins_with("res://SampleProject/Assets/Backgrounds/Clouds/") or path == SkyTint.CLOUD_BANK:
			count += 1
			if (node as Sprite2D).material not in [SkyTint.CLOUDS_FAR, SkyTint.CLOUDS]:
				return false
	return count > 0

func _cream() -> float:
	return SkyTint.CLOUDS_FAR.get_shader_parameter(&"cream")

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
	ck(_clouds_shared(game.map) and _cream() == 1.0, "DesertRoad: every cloud is under the shared cloud material, cream")
	await _enter(game, "MountainPath")
	ck(game.map.get_node(^"Back/Sky").material == SkyTint.SKY, "MountainPath: its own Back/Sky gets the shared tint")
	ck(SkyTint.is_yellow(), "MountainPath: the sky is yellow")

	print("[2] A cave: only the sky baked into its far wall")
	await _enter(game, "CaveUnderBridge")
	var cave_skies := _tinted(game.map)
	ck(not cave_skies.is_empty() and cave_skies.all(func(n: Node) -> bool: return (n as CanvasItem).material == SkyTint.SKY_KEYED),
			"CaveUnderBridge: only the canyon sky baked into its far wall is retinted, keyed (%d)" % cave_skies.size())

	print("[3] The Laboratory exit itself turns the sky blue, in the courtyard")
	await _enter(game, "LaboratoryOutside")
	await _until(func() -> bool: return game.get_quest_flag(SkyTint.LAB_EXIT_FLAG) == true, 5.0)
	ck(game.get_quest_flag(SkyTint.LAB_EXIT_FLAG) == true, "the courtyard sets the Laboratory exit flag")
	ck(not SkyTint.is_yellow(), "courtyard: the sky is blue at once")
	ck(game.map.get_node(^"HighSky").material == SkyTint.SKY, "courtyard: the finale's high sky is under the shared tint")
	var high: Color = (game.map.get_node(^"HighSky") as Sprite2D).texture.gradient.sample(0.0)
	ck(high.b > high.r + 0.3, "courtyard: the painted finale sky is the experiment's blue (%s)" % high)
	ck(_clouds_shared(game.map) and _cream() == 0.0, "courtyard: the clouds are as painted again")

	print("[4] After the flag the city is blue too")
	await _enter(game, "City", ^"ForgeDoor")
	ck(not SkyTint.is_yellow(), "City: the sky is blue")
	ck(_clouds_shared(game.map) and _cream() == 0.0, "City: clouds as painted")

	print("RESULT:" + ("ALL PASS" if fails.is_empty() else "%d FAIL: %s" % [fails.size(), ", ".join(fails)]))
	quit()
