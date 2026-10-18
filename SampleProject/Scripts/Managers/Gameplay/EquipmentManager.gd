extends ManagerBase
class_name EquipmentManager

## 🛡️ EquipmentManager — запити на екіпірування з меню і зброя в руці (D202).
## Саме екіпірування виконує CharacterManager (EventBus.equipment_*_requested);
## статистику спорядження рахує GameCharacter.get_equipment_stats().

## Слоти зброї (D147). З вдягнених у них одна — в руці: нею бʼє гравець (D203) і за нею
## перевіряються Fire / Electric Strike (D141).
const WEAPON_SLOTS: Array[String] = ["sword", "polearm", "dagger", "axe", "mace", "bow", "staff"]

func _initialize():
	EventBus.equipment_equipped.connect(_on_equipped)
	EventBus.equipment_unequipped.connect(_on_unequipped)

func equip_item(character_id: String, slot_id: String, item_id: String, item_data: Dictionary) -> void:
	EventBus.equipment_equip_requested.emit(character_id, slot_id, item_id, item_data)

func unequip_item(character_id: String, slot_id: String) -> void:
	EventBus.equipment_unequip_requested.emit(character_id, slot_id)


# ── Зброя в руці ────────────────────────────────────────────────────────────

## Слот зброї в руці або "" — голі руки. Зберігається в player_state (PlayerDataModule).
func get_weapon_in_hand() -> String:
	return String(_state().get("weapon_in_hand", ""))

## Предмет у руці (запис ItemDatabase) або {} — голі руки.
func get_weapon_item_in_hand() -> Dictionary:
	var slot := get_weapon_in_hand()
	if slot.is_empty():
		return {}
	return ItemDatabase.get_item(_state().equipment[slot].id)

## Наступна (step = 1) чи попередня (-1) вдягнена зброя. Без вдягненої зброї — голі руки.
func cycle_weapon(step: int) -> void:
	var equipped := _equipped_weapons()
	if equipped.is_empty():
		_set_in_hand("")
		return
	var index := equipped.find(get_weapon_in_hand())
	if index == -1:
		_set_in_hand(equipped[0])
		return
	_set_in_hand(equipped[posmod(index + step, equipped.size())])

func _equipped_weapons() -> Array[String]:
	var equipment: Dictionary = _state().equipment
	return WEAPON_SLOTS.filter(func(slot: String) -> bool: return equipment.get(slot) != null)

func _on_equipped(_character_id: String, slot_id: String, _item_id: String) -> void:
	if slot_id in WEAPON_SLOTS and get_weapon_in_hand().is_empty():
		_set_in_hand(slot_id)

func _on_unequipped(_character_id: String, slot_id: String) -> void:
	if slot_id == get_weapon_in_hand():
		var equipped := _equipped_weapons()
		_set_in_hand(equipped[0] if not equipped.is_empty() else "")

func _set_in_hand(slot_id: String) -> void:
	if slot_id == get_weapon_in_hand():
		return
	_state()["weapon_in_hand"] = slot_id
	EventBus.weapon_in_hand_changed.emit(slot_id)

func _state() -> Dictionary:
	return ServiceLocator.get_game_manager().player_state
