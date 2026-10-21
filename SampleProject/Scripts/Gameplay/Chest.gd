extends Area2D
class_name Chest

## Скриня у світі гри (BACKLOG 33, D88 шлях 3, chests_plan):
##   1. поруч — UI/Interaction/Prompt "Open"; interact (E / геймпад) відкриває;
##   2. вміст одразу йде в інвентар (D88: "adds its contents automatically");
##   3. кришка: Closed → Opening (3 кадри) → Open;
##   4. Kusakam стоїть у позі HERO_POSE, знайдений предмет — над ним (Found);
##   5. модалка "You obtained:" — та сама, що в ItemPickup.
## Відкрита скриня лишається відкритою: стан кімнати (D152) пам'ятає "opened_<імʼя вузла>", як ItemPickup (D298),
## і він їде в сейв (FlagsModule.room_state).

signal opened(contents: Dictionary)

## Поза героя, поки предмет над головою. Кадрів Raise (SampleProject/Sprites/Player/Raise/, арт A1 «hero_raise»)
## ще нема в репо — коли ляжуть: анімація "Raise" у Player.tscn і тут &"Raise". Більше нічого міняти не треба.
const HERO_POSE := &"Idle"
## Скільки предмет висить над героєм, перш ніж відкриється модалка.
const RAISE_SECONDS := 1.2

## item_id → кількість. Лише предмети з ItemDatabase; невідомий id вимикає скриню, нічого не вигадуючи.
@export var contents: Dictionary[String, int] = {}
## Скриня, поставлена в кімнату, відкривається один раз. false — поза кімнатою (тести).
@export var persistent: bool = true

var is_open := false
## Де предмет над героєм — позиція Found у сцені (Found top_level, тож позицію беремо раз).
var _found_offset := Vector2.ZERO

@onready var _interactable: InteractableComponent = $Interactable
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _found: Sprite2D = $Found


func _ready() -> void:
	_found_offset = _found.position
	_found.visible = false
	if persistent and Game.get_singleton().get_room_state(_room(), _state_key(), false):
		_show_open()
		return
	_sprite.play(&"closed")
	var db := _item_database()
	if contents.is_empty():
		push_error("Chest: no contents at %s" % get_path())
		_interactable.enabled = false
		return
	for item_id: String in contents:
		if db == null or db.get_item(item_id).is_empty():
			push_error("Chest: unknown item_id '%s' at %s" % [item_id, get_path()])
			_interactable.enabled = false
			return
	_interactable.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	if is_open:
		return
	var inventory = ServiceLocatorHelper.get_manager("get_inventory_manager")
	for item_id: String in contents:
		if inventory == null or not inventory.add_item(item_id, contents[item_id]):
			DebugLogger.warning("Chest: could not add '%s' to the inventory" % item_id, "Chest")
			return
	is_open = true
	_interactable.enabled = false
	if persistent:
		Game.get_singleton().set_room_state(_room(), _state_key(), true)
	opened.emit(contents)
	await _play_opening()


func _play_opening() -> void:
	_sprite.play(&"opening")
	await _sprite.animation_finished
	_sprite.play(&"open")
	var player := Game.get_singleton().player
	player.set_movement_enabled(false)
	player.get_node(^"AnimationPlayer").play(HERO_POSE)
	_found.texture = _item_database().get_item_icon(contents.keys()[0])
	_found.global_position = player.global_position + _found_offset
	_found.visible = true
	await get_tree().create_timer(RAISE_SECONDS).timeout
	_found.visible = false
	player.set_movement_enabled(true)
	var ui = ServiceLocatorHelper.get_manager("get_ui_manager")
	if ui:
		var db := _item_database()
		var lines: Array[String] = []
		for item_id: String in contents:
			lines.append("%s × %d" % [db.get_item_name(item_id), contents[item_id]])
		ui.show_modal(ModalTemplates.items_obtained(lines))


func _show_open() -> void:
	is_open = true
	_interactable.enabled = false
	_sprite.play(&"open")


func _item_database() -> Node:
	return ServiceLocatorHelper.get_manager("get_item_database")


func _room() -> String:
	return get_node(^"/root/MetSys").map_data.get_room_from_scene_path(owner.scene_file_path, false)


func _state_key() -> String:
	return "opened_%s" % name
