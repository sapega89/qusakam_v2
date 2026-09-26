extends Area2D
class_name ItemPickup

## Предмет у світі гри, який підбирають через підказку взаємодії (D71):
##   1. поруч — UI/Interaction/Prompt "Pick up";
##   2. interact — предмет іде в інвентар через InventoryManager;
##   3. модалка підтвердження UI/Modal/ItemPickup ("You obtained: …").
##
## Дані предмета — лише з ItemDatabase. Невідомий item_id вимикає підбір,
## нічого не вигадуючи.

signal picked_up(item_id: String, amount: int)

@export var item_id: String = ""
@export_range(1, 999) var amount: int = 1

@onready var _interactable: InteractableComponent = $Interactable
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	var db := _item_database()
	if db == null or db.get_item(item_id).is_empty():
		push_error("ItemPickup: unknown item_id '%s' at %s" % [item_id, get_path()])
		_interactable.enabled = false
		return
	_sprite.texture = db.get_item_icon(item_id)


func _on_interacted() -> void:
	var inventory = ServiceLocatorHelper.get_manager("get_inventory_manager")
	if inventory == null or not inventory.add_item(item_id, amount):
		DebugLogger.warning("ItemPickup: could not add '%s' to the inventory" % item_id, "ItemPickup")
		return
	_interactable.enabled = false
	picked_up.emit(item_id, amount)
	var ui = ServiceLocatorHelper.get_manager("get_ui_manager")
	if ui:
		ui.show_modal(ModalTemplates.item_pickup(_item_database().get_item_name(item_id), amount))
	queue_free()


func _item_database() -> Node:
	return ServiceLocatorHelper.get_manager("get_item_database")
