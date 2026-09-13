# A save point object. Colliding with it saves the game.
extends Area2D

## Offset для позиции спавна (относительно SavePoint)
@export var spawn_offset: Vector2 = Vector2(0, 0)

## Позиционировать игрока при касании (true = игрок встанет на SavePoint)
@export var position_player_on_touch: bool = true

@onready var start_time := Time.get_ticks_msec()

func _ready() -> void:
	body_entered.connect(on_body_entered)
	# Добавляем в группу для поиска SavePoint'ов при загрузке комнаты
	add_to_group("save_points")
	
	# ВАЖЛИВО: Перевіряємо, чи гравець вже всередині Area при завантаженні
	# Це запобігає попередженню Rapier2D про Exit Event без Entry Event
	call_deferred("_check_existing_bodies")

# Player enter save point. Note that in a legit code this should check whether body is really a player.
func on_body_entered(_body: Node2D) -> void:
	if Time.get_ticks_msec() - start_time < 1000:
		return # Small hack to prevent saving at the game start.

	# FIX: Позиционируем игрока на SavePoint перед сохранением
	if position_player_on_touch and _body:
		var spawn_pos = global_position + spawn_offset
		_body.global_position = spawn_pos
		DebugLogger.info("SavePoint: Positioned player at %s" % spawn_pos, "SavePoint")

		# Обновляем MetSys позицию
		MetSys.set_player_position(_body.global_position)

	# Make Game save the data.
	Game.get_singleton().save_game()
	# Starting coords for the delta vector feature.
	Game.get_singleton().reset_map_starting_coords()

func _check_existing_bodies() -> void:
	"""Перевіряє, чи гравець вже всередині Area при завантаженні"""
	# Чекаємо один кадр, щоб фізика ініціалізувалася
	await get_tree().process_frame
	
	# Перевіряємо всі тіла, які вже всередині Area
	var overlapping_bodies = get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			# Гравець вже всередині, викликаємо обробник вручну
			# Це запобігає попередженню Rapier2D про Exit Event без Entry Event
			on_body_entered(body)

func _draw() -> void:
	# Draws the circle.
	$CollisionShape2D.shape.draw(get_canvas_item(), Color.BLUE)
