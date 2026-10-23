extends Area2D
class_name ItemPickup

## Предмет у світі гри, який підбирають через підказку взаємодії (D71):
##   1. поруч — UI/Interaction/Prompt "Pick up";
##   2. interact — предмет іде в інвентар через InventoryManager;
##   3. модалка підтвердження UI/Modal/ItemPickup ("You obtained: …").
##
## Дані предмета — лише з ItemDatabase. Невідомий item_id вимикає підбір,
## нічого не вигадуючи. У світі предмет — блиск (D446), що саме лежить, видно лише в модалці підбору.

signal picked_up(item_id: String, amount: int)

@export var item_id: String = ""
@export_range(1, 999) var amount: int = 1
## Предмет, покладений у кімнату, підбирається один раз: стан кімнати (D152) пам'ятає "picked_<імʼя вузла>" (D298).
## false — предмет поза кімнатою (кинутий у світ скриптом, тести).
@export var persistent: bool = true

@onready var _interactable: InteractableComponent = $Interactable


func _ready() -> void:
	if persistent and Game.get_singleton().get_room_state(_room(), _state_key(), false):
		queue_free()
		return
	_interactable.interacted.connect(_on_interacted)
	var db := _item_database()
	if db == null or db.get_item(item_id).is_empty():
		push_error("ItemPickup: unknown item_id '%s' at %s" % [item_id, get_path()])
		_interactable.enabled = false


func _on_interacted() -> void:
	var inventory = ServiceLocatorHelper.get_manager("get_inventory_manager")
	if inventory == null or not inventory.add_item(item_id, amount):
		DebugLogger.warning("ItemPickup: could not add '%s' to the inventory" % item_id, "ItemPickup")
		return
	_interactable.enabled = false
	if persistent:
		Game.get_singleton().set_room_state(_room(), _state_key(), true)
	picked_up.emit(item_id, amount)
	var ui = ServiceLocatorHelper.get_manager("get_ui_manager")
	if ui:
		ui.show_modal(ModalTemplates.item_pickup(_item_database().get_item_name(item_id), amount))
	queue_free()


func _item_database() -> Node:
	return ServiceLocatorHelper.get_manager("get_item_database")


func _room() -> String:
	return get_node(^"/root/MetSys").map_data.get_room_from_scene_path(owner.scene_file_path, false)


func _state_key() -> String:
	return "picked_%s" % name
