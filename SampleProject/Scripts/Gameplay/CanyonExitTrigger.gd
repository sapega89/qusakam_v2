extends Area2D
class_name CanyonExitTrigger

## 🚪 Триггер выхода из каньона
## При входе игрока показывает катсцену спуска с каньона, затем переход в пустыню

@export var one_shot: bool = true  # Срабатывает только один раз
@export var target_room: String = "DesertRoad.tscn"  # Комната для перехода после катсцены

var has_triggered: bool = false

func _ready() -> void:
	"""Настройка обнаружения столкновений"""
	# Проверяем, не подключен ли сигнал уже (чтобы избежать ошибки при повторном вызове _ready)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	"""Игрок вошел в зону выхода"""
	if has_triggered and one_shot:
		return

	# Проверяем, что это игрок
	if not body.is_in_group(GameGroups.PLAYER):
		return

	has_triggered = true
	_trigger_exit_cutscene()

func _trigger_exit_cutscene() -> void:
	"""Вызывает катсцену спуска через Canyon scene manager"""
	var canyon_scene = get_tree().current_scene
	if canyon_scene and canyon_scene.has_method("trigger_exit_cutscene"):
		canyon_scene.trigger_exit_cutscene(target_room)
		DebugLogger.info("CanyonExitTrigger: Катсцена спуска активирована", "Scene")
	else:
		DebugLogger.warning("CanyonExitTrigger: Canyon scene manager не найден", "Scene")

func reset() -> void:
	"""Сброс триггера (для тестирования/отладки)"""
	has_triggered = false
