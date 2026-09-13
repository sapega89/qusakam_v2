extends CanvasLayer
class_name DialogueSystemController

## 💬 DialogueSystemController - Контролер для DialogueSystem
## Приховує DialogueBox за замовчуванням та забезпечує правильну ініціалізацію

@onready var dialogue_box = $DialogueBox
@onready var dialogue_player = $DialoguePlayer

func _ready() -> void:
	"""Ініціалізація DialogueSystem - приховуємо DialogueBox за замовчуванням"""
	DebugLogger.info("💬 DialogueSystemController: Ініціалізація DialogueSystem", "DialogueSystem")
	
	# Приховуємо DialogueBox за замовчуванням
	if dialogue_box:
		dialogue_box.visible = false
		DebugLogger.info("💬 DialogueSystemController: DialogueBox приховано за замовчуванням", "DialogueSystem")
	else:
		DebugLogger.warning("💬 DialogueSystemController: DialogueBox не знайдено!", "DialogueSystem")
	
	# Перевіряємо наявність DialoguePlayer
	if dialogue_player:
		DebugLogger.info("💬 DialogueSystemController: DialoguePlayer знайдено", "DialogueSystem")
	else:
		DebugLogger.warning("💬 DialogueSystemController: DialoguePlayer не знайдено!", "DialogueSystem")
