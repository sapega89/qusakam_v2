extends SceneTree

## Знімок D581: справжній бій із навчальним бандитом на вулиці Village — легкий удар, важкий, парирування, удар по
## героєві. Для кожного — кадр до (замах / підказка) і кадр влучання (завмирання, тряска, білий спалах героя).
## Рядки — чотири удари, стовпці — до і після. Потрібне вікно, не --headless:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_hit_feel.gd
## Файл: design/shots/combat_polish_fight.png

const OUT := "res://design/shots/combat_polish_fight.png"
## Виріз навколо героя (px вікна) і масштаб у листі.
const CROP := Vector2i(640, 360)

var game: Node
var hero: Node
var bandit: Node
var _hit := [false]


func _initialize() -> void:
	await process_frame
	root.get_node("SaveSystem").settings_module.settings.hints = false  # D746: no «?» tips in this run
	await process_frame
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
	hero = game.player
	hero.global_position = Vector2(150, 344)
	hero.velocity = Vector2.ZERO
	for i in 30: await process_frame
	await _drain(dm)
	for i in 30: await process_frame
	bandit = game.map.enemy_spawner.spawned_enemies[0]
	hero.Max_Health = 99999
	hero.current_health = hero.Max_Health
	bandit.Max_Health = 99999
	bandit.current_health = bandit.Max_Health
	var bus: Node = root.get_node("EventBus")
	bus.damage_dealt.connect(func(_s: Node, _t: Node, _a: int) -> void: _hit[0] = true)
	bus.damage_received.connect(func(t: Node, _s: Node, _a: int, _c: bool) -> void:
		if t == hero: _hit[0] = true)
	bus.player_parried.connect(func(_s: Node) -> void: _hit[0] = true)

	# Плашка уроку закриває героя: Tab (cutscene_skip) пропускає навчання, бандит б'ється далі
	await _tap(&"cutscene_skip")
	for i in 20: await process_frame
	var rows: Array = []
	rows.append(await _shot(func() -> void: await _tap(&"attack"), 0.06))
	rows.append(await _shot(func() -> void: await _tap(&"heavy_attack"), 0.2))
	rows.append(await _parry_shot())
	rows.append(await _hurt_shot())

	var sheet := Image.create(CROP.x * 2, CROP.y * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for c in 2:
			if rows[r][c] != null:
				sheet.blit_rect(rows[r][c], Rect2i(Vector2i.ZERO, CROP), Vector2i(c * CROP.x, r * CROP.y))
	sheet.save_png(ProjectSettings.globalize_path(OUT))
	print("CAPTURED " + OUT)
	quit()


## Виріз вікна навколо героя.
func _grab() -> Image:
	var img: Image = root.get_texture().get_image()
	var at: Vector2 = hero.get_global_transform_with_canvas().origin
	var origin := Vector2i(clampi(int(at.x) - CROP.x / 2 + 80, 0, img.get_width() - CROP.x), clampi(int(at.y) - CROP.y / 2 - 40, 0, img.get_height() - CROP.y))
	return img.get_region(Rect2i(origin, CROP))


## Кадр влучання. Під xvfb гра йде ~6 кадрів/с, а спалах і тряска (tween у реальних с) коротші за кадр — тож на
## цей один кадр tween-и стоять, і на знімку їхній перший кадр, а не вже згаслий.
func _grab_hit() -> Image:
	var tweens: Array[Tween] = get_processed_tweens()
	for t in tweens:
		t.pause()
	await RenderingServer.frame_post_draw
	var img: Image = _grab()
	for t in tweens:
		if t.is_valid():
			t.play()
	return img


## Кадр до — після [param before] с від натискання; кадр після — перший кадр після влучання.
func _shot(press: Callable, before: float) -> Array:
	bandit.set_physics_process(false)  # стоїть, щоб його удар не перебив замах героя
	await _face()
	_hit[0] = false
	await press.call()
	await create_timer(before * 0.5).timeout
	await RenderingServer.frame_post_draw
	var first: Image = _grab()
	for i in 240:
		if _hit[0]:
			break
		await process_frame
	var second: Image = await _grab_hit()
	await create_timer(1.2).timeout
	return [first, second]


## Парирування: блок, коли падає жовтий удар; кадр до — підказка на зброї бандита.
func _parry_shot() -> Array:
	for attempt in 8:
		await _face()
		bandit.set_physics_process(true)
		await _bandit_signal(&"attack_telegraphed")
		if bandit.enemy_logic.tell_kind != &"parry":
			await create_timer(1.0).timeout
			continue
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		var first: Image = _grab()
		_hit[0] = false
		await create_timer(bandit.enemy_logic.TELL_LEAD - hero.combat.PARRY_WINDOW + 0.08 - 0.15).timeout
		_press(&"block", true)
		for i in 60:
			if _hit[0]:
				break
			await process_frame
		var second: Image = await _grab_hit()
		_press(&"block", false)
		await create_timer(1.2).timeout
		return [first, second]
	return [null, null]


## Удар по героєві: стоїть і нічого не робить; кадр до — підказка, після — влучання.
func _hurt_shot() -> Array:
	bandit.set_physics_process(true)
	for attempt in 6:
		await _face()
		await _bandit_signal(&"attack_telegraphed")
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		var first: Image = _grab()
		_hit[0] = false
		for i in 120:
			if _hit[0]:
				break
			await process_frame
		if not _hit[0]:
			await create_timer(1.0).timeout
			continue
		var second: Image = await _grab_hit()
		await create_timer(1.2).timeout
		return [first, second]
	return [null, null]


func _face() -> void:
	await create_timer(0.3).timeout
	var side: float = -1.0 if hero.global_position.x < bandit.global_position.x else 1.0
	hero.global_position = Vector2(bandit.global_position.x + side * 30.0, bandit.global_position.y - 4.0)
	hero.velocity = Vector2.ZERO
	hero.mover.last_direction = int(-side)
	hero.current_health = hero.Max_Health
	for i in 4: await physics_frame


func _bandit_signal(sig: StringName) -> void:
	var fired := [false]
	var on_fire := func() -> void: fired[0] = true
	bandit.enemy_logic.connect(sig, on_fire, CONNECT_ONE_SHOT)
	for i in 600:
		if fired[0]:
			return
		await physics_frame
	bandit.enemy_logic.disconnect(sig, on_fire)


func _press(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap(action: StringName) -> void:
	_press(action, true)
	await physics_frame
	await physics_frame
	_press(action, false)


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
