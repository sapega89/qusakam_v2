extends Control
class_name TimerDisplay

@onready var time_label: Label = $HBoxContainer/TimeLabel

var game_timer: Node = null

func _ready():
	# Шукаємо таймер гри в сцені
	# Спочатку пробуємо знайти в поточній сцені
	game_timer = get_node_or_null("../GameTimer")
	if not game_timer:
		# Якщо не знайшли, пробуємо в root
		game_timer = get_node_or_null("/root/GameTimer")
	
	if game_timer:
		if game_timer.has_signal("time_updated"):
			game_timer.time_updated.connect(_on_time_updated)
		print("Timer display connected to game timer")
	else:
		print("Game timer not found! Will try to connect later.")

func _on_time_updated(time_string: String):
	"""Оновлює відображення часу"""
	if time_label:
		time_label.text = time_string

func set_timer_reference(timer_node: Node):
	"""Встановлює посилання на таймер гри"""
	game_timer = timer_node
	if game_timer:
		if game_timer.has_signal("time_updated"):
			game_timer.time_updated.connect(_on_time_updated)
		print("Timer display connected to provided game timer")

