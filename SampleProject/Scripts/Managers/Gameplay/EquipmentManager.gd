extends ManagerBase
class_name EquipmentManager

## 🛡️ EquipmentManager - Управление экипировкой
## Отвечает только за управление экипировкой персонажей
## Согласно SRP: одна ответственность - управление экипировкой

# Preload GameCharacter script to ensure it's loaded (class_name should be available globally)
const GameCharacterScript = preload("res://SampleProject/Scripts/Systems/Character.gd")

# Ссылка на CharacterManager для работы с персонажами (DEPRECATED - используем EventBus)
# var character_manager: CharacterManager = null

# Ссылка на ItemDatabase для получения данных предметов
var item_database: Node = null

# Сигналы (DEPRECATED - используем EventBus.equipment_equipped/unequipped)
signal equipment_changed(character_id: String, slot_id: String)
signal equipment_updated()

func _initialize():
	"""Инициализирует зависимости после того, как ServiceLocator зарегистрирует все сервисы"""
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator:
			# Убрали зависимость от CharacterManager - используем EventBus
			if service_locator.has_method("get_item_database"):
				item_database = service_locator.get_item_database()
		if not item_database:
			push_warning("⚠️ EquipmentManager: ItemDatabase not found!")

	# Подключаемся к EventBus для получения уведомлений об экипировке
	EventBus.equipment_equipped.connect(_on_equipment_equipped)
	EventBus.equipment_unequipped.connect(_on_equipment_unequipped)

func get_equipment_stats(character: GameCharacter = null) -> Dictionary:
	"""Получает общие статы из всей экипировки"""
	if not character:
		var char_manager = _get_character_manager()
		if char_manager:
			character = char_manager.get_active_character()
		if not character:
			return {}
	
	# Используем метод персонажа если доступен
	if character and character.has_method("get_equipment_stats"):
		return character.get_equipment_stats()
	
	# Fallback: вычисляем вручную
	var total_stats = {
		"attack": 0,
		"defense": 0,
		"magic": 0,
		"strength": 0,
		"intelligence": 0,
		"dexterity": 0,
		"constitution": 0
	}
	
	if not item_database:
		return total_stats
	
	# Суммируем статы из всех экипированных предметов
	for slot_id in character.equipment.keys():
		var equipped_item = character.equipment[slot_id]
		if equipped_item and equipped_item is Dictionary:
			var item_id = equipped_item.get("id", "")
			if item_id != "":
				var item_data = item_database.get_item(item_id)
				if not item_data.is_empty():
					var stats = item_data.get("stats", {})
					if stats is Dictionary:
						total_stats["attack"] += stats.get("attack", 0)
						total_stats["defense"] += stats.get("defense", 0)
						total_stats["magic"] += stats.get("magic", 0)
						total_stats["strength"] += stats.get("strength", 0)
						total_stats["intelligence"] += stats.get("intelligence", 0)
						total_stats["dexterity"] += stats.get("dexterity", 0)
						total_stats["constitution"] += stats.get("constitution", 0)
	
	return total_stats

func equip_item(character_id: String, slot_id: String, item_id: String, item_data: Dictionary) -> bool:
	"""Экипирует предмет в слот через EventBus"""
	# Эмитируем запрос на экипирование через EventBus
	# CharacterManager обработает запрос и выполнит экипирование
	EventBus.equipment_equip_requested.emit(character_id, slot_id, item_id, item_data)

	# Возвращаем true - предполагаем успех (можно добавить проверку через сигналы)
	return true

func unequip_item(character_id: String, slot_id: String) -> bool:
	"""Снимает предмет со слота через EventBus"""
	# Эмитируем запрос на снятие через EventBus
	# CharacterManager обработает запрос и выполнит снятие
	EventBus.equipment_unequip_requested.emit(character_id, slot_id)

	# Возвращаем true - предполагаем успех
	return true

func get_equipped_item(character_id: String, slot_id: String) -> Dictionary:
	"""Получает экипированный предмет из слота (read-only)"""
	# Для read-операций используем CharacterManager напрямую
	var character_manager = _get_character_manager()
	if not character_manager:
		return {}

	var character = character_manager.get_character(character_id)
	if not character:
		return {}

	var equipped = character.equipment.get(slot_id, null)
	if equipped and equipped is Dictionary:
		return equipped
	return {}

func get_all_equipment(character_id: String) -> Dictionary:
	"""Получает всю экипировку персонажа (read-only)"""
	# Для read-операций используем CharacterManager напрямую
	var character_manager = _get_character_manager()
	if not character_manager:
		return {}

	var character = character_manager.get_character(character_id)
	if not character:
		return {}

	return character.equipment.duplicate()

func _get_character_manager() -> CharacterManager:
	"""Получает CharacterManager через ServiceLocator (только для read-операций)"""
	if Engine.has_singleton("ServiceLocator"):
		var service_locator = Engine.get_singleton("ServiceLocator")
		if service_locator and service_locator.has_method("get_character_manager"):
			return service_locator.get_character_manager()
	return null

## Обработчик успешного экипирования (из EventBus)
func _on_equipment_equipped(character_id: String, slot_id: String, _item_id: String) -> void:
	"""Обрабатывает уведомление об экипировании"""
	# Эмитируем старые сигналы для обратной совместимости
	equipment_changed.emit(character_id, slot_id)
	equipment_updated.emit()

## Обработчик успешного снятия (из EventBus)
func _on_equipment_unequipped(character_id: String, slot_id: String) -> void:
	"""Обрабатывает уведомление о снятии экипировки"""
	# Эмитируем старые сигналы для обратной совместимости
	equipment_changed.emit(character_id, slot_id)
	equipment_updated.emit()

func _exit_tree() -> void:
	"""Отключаемся от EventBus при удалении"""
	if EventBus.equipment_equipped.is_connected(_on_equipment_equipped):
		EventBus.equipment_equipped.disconnect(_on_equipment_equipped)
	if EventBus.equipment_unequipped.is_connected(_on_equipment_unequipped):
		EventBus.equipment_unequipped.disconnect(_on_equipment_unequipped)
