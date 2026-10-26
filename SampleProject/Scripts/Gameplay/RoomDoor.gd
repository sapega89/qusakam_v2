class_name RoomDoor
extends Area2D

## Двері в іншу кімнату (BACKLOG 38): поруч — підказка "[E] Enter" (InteractableComponent, D74),
## interact переносить героя в кімнату [member target_room] на вузол [member arrival]
## (Game.teleport_to_room — як вихід із зали мера в лабораторію). Ходити крізь край кімнати не треба:
## клітинки кімнат на карті MetSys відділені стіною.
## Двері з головної дороги в бічну кімнату (D643) можуть бути зачинені брамою з gates.json ([member gate_id]):
## прапорцем — відчинені, поки він стоїть; ключем (D723) — E з ключем у торбі відмикає їх назавжди (стан кімнати
## opened_<імʼя вузла>, у сейві), як LockedDoor. Поки зачинено, E — репліка героя (locked_dialogue), а не перехід.
## Ключові двері, за якими герой уже бував (його клітинки MetSys досліджено: сейв, зроблений до того, як двері
## замкнули), відчинені — старий сейв не замикає героя. Брама-ґрати (LockedDoor) тут не годиться: її тіло
## перегородило б саму дорогу. Так само двері можуть ховатися за брилою на
## задньому плані ([member cover]): поки її не розбито важким ударом, дверей не видно (жодної підказки).
## Кожен вихід освітлений (ExitLight у room_door.tscn): теплий м'який відсвіт на вході, як двері коридору замку в Tails of Iron.

const GATES_PATH := "res://SampleProject/Resources/Data/gates.json"
const LockedDoor := preload("res://SampleProject/Scripts/Gameplay/LockedDoor.gd")

## Сцена кімнати MetSys, куди ведуть двері.
@export_file("*.tscn") var target_room: String
## Вузол у цільовій кімнаті, де стане герой (зазвичай зворотні двері).
@export var arrival: NodePath
## Брама з gates.json: "flag" — двері відчинені, поки стоїть прапорець; "key" — відмикаються ключем (D723).
## Порожньо — завжди відчинені.
@export var gate_id: String = ""
## Прапорець квесту, який ставить перехід крізь ці двері (зсередини відчинити шорткат, D643). Порожньо — нічого.
@export var sets_flag: String = ""
## Брила (BreakableWall) на задньому плані, що закриває двері. Порожньо — нічого не закриває.
@export var cover: NodePath

@onready var interactable: InteractableComponent = $Interactable
@onready var exit_light: Sprite2D = $ExitLight

var _gate: Dictionary = {}


func _ready() -> void:
	if gate_id != "":
		var gates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATES_PATH)).gates
		assert(gates.has(gate_id), "RoomDoor: no gate '%s' in gates.json (%s)" % [gate_id, get_path()])
		_gate = gates[gate_id]
	if not cover.is_empty():
		var wall: Node = get_node(cover)
		if not wall.was_broken():
			interactable.enabled = false
			exit_light.hide()
			wall.broken.connect(func() -> void:
				interactable.enabled = true
				exit_light.show())
	interactable.interacted.connect(_on_interacted)


## Двері відчинені: брами немає, її прапорець стоїть, або ключову браму відімкнено чи за нею вже бували.
func is_open() -> bool:
	return gate_id == "" or not locked(gate_id, _room(), name, target_room)


## Чи двері з брамою [param gate] вузла [param node_name] у кімнаті [param room] (ключ стану кімнати MetSys), що
## ведуть у [param target], ще зачинені — без сцени: карта World Map питає це для кімнат, де героя немає.
static func locked(gate: String, room: String, node_name: String, target: String) -> bool:
	if not LockedDoor.is_locked(gate, room, node_name):
		return false
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATES_PATH)).gates[gate]
	if not spec.has("key"):
		return true
	return not MetSys.map_data.get_cells_assigned_to_path(target).any(
			func(c: Vector3i) -> bool: return MetSys.is_cell_discovered(c, false))


func _on_interacted() -> void:
	if not is_open():
		var inventory: InventoryManager = ServiceLocator.get_inventory_manager()
		if not _gate.has("key") or inventory.get_item_count(_gate.key) == 0:
			ServiceLocator.get_dialogue_manager().start_dialogue("res://dialogue_quest/%s.dqd" % _gate.locked_dialogue)
			return
		if _gate.get("consumes_key", false):
			inventory.remove_item(_gate.key, 1)
		Game.get_singleton().set_room_state(_room(), "opened_%s" % name, true)
		AudioManager.play(&"door")
	interactable.enabled = false
	if sets_flag != "":
		Game.get_singleton().set_quest_flag(sets_flag, true)
	# Стару кімнату (разом із цими дверима) звільняє сам teleport_to_room — не посеред обробки вводу.
	Game.get_singleton().teleport_to_room.call_deferred(target_room, arrival)


func _room() -> String:
	return MetSys.map_data.get_room_from_scene_path(owner.scene_file_path, false)
