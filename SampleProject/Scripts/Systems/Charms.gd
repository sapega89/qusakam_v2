extends RefCounted

## Обереги (D592, charms_plan): персні й амулети, що змінюють правило, як у Hollow Knight. Дані — charms.json,
## стан — player_state.charms {owned, equipped, slots} (зберігає PlayerDataModule). Кожне правило читає
## система, якій воно належить: Charms.effect(&"parry_heal") тощо.
##   const Charms = preload("res://SampleProject/Scripts/Systems/Charms.gd")
##   Charms.grant("grandfathers_ring"); Charms.equip(0, "grandfathers_ring")

const DATA_PATH := "res://SampleProject/Resources/Data/charms.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


## Скільки слотів усього (відкритих і закритих).
static func total_slots() -> int:
	return int(data().slots.total)


## Початковий стан для нового героя (PlayerStateManager._initial_state).
static func initial_state() -> Dictionary:
	var equipped: Array = []
	equipped.resize(total_slots())
	equipped.fill("")
	return {"owned": [], "equipped": equipped, "slots": int(data().slots.at_start)}


static func get_charm(charm_id: String) -> Dictionary:
	for charm: Dictionary in data().charms:
		if String(charm.id) == charm_id:
			return charm
	return {}


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for charm: Dictionary in data().charms:
		ids.append(String(charm.id))
	return ids


static func charm_name(charm_id: String) -> String:
	return TranslationServer.translate(String(get_charm(charm_id).name))


static func charm_description(charm_id: String) -> String:
	return TranslationServer.translate(String(get_charm(charm_id).description))


static func icon(charm_id: String) -> Texture2D:
	return load(String(get_charm(charm_id).icon_path))


# ── Стан ────────────────────────────────────────────────────────────────────

static func _state() -> Dictionary:
	return ServiceLocator.get_game_manager().player_state.charms


static func owned() -> Array:
	return _state().owned


static func equipped() -> Array:
	return _state().equipped


## Відкритих слотів: 2 на старті, третій — після Латунного Збирача (D592, MayorHall).
static func open_slots() -> int:
	return int(_state().slots)


static func unlock_slot() -> void:
	_state().slots = mini(open_slots() + 1, total_slots())
	EventBus.charms_changed.emit()


## Знайдений оберіг (скриня). Повертає false, якщо такого немає або він уже є.
static func grant(charm_id: String) -> bool:
	if get_charm(charm_id).is_empty() or charm_id in owned():
		return false
	owned().append(charm_id)
	EventBus.charms_changed.emit()
	return true


## Вдягає [param charm_id] у слот [param slot]; з іншого слота він знімається. Слот має бути відкритим, оберіг — знайденим.
static func equip(slot: int, charm_id: String) -> bool:
	if slot < 0 or slot >= open_slots() or charm_id not in owned():
		return false
	var worn := equipped()
	var was := worn.find(charm_id)
	if was >= 0:
		worn[was] = ""
	worn[slot] = charm_id
	EventBus.charms_changed.emit()
	return true


static func unequip(slot: int) -> void:
	equipped()[slot] = ""
	EventBus.charms_changed.emit()


## Сума ефекту [param name] з усіх вдягнених оберегів (0 — жоден його не дає).
static func effect(name: StringName) -> float:
	var total := 0.0
	for charm_id: String in equipped():
		if charm_id != "":
			total += float(get_charm(charm_id).effects.get(String(name), 0.0))
	return total


static func has_effect(name: StringName) -> bool:
	return effect(name) != 0.0
