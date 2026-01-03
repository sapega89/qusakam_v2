extends Control
class_name BaseMenuComponent

## Базовый класс для компонентов игрового меню
## Предоставляет общий доступ к game_manager и item_database

var game_manager: Node = null
var item_database: Node = null

## Сигналы для взаимодействия с меню
signal item_equipped(item_id: String, slot_id: String)
signal request_tab(tab_name: String)

func _ready() -> void:
	"""Инициализация базового компонента"""
	# Получаем game_manager и item_database через ServiceLocator
	var service_locator = ServiceLocatorHelper.get_service_locator()
	if service_locator:
		game_manager = service_locator.get_game_manager()
		item_database = service_locator.get_item_database()
	
	# Вызываем инициализацию компонента
	_initialize_component()

func _initialize_component() -> void:
	"""Инициализация компонента (должен быть переопределен в дочерних классах)
	
	Это абстрактный метод - дочерние классы ОБЯЗАНЫ его переопределить.
	Если метод не переопределен, будет выдана ошибка во время выполнения.
	"""
	push_error("BaseMenuComponent._initialize_component() должен быть переопределен в дочернем классе: " + get_script().get_path())
	# Альтернативно можно использовать assert, но push_error более информативен
	# assert(false, "BaseMenuComponent._initialize_component() должен быть переопределен")

func update_display() -> void:
	"""Обновление отображения (переопределяется в дочерних классах)"""
	pass

func emit_item_equipped(item_id: String, slot_id: String):
	"""Эмитит сигнал экипировки предмета"""
	item_equipped.emit(item_id, slot_id)

func request_tab_change(tab_name: String):
	"""Эмитит сигнал запроса смены вкладки"""
	request_tab.emit(tab_name)
