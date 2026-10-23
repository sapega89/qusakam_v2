extends Node2D

## Замкнений прохід усередині локації (D562): ґрати, ляда, двері. Відкривається ключем з інвентаря або прапорцем
## квесту, який ставить розмова з NPC; що саме — у Resources/Data/gates.json за [member gate_id].
## Закритий — Body тримає героя, «Open» біля Area: з ключем відмикає, без нього — репліка героя (locked_dialogue).
## Відкритий — Body і Sprite вимкнено. Ключова брама памʼятає себе в стані кімнати (opened_<імʼя вузла>, D152 → сейв);
## брама прапорця відкрита, доки стоїть прапорець (прапорці теж у сейві), і відчиняється одразу, щойно його поставили.

signal opened

const DATA_PATH := "res://SampleProject/Resources/Data/gates.json"
const OPEN_TIME := 0.35

@export var gate_id: String = ""

var is_open := false
var _gate: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite
@onready var _body: StaticBody2D = $Body
@onready var _interactable: InteractableComponent = $Area/Interactable


func _ready() -> void:
	var gates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)).gates
	assert(gates.has(gate_id), "LockedDoor: no gate '%s' in gates.json (%s)" % [gate_id, get_path()])
	_gate = gates[gate_id]
	assert(_gate.has("key") != _gate.has("flag"), "LockedDoor: gate '%s' needs exactly one of key / flag" % gate_id)
	var game := Game.get_singleton()
	if _gate.has("key"):
		if game.get_room_state(_room(), _state_key(), false):
			_set_open()
			return
	else:
		if game.get_quest_flag(_gate.flag):
			_set_open()
			return
		game.quest_flag_changed.connect(_on_quest_flag_changed)
	_interactable.interacted.connect(_on_interacted)


## Закрита брама з ключем у інвентарі відмикається; інакше герой каже, чого бракує.
func _on_interacted() -> void:
	if is_open:
		return
	var inventory: InventoryManager = ServiceLocator.get_inventory_manager()
	if _gate.has("key") and inventory.get_item_count(_gate.key) > 0:
		if _gate.get("consumes_key", false):
			inventory.remove_item(_gate.key, 1)
		Game.get_singleton().set_room_state(_room(), _state_key(), true)
		open()
		return
	ServiceLocator.get_dialogue_manager().start_dialogue("res://dialogue_quest/%s.dqd" % _gate.locked_dialogue)


func _on_quest_flag_changed(flag: String, value: Variant) -> void:
	if flag == _gate.flag and value and not is_open:
		open()


## Відчинити з анімацією (ґрати / ляда тануть).
func open() -> void:
	AudioManager.play(&"door")
	_set_open(false)
	var tween := create_tween()
	tween.tween_property(_sprite, ^"modulate:a", 0.0, OPEN_TIME)
	tween.tween_callback(func() -> void: _sprite.visible = false)
	opened.emit()


func _set_open(instant: bool = true) -> void:
	is_open = true
	_interactable.enabled = false
	_body.get_node(^"CollisionShape2D").set_deferred(&"disabled", true)
	if instant:
		_sprite.visible = false


func _room() -> String:
	return get_node(^"/root/MetSys").map_data.get_room_from_scene_path(owner.scene_file_path, false)


func _state_key() -> String:
	return "opened_%s" % name
