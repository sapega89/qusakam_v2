extends SceneTree

## Проходження очима гравця: справжнє вікно, справжній ввід (клавіші й кліки в екранних координатах),
## на кожному кроці — знімок і рядки транскрипту. Порівнює їх з еталоном, який затвердив Sapega.
## Ловить те, чого не бачать verify_*.gd: панель поверх меню, кнопку за екраном, діалог не там.
##
##   Scripts/Tools/playthrough.sh            — прогін, один рядок PLAYTHROUGH: PASS / FAIL
##   Scripts/Tools/playthrough.sh --approve  — поточні знімки й транскрипт стають еталоном (лише з дозволу Sapega)
##
## Еталон: design/playthrough/ (<крок>.png 960×540 + transcript.txt). Поточний прогін і картинки
## різниці: logs/playthrough/. Вікно обов'язкове (--headless дає чорні кадри).

const BASE_DIR := "res://design/playthrough/"
const OUT_DIR := "res://logs/playthrough/"
const SAVE_DIR := "user://playthrough/"
const SHOT_SIZE := Vector2i(960, 540)      # зберігаємо — для перегляду людиною
const CMP_SIZE := Vector2i(480, 270)       # порівнюємо — швидко в GDScript
const PIXEL_DELTA := 0.1                   # піксель «інший», якщо канал зсунувся більше ніж на 10%
const TOLERANCE := 0.015                   # крок падає, якщо інших пікселів більше 1.5%
const TOLERANCE_GAMEPLAY := 0.05           # у грі анімації й частинки — 5%

var _approve := false
var _transcript: PackedStringArray = []
var _failures: PackedStringArray = []


func _initialize() -> void:
	_approve = "--approve" in OS.get_cmdline_user_args()
	var previous_size := DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if _approve:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE_DIR))
	var save_system: Node = root.get_node("SaveSystem")
	save_system.set_save_dir(SAVE_DIR)  # налаштування й сейви прогону не чіпають справжні
	await process_frame
	await process_frame
	# Менеджери реєструються в ServiceLocator лише після перших кадрів.
	root.get_node("ServiceLocator").get_dialogue_manager().dialogue_started.connect(
			func(id: String) -> void: _log("dialogue " + id.get_file().get_basename()))

	# ── Маршрут 1: старт гри (Sapega, 2026-10-16: «при вході в гру все зламане») ──────────────
	var menu: Node = load("res://SampleProject/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _wait(1.0)
	await _step("01_splash")

	await _key(KEY_SPACE)                                  # PRESS ANY BUTTON
	await _wait(1.2)
	await _step("02_main_menu")

	await _click(menu.menu.get_node("options"))
	await _wait(1.5)
	await _step("03_settings_display")
	var opts: Node = get_first_node_in_group("settings_screen")
	for tab in ["audio", "game", "controls"]:
		opts.switch_to_tab(tab)
		await _wait(0.5)
		await _step("04_settings_" + tab)

	await _key(KEY_ESCAPE)                                 # закриває Settings, не гру
	await _wait(1.2)
	await _step("05_main_menu_back")

	await _key(KEY_ESCAPE)                                 # «Exit Game?»
	await _wait(0.5)
	await _step("06_exit_modal")
	await _click(_modal_button("Cancel"))
	await _wait(0.5)

	await _click(menu.menu.get_node("new_game"))
	await _wait(4.0)
	await _step("07_game_start", TOLERANCE_GAMEPLAY)

	# ── Маршрут 2: перші хвилини Кусакамом (Sapega, 2026-10-16: «побігати кусакамом, подивитись,
	# що доступне — поки тільки меню Misc») ────────────────────────────────────────────────────
	var game: Node = current_scene
	await _finish_dialogues()                              # вступ Canyon, Enter гортає (D192)
	await _step("08_canyon_free", TOLERANCE_GAMEPLAY)

	var x0: float = game.player.global_position.x
	await _hold(KEY_D, 1.5)
	_log("run right: %s" % _yes(game.player.global_position.x > x0 + 50.0))
	await _step("09_ran_right", TOLERANCE_GAMEPLAY)
	var y0: float = game.player.global_position.y
	await _key(KEY_SPACE)
	await _wait(0.15)
	_log("jump: %s" % _yes(game.player.global_position.y < y0 - 10.0))
	await _wait(1.0)
	var x1: float = game.player.global_position.x
	await _hold(KEY_A, 1.0)
	_log("run left: %s" % _yes(game.player.global_position.x < x1 - 50.0))
	await _step("10_ran_left", TOLERANCE_GAMEPLAY)

	await _key(KEY_ESCAPE)                                 # Game Menu; на старті відкрита лише Misc (D151)
	await _wait(0.8)
	await _step("11_game_menu")
	var game_menu: Node = get_first_node_in_group("game_menu")
	await _click(game_menu.misc_button)
	await _wait(0.5)
	await _step("12_misc")
	await _click(_misc_button("Settings"))
	await _wait(0.8)
	await _step("13_misc_settings")

	await _click(game_menu.misc_button)
	await _wait(0.5)
	await _click(_misc_button("Tutorial"))
	await _wait(0.8)
	await _step("14_tutorial")
	await _key(KEY_ESCAPE)
	await _wait(0.5)
	game_menu = get_first_node_in_group("game_menu")
	var menu_open: bool = game_menu != null and game_menu.is_visible_in_tree()
	_log("Esc in Tutorial keeps the Game Menu open: %s" % _yes(menu_open))
	if not menu_open:
		await _key(KEY_ESCAPE)
		await _wait(0.8)
		game_menu = get_first_node_in_group("game_menu")

	await _click(game_menu.misc_button)
	await _wait(0.5)
	await _click(_misc_button("Quit the Game"))
	await _wait(0.5)
	await _step("15_quit_confirm")
	await _click(_modal_button("Cancel"))
	await _wait(0.5)

	await _click(game_menu.misc_button)
	await _wait(0.5)
	await _click(_misc_button("Return to Title"))
	await _wait(0.5)
	await _step("16_return_confirm")
	await _click(_modal_button("Exit"))
	await _wait(1.5)
	await _step("17_back_on_title")

	# ── Підсумок ─────────────────────────────────────────────────────────────────────────────
	_check_transcript()
	save_system.set_save_dir(save_system.SAVE_DIR)
	_wipe(SAVE_DIR)
	DisplayServer.window_set_size(previous_size)
	if _approve:
		print("PLAYTHROUGH: APPROVED — design/playthrough/ updated, commit it")
	elif _failures.is_empty():
		print("PLAYTHROUGH: PASS")
	else:
		print("PLAYTHROUGH: FAIL %d — %s" % [_failures.size(), ", ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)


# ── Кроки ────────────────────────────────────────────────────────────────────────────────────

func _step(name: String, tolerance: float = TOLERANCE) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	shot.resize(SHOT_SIZE.x, SHOT_SIZE.y, Image.INTERPOLATE_BILINEAR)
	var scene: String = current_scene.scene_file_path.get_file() if current_scene else "<none>"
	var modal: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal
	_log("step %s | scene %s | modal %s" % [name, scene, _modal_name(modal)])
	var out_path := OUT_DIR + name + ".png"
	shot.save_png(ProjectSettings.globalize_path(out_path))
	if _approve:
		shot.save_png(ProjectSettings.globalize_path(BASE_DIR + name + ".png"))
		return
	var base_path := BASE_DIR + name + ".png"
	if not FileAccess.file_exists(base_path):
		_fail(name, "NEW, no baseline — %s" % out_path)
		return
	var ratio := _diff(Image.load_from_file(ProjectSettings.globalize_path(base_path)), shot,
			OUT_DIR + name + "_diff.png")
	if ratio > tolerance:
		_fail(name, "%.1f%% of pixels differ — %s_diff.png" % [ratio * 100.0, OUT_DIR + name])


## Частка різних пікселів; червоним на сірому — картинка різниці для того, хто розбирається.
func _diff(base: Image, current: Image, diff_path: String) -> float:
	var a: Image = base.duplicate()
	var b: Image = current.duplicate()
	a.resize(CMP_SIZE.x, CMP_SIZE.y, Image.INTERPOLATE_BILINEAR)
	b.resize(CMP_SIZE.x, CMP_SIZE.y, Image.INTERPOLATE_BILINEAR)
	var diff := Image.create(CMP_SIZE.x, CMP_SIZE.y, false, Image.FORMAT_RGB8)
	var different := 0
	for y in CMP_SIZE.y:
		for x in CMP_SIZE.x:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var delta: float = maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			if delta > PIXEL_DELTA:
				different += 1
				diff.set_pixel(x, y, Color.RED)
			else:
				diff.set_pixel(x, y, Color(cb.get_luminance(), cb.get_luminance(), cb.get_luminance()) * 0.5)
	var ratio := float(different) / float(CMP_SIZE.x * CMP_SIZE.y)
	if ratio > 0.0:
		diff.save_png(ProjectSettings.globalize_path(diff_path))
	return ratio


func _check_transcript() -> void:
	var out_path := OUT_DIR + "transcript.txt"
	var text := "\n".join(_transcript) + "\n"
	FileAccess.open(out_path, FileAccess.WRITE).store_string(text)
	var base_path := BASE_DIR + "transcript.txt"
	if _approve:
		FileAccess.open(base_path, FileAccess.WRITE).store_string(text)
		return
	if not FileAccess.file_exists(base_path):
		_fail("transcript", "NEW, no baseline — %s" % out_path)
		return
	var expected: PackedStringArray = FileAccess.get_file_as_string(base_path).strip_edges().split("\n")
	for i in maxi(expected.size(), _transcript.size()):
		var want: String = expected[i] if i < expected.size() else "<end>"
		var got: String = _transcript[i] if i < _transcript.size() else "<end>"
		if want != got:
			_fail("transcript", "line %d: expected «%s», got «%s»" % [i + 1, want, got])
			return


# ── Ввід гравця ──────────────────────────────────────────────────────────────────────────────

func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame


## Клік миші в центр контрола — у координатах вікна, як справжня миша. Якщо щось перекриває
## кнопку, клік дістанеться тому, що зверху, і транскрипт це покаже.
func _click(control: Control) -> void:
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		_fail("click", "nothing to click (gone or hidden)")
		return
	var at: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await process_frame
	await process_frame  # один кадр після закриття модалки — кнопка ще не «бачить» курсор
	var under: Control = root.gui_get_hovered_control()
	_log("click %s → %s" % [_label(control), _label(under)])
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await process_frame


## Кнопки модалок створюються в коді з іменами @Button@N, що міняються від запуску — у транскрипт
## пишемо текст кнопки.
func _label(control: Control) -> String:
	if control == null:
		return "nothing"
	if control is Button and control.text != "":
		return "«%s»" % control.text
	return control.name


## Рядок підменю Misc (MiscMenuModal) за текстом.
func _misc_button(text: String) -> Control:
	var modal: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal
	if modal == null:
		return null
	for b in modal.find_children("*", "Button", true, false):
		if b.visible and b.text == text:
			return b
	return null


func _modal_button(text: String) -> Control:
	var modal: Node = root.get_node("ServiceLocator").get_ui_manager().get_modal_layer().active_modal
	if modal == null:
		return null
	for b in modal.buttons_container.get_children():
		if b is Button and b.visible and b.text == text:  # у сцені є прихований шаблон CancelButton
			return b
	return null


# ── Дрібне ───────────────────────────────────────────────────────────────────────────────────

## Тримає клавішу, як гравець, що біжить.
func _hold(keycode: Key, seconds: float) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = true
	Input.parse_input_event(e)
	await _wait(seconds)
	var up: InputEventKey = e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


## Гортає репліки Enter, доки не стихнуть і діалоги, і облачка (вони йдуть ланцюжком).
func _finish_dialogues() -> void:
	var dm: Node = root.get_node("ServiceLocator").get_dialogue_manager()
	var quiet := 0.0
	for i in 200:
		if dm.is_dialogue_active() or dm.is_bubble_playing():
			quiet = 0.0
			await _key(KEY_ENTER)
		else:
			quiet += 0.3
			if quiet >= 1.5:
				return
		await _wait(0.3)
	_fail("dialogues", "still talking after 60 s")


## Заголовок модалки для транскрипту; у підменю Misc (MiscMenuModal) заголовка немає — ім'я вузла.
func _modal_name(modal: Node) -> String:
	if modal == null:
		return "-"
	return modal.title_label.text if "title_label" in modal else String(modal.name)


func _yes(ok: bool) -> String:
	return "yes" if ok else "NO"


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _log(line: String) -> void:
	_transcript.append(line)


func _fail(step: String, why: String) -> void:
	_failures.append(step)
	print("  FAIL %s: %s" % [step, why])


func _wipe(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)
