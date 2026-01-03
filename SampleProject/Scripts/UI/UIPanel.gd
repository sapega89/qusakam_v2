extends Control
class_name UIPanel

@onready var gold_display = $VBoxContainer/GoldDisplay
@onready var timer_display = $VBoxContainer/TimerDisplay

func _ready():
	# Ініціалізуємо золото
	if gold_display:
		gold_display.set_gold(0)
		print("UI Panel: Gold display initialized")

func set_gold(amount: int):
	"""Встановлює кількість золота"""
	if gold_display:
		gold_display.set_gold(amount)

func add_gold(amount: int):
	"""Додає золото"""
	if gold_display:
		gold_display.add_gold(amount)

func remove_gold(amount: int):
	"""Віднімає золото"""
	if gold_display:
		gold_display.remove_gold(amount)

func get_gold() -> int:
	"""Повертає поточну кількість золота"""
	if gold_display:
		return gold_display.get_gold()
	return 0

