extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## Прохід крізь край кімнати (D434): MetSys бачить героя в клітинці сусідньої кімнати → Game.load_room() гасить екран,
## міняє кімнату і світлішає. Тут — лише те, що властиве проходу: героя зсуваємо в координати нової кімнати,
## а гра стоїть на паузі до кінця появи, щоб герой не перетнув межу назад і не зациклив переходи.
## Замінює ScrollingRoomTransitions: панорама камери під чорним екраном не видна.

## Відступ углиб нової кімнати після переходу, px. Без нього гравець лишається рівно на шві між клітинками:
## колізія краю виштовхує його назад за межу, MetSys бачить зміну кімнати — і переходи зациклюються.
const EDGE_NUDGE := 16.0

var _player: Node2D


func _initialize() -> void:
	_player = game.player
	MetSys.room_changed.connect(_on_room_changed, CONNECT_DEFERRED)


func _on_room_changed(target_room: String) -> void:
	# room_changed дає шлях ("DesertRoad.tscn"), а get_current_room_name() — ":uid". Без переведення в один формат
	# рівність не справджувалась ніколи, і після кожного телепорту кімната вантажилась удруге (B51).
	if target_room == MetSys.map_data.get_uid_room(MetSys.get_current_room_name()):
		return  # телепорт: кімнату вже замінив teleport_to_room()
	var tree := game.get_tree()
	tree.paused = true
	var from_coords: Vector2i = MetSys.get_current_room_instance().get_base_coords()
	await game.load_room(target_room)

	var to_coords: Vector2i = MetSys.get_current_room_instance().get_base_coords()
	var offset := Vector2(to_coords - from_coords) * MetSys.settings.in_game_cell_size
	_player.position -= offset
	_player.position += Vector2(signf(offset.x), signf(offset.y)) * EDGE_NUDGE
	# У камери ввімкнено position_smoothing: без скидання вона повзла б через усю кімнату до героя.
	var camera: Camera2D = _player.get_node(^"Camera2D")
	camera.reset_smoothing()
	camera.force_update_scroll()

	if game.room_changing:
		await game.room_change_finished
	tree.paused = false
