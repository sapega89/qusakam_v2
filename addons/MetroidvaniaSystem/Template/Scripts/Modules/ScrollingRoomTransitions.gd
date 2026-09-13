## A MetSysModule that handles room transitions, with a scrolling effect.
##
## This module is the same as RoomTransitions, but includes a scrolling effect (similar to Zelda or Metroid). When the player moves to another room, both previous and next rooms will be visible and the camera will scroll to the new room.
##[br][br]Note that this effect works best when rooms have unified size. If you move e.g. from wide horizontal room to wide vertical room, the camera will shift in both axes, resulting in space out of map bounds being visible. This can be masked by fading the surroundings to black, like in Metroid games. The module in its base form does not allow to implement it easily.
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## Time of the scroll effect. Lower means faster scrolling.
var SCROLL_TIME = 0.5
## Дистанція скролу в частках екрана. 1.0 — повний екран (класичний Zelda-ефект),
## 0.5 — половина. Менше значення = коротша панорама.
var SCROLL_DISTANCE: float = 0.5
## Відступ углиб нової кімнати після переходу, px. Без нього гравець лишається
## рівно на шві між клітинками: колізія краю виштовхує його назад за межу, MetSys
## бачить зміну кімнати — і переходи зациклюються без жодного руху гравця.
var EDGE_NUDGE: float = 16.0
var _SCREEN_SIZE: Vector2i

var _player: Node2D
var _prev_cell: Vector3i
#var _change_direction: Vector2

func _initialize():
	_SCREEN_SIZE = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	
	_player = game.player
	assert(_player)
	MetSys.room_changed.connect(_on_room_changed, CONNECT_DEFERRED)
	MetSys.cell_changed.connect(_on_cell_changed)

func _on_room_changed(target_room: String):
	if target_room == MetSys.get_current_room_name():
		# This can happen when teleporting to another room.
		return
	
	var camera: Camera2D = _player.get_node(^"Camera2D")

	# Центр кадру в СТАРІЙ кімнаті — потрібен, щоб вирівняти вертикаль: кімнати
	# різної висоти дають різний clamp камери, і без компенсації кадр стрибає.
	var cam_before := camera.get_screen_center_position()

	var prev_room_instance := MetSys.get_current_room_instance()
	if prev_room_instance:
		prev_room_instance.get_parent().remove_child(prev_room_instance)
	
	var prev_map := game.map
	game.map = null

	# Ховаємо стару кімнату до того, як дізнаємось offset. Поки вона не зсунута,
	# у координатах нової кімнати вона лежить поверх неї, і будь-який кадр,
	# намальований у цей момент, показує її протилежний край.
	if is_instance_valid(prev_map):
		prev_map.visible = false

	await game.load_room(target_room)

	if prev_room_instance:
		var offset := MetSys.get_current_room_instance().get_room_position_offset(prev_room_instance)

		_player.position -= offset
		# Відсуваємо гравця від шва углиб нової кімнати (у бік руху), щоб колізія
		# краю не виштовхнула його назад за межу клітинки.
		_player.position += Vector2(signf(offset.x), signf(offset.y)) * EDGE_NUDGE
		prev_room_instance.queue_free()

		# КРИТИЧНО: у камери ввімкнено position_smoothing_enabled, тож після
		# телепорту гравця вона не стрибає, а повзе через усю кімнату (2592 px).
		# Саме це виглядало як "анімація в протилежному кінці". Ставимо камеру в
		# ціль миттєво, щоб нижче анімувати вже від правильної бази.
		camera.reset_smoothing()
		camera.force_update_scroll()

		# Плавний доїзд камери: кадр стартує з того боку, ЗВІДКИ прийшов гравець,
		# і доїжджає до нього.
		var shift := game.get_viewport().get_visible_rect().size * SCROLL_DISTANCE
		var from_offset := Vector2(
			-signf(offset.x) * shift.x,
			-signf(offset.y) * shift.y
		)

		# Вертикальна компенсація. Кімнати різної висоти (Canyon 960, Village 480)
		# дають різний clamp камери, тож кадр стрибає по вертикалі на цю різницю.
		# Стартуємо з висоти старого кадру і плавно доїжджаємо до нової.
		var cam_after := camera.get_screen_center_position()
		from_offset.y += (cam_before - offset).y - cam_after.y

		# Тепер offset відомий: ставимо стару кімнату впритул за краєм нової і аж
		# тоді повертаємо їй видимість. Так вона з'являється одразу на місці.
		if is_instance_valid(prev_map):
			prev_map.position -= offset
			prev_map.visible = true

		# Стартовий зсув ставимо напряму, а не нульовим tween'ом: інакше встигає
		# промалюватись кадр зі зсувом 0, і перехід читається як стрибок.
		camera.offset = from_offset

		# Пауза потрібна не для картинки, а щоб гравець не перетнув межу назад
		# одразу ж і не зациклив переходи. Камера вже стоїть правильно (вище),
		# тож заморожування дерева їй більше не шкодить.
		game.get_tree().paused = true
		var tween := game.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		# Плавна крива замість лінійної — лінійний рух камери око читає як ривок
		# на старті й на зупинці.
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, ^"offset", Vector2.ZERO, SCROLL_TIME)
		await tween.finished
		camera.offset = Vector2.ZERO

		# Стара кімната більше не потрібна — прибираємо після анімації.
		if is_instance_valid(prev_map):
			prev_map.queue_free()
		game.get_tree().paused = false

func _on_cell_changed(new_cell: Vector3i):
	#var change := new_cell - _prev_cell
	#change_direction = Vector2(change.x, change.y)
	_prev_cell = new_cell
