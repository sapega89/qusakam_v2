extends Area2D
class_name AbductionZoneTrigger

## Триггер зоны для катсцены с уводом жителей
## Вызывается при входе игрока в зону после изучения окружения

@export var one_shot: bool = true  # Срабатывает только один раз

var has_triggered: bool = false

func _ready() -> void:
	"""Настройка обнаружения столкновений"""
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	"""Игрок вошел в зону"""
	if has_triggered and one_shot:
		return

	# Проверяем, что это игрок
	if not body.is_in_group(GameGroups.PLAYER):
		return

	has_triggered = true
	_trigger_cutscene()

func _trigger_cutscene() -> void:
	"""Вызывает катсцену через Canyon scene manager"""
	var canyon_scene = get_tree().current_scene
	if canyon_scene and canyon_scene.has_method("trigger_abduction_cutscene"):
		canyon_scene.trigger_abduction_cutscene()
		DebugLogger.info("AbductionZoneTrigger: Катсцена активирована", "Scene")
	else:
		DebugLogger.warning("AbductionZoneTrigger: Canyon scene manager не найден", "Scene")

func reset() -> void:
	"""Сброс триггера (для тестирования/отладки)"""
	has_triggered = false
