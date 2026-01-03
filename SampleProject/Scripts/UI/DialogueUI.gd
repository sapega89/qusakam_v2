extends CanvasLayer
class_name DialogueUI

## 🗣️ DialogueUI - Базовий UI компонент для діалогів
## Інтегрується з DialogueManager та DialogueQuest

@onready var panel = $Panel
@onready var label = $Panel/ScrollContainer/VBoxContainer/Label

var dialogue_manager: Node = null

func _ready():
	# Знаходимо DialogueManager
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_dialogue_manager"):
			dialogue_manager = service_locator.get_dialogue_manager()
	
	# Підписуємося на події DialogueManager
	if dialogue_manager:
		if dialogue_manager.has_signal("dialogue_started"):
			dialogue_manager.dialogue_started.connect(_on_dialogue_started)
		if dialogue_manager.has_signal("dialogue_ended"):
			dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	
	# Приховуємо панель на старті
	if panel:
		panel.visible = false

func show_dialogue(text: String = ""):
	"""Показує діалог з текстом"""
	if label:
		if text.is_empty():
			label.text = "Тут знову цей недоумок без здібностей? " + "Тут знову цей недоумок без здібностей? " + "Тут знову цей недоумок без здібностей?" + "Тут знову цей недоумок без здібностей? " + "Тут знову цей недоумок без здібностей? " + "Тут знову цей недоумок без здібностей?"
		else:
			label.text = text
	
	if panel:
		panel.visible = true

func hide_dialogue():
	"""Приховує діалог"""
	if panel:
		panel.visible = false

func _input(event):
	"""Обробляє ввід для закриття діалогу"""
	if panel and panel.visible and event.is_action("ui_accept") and event.pressed:
		hide_dialogue()

func _on_dialogue_started(dialogue_id: String):
	"""Обробляє початок діалогу"""
	# Показуємо UI
	if panel:
		panel.visible = true

func _on_dialogue_ended(dialogue_id: String):
	"""Обробляє завершення діалогу"""
	# Приховуємо UI
	if panel:
		panel.visible = false

func _on_enemy_trigger_player_entered() -> void:
	"""Обробник для EnemyTrigger (для зворотної сумісності)"""
	show_dialogue()

func _exit_tree() -> void:
	"""Відписується від всіх сигналів при видаленні вузла"""
	_disconnect_all_signals()

func _disconnect_all_signals() -> void:
	"""Відписується від всіх сигналів для запобігання витоків пам'яті"""
	if dialogue_manager:
		if dialogue_manager.has_signal("dialogue_started") and dialogue_manager.dialogue_started.is_connected(_on_dialogue_started):
			dialogue_manager.dialogue_started.disconnect(_on_dialogue_started)
		if dialogue_manager.has_signal("dialogue_ended") and dialogue_manager.dialogue_ended.is_connected(_on_dialogue_ended):
			dialogue_manager.dialogue_ended.disconnect(_on_dialogue_ended)

