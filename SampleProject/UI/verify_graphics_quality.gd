extends SceneTree

## D553 / D554, performance_plan slice 7: Settings → Display → Quality (High / Low).
##   godot --headless --path . --script res://SampleProject/UI/verify_graphics_quality.gd
## [1] перший запуск бере Low для слабкої вбудованої відеокарти за назвою адаптера; [2] вибір у рядку пишеться у файл
## налаштувань і переживає перезапуск модуля; [3] Low знімає світіння, колірні криві, розмиття глибини, тіні й
## половину частинок, High повертає все як було (спільні ресурси сцен не змінюються); [4] Low діє вже на першому
## кадрі гри: Game і перша кімната входять у дерево вже без дорогого.

var fails: Array[String] = []
func ck(ok: bool, label: String) -> void:
	print(("  OK  " if ok else "  FAIL ") + label)
	if not ok: fails.append(label)

const GraphicsQuality := preload("res://SampleProject/Scripts/Systems/GraphicsQuality.gd")
const TEST_DIR := "user://verify_graphics_quality/"
const BLUR := "res://SampleProject/Resources/Materials/depth_blur_far.tres"


func _initialize() -> void:
	await process_frame
	var save_system: Node = root.get_node("SaveSystem")
	var display: Node = root.get_node("DisplayManager")
	var quality: GraphicsQuality = display.graphics_quality
	save_system.set_save_dir(TEST_DIR)  # не чіпає справжні налаштування гравця
	var settings_path: String = save_system.get_settings_path()
	DirAccess.remove_absolute(settings_path)

	print("[1] the first-run default comes from the adapter name (D553)")
	var table := {
		"Intel(R) HD Graphics 3000": "low",
		"Intel(R) HD Graphics 2000": "low",
		"Intel(R) HD Graphics 4000": "low",
		"Intel(R) HD Graphics": "low",
		"ANGLE (Intel, Intel(R) HD Graphics 3000 Direct3D11 vs_4_1 ps_4_1, D3D11-9.17.10.4459)": "low",
		"ANGLE (Intel, Intel(R) G41 Express Chipset Direct3D11 vs_4_0 ps_4_0, D3D11)": "low",
		"Intel(R) HD Graphics 4600": "high",
		"Intel(R) HD Graphics 620": "high",
		"Intel(R) UHD Graphics 630": "high",
		"Intel(R) Iris(R) Xe Graphics": "high",
		"ANGLE (NVIDIA, NVIDIA GeForce GTX 1060 Direct3D11 vs_5_0 ps_5_0, D3D11)": "high",
		"NVIDIA GeForce RTX 3060/PCIe/SSE2": "high",
		"AMD Radeon(TM) Graphics": "high",
		"llvmpipe (LLVM 15.0.7, 256 bits)": "high",
		"": "high",
	}
	for adapter: String in table:
		ck(GraphicsQuality.default_for_adapter(adapter) == table[adapter], "%s → %s" % [adapter if adapter else "(none)", table[adapter]])
	var module: Node = save_system.settings_module
	var here: String = GraphicsQuality.default_for_adapter(RenderingServer.get_video_adapter_name())
	ck(module.default_settings["graphics_quality"] == here, "default_settings use this adapter (%s)" % here)
	module.read({})
	ck(module.settings["graphics_quality"] == here, "a settings file without the key (first run) gets it too")
	module.read({"graphics_quality": "low"})
	ck(module.settings["graphics_quality"] == "low", "a saved choice wins over the adapter default")
	module.settings = module.default_settings.duplicate()
	module.settings["graphics_quality"] = "high"
	module.apply_settings()
	ck(quality.quality == "high", "applied: High")

	print("[2] the Quality row saves and applies; the choice survives a restart")
	var opts: Node = load("res://SampleProject/Scenes/Menus/Game/options_component.tscn").instantiate()
	opts.mode = "main_menu"
	root.add_child(opts)
	for i in 4: await process_frame
	opts.switch_to_tab("display")
	for i in 3: await process_frame
	var row: Node = _row(opts, "Quality")
	ck(row != null, "Display tab has a Quality row")
	if row == null:
		_done()
		return
	var cells: Array[Node] = row.get_node(^"Segments/Cells").get_children()
	ck(cells.size() == 2 and String(cells[0].text).ends_with("High") and String(cells[1].text).ends_with("Low"),
			"two cells: High, Low")
	ck(String(cells[0].text).begins_with("✓"), "High is ticked")
	cells[1].pressed.emit()
	for i in 3: await process_frame
	ck(module.settings["graphics_quality"] == "low", "stored low")
	ck(quality.quality == "low", "applied: Low")
	var on_disk: Dictionary = str_to_var(FileAccess.get_file_as_string(settings_path))
	ck(on_disk["graphics_quality"] == "low", "the settings file holds low")
	opts.queue_free()
	await process_frame
	quality.apply("high")
	var old_module: Node = save_system.settings_module
	var module_script: Script = old_module.get_script()
	save_system.remove_child(old_module)
	old_module.free()
	var fresh: Node = module_script.new()
	save_system.settings_module = fresh
	save_system.add_child(fresh)
	await process_frame
	save_system.load_game_settings()
	ck(fresh.settings["graphics_quality"] == "low", "reloaded low")
	ck(quality.quality == "low", "applied on load: Low")

	print("[3] Low drops the expensive looks, High brings them back")
	quality.apply("high")
	var holder := Node2D.new()
	var env := Environment.new()
	env.glow_enabled = true
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	holder.add_child(we)
	var sprite := Sprite2D.new()
	sprite.material = load(BLUR)
	holder.add_child(sprite)
	var dust := CPUParticles2D.new()
	dust.amount = 36
	holder.add_child(dust)
	var spark := CPUParticles2D.new()
	spark.amount = 8
	holder.add_child(spark)
	var light := PointLight2D.new()
	light.shadow_enabled = true
	holder.add_child(light)
	root.add_child(holder)
	quality.apply("low")
	ck(not we.environment.glow_enabled and not we.environment.adjustment_enabled, "Low: no glow, no colour curves")
	ck(env.glow_enabled and env.adjustment_enabled, "the shared Environment resource itself is untouched")
	ck(sprite.material == null, "Low: no depth blur")
	ck(dust.amount == 18 and spark.amount == 8, "Low: 36 particles → 18, a small 8 stays (%d, %d)" % [dust.amount, spark.amount])
	ck(not light.shadow_enabled, "Low: no light shadows")
	quality.apply("high")
	ck(we.environment == env, "High: the original Environment is back")
	ck(sprite.material == load(BLUR), "High: depth blur back")
	ck(dust.amount == 36 and light.shadow_enabled, "High: 36 particles, shadows back")
	holder.free()

	print("[4] Low is in place before the first room draws")
	quality.apply("low")
	tree_set_new_game()
	var game: Node = load("res://SampleProject/Game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	# Перевірка — у мить, коли перша кімната додана (room_loaded), ще до її першого кадру.
	if game.map == null:
		await game.room_loaded
	var world: WorldEnvironment = game.get_node(^"WorldEnvironment")
	ck(not world.environment.glow_enabled and not world.environment.adjustment_enabled,
			"Game's WorldEnvironment: no glow, no colour curves")
	ck(game.map != null, "the first room is already in the tree (%s)" % (game.map.scene_file_path.get_file() if game.map else "none"))
	var blurred: int = 0
	var low_blur: int = 0
	for n: Node in game.find_children("*", "CanvasItem", true, false):
		var m := (n as CanvasItem).material as ShaderMaterial
		if m != null and m.shader != null and m.shader.resource_path in GraphicsQuality.LOW_DROPS_SHADERS:
			blurred += 1
		if n.has_meta(&"graphics_quality_material"):
			low_blur += 1
	ck(blurred == 0 and low_blur > 0, "no layer is drawn with depth blur (%d stripped)" % low_blur)
	var dust_amount: int = (game.get_node(^"Player/Camera2D/AmbientDust") as CPUParticles2D).amount
	ck(dust_amount == 18, "AmbientDust 36 → %d" % dust_amount)
	quality.apply("high")
	ck(world.environment.glow_enabled, "switching to High in play brings the glow back")

	while game.room_preloader.busy():  # вихід посеред фонового завантаження дає Parse Error у лозі
		await process_frame
	DirAccess.remove_absolute(settings_path)
	_done()


func tree_set_new_game() -> void:
	set_meta("start_new_game", true)
	root.get_node("ServiceLocator").get_dialogue_manager().bubble_time_scale = 0.0


func _row(opts: Node, title: String) -> Node:
	for margin in opts._list.get_children():
		if margin.get_child_count() > 0 and margin.get_child(0).name == title:
			return margin.get_child(0)
	return null


func _done() -> void:
	print("RESULT: %s" % ("ALL PASS" if fails.is_empty() else "%d FAIL" % fails.size()))
	quit(0 if fails.is_empty() else 1)
