extends BaseMenuComponent
class_name BaseOptionsComponent

## Базовый класс для компонента опций
## Наследуется от BaseMenuComponent для общей функциональности

func _ready() -> void:
	"""Инициализация компонента опций"""
	super._ready()
	_setup_mode()

func _initialize_component() -> void:
	"""Инициализация компонента опций (переопределяется в дочерних классах)"""
	# BaseOptionsComponent - это промежуточный базовый класс,
	# поэтому просто передаем вызов дальше или делаем базовую инициализацию
	pass

func _setup_mode() -> void:
	"""Настройка режима компонента (переопределяется в дочерних классах)"""
	pass

