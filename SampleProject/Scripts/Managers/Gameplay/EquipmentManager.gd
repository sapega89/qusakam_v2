extends ManagerBase
class_name EquipmentManager

## 🛡️ EquipmentManager — запити на екіпірування з меню.
## Саме екіпірування виконує CharacterManager (EventBus.equipment_*_requested);
## статистику спорядження рахує GameCharacter.get_equipment_stats().

func _initialize():
	pass

func equip_item(character_id: String, slot_id: String, item_id: String, item_data: Dictionary) -> void:
	EventBus.equipment_equip_requested.emit(character_id, slot_id, item_id, item_data)

func unequip_item(character_id: String, slot_id: String) -> void:
	EventBus.equipment_unequip_requested.emit(character_id, slot_id)
