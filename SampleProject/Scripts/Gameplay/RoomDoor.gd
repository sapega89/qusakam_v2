class_name RoomDoor
extends Area2D

## Двері в іншу кімнату (BACKLOG 38): поруч — підказка "[E] Enter" (InteractableComponent, D74),
## interact переносить героя в кімнату [member target_room] на вузол [member arrival]
## (Game.teleport_to_room — як вихід із зали мера в лабораторію). Ходити крізь край кімнати не треба:
## клітинки кімнат на карті MetSys відділені стіною.
## Двері з головної дороги в бічну кімнату (D643) можуть бути зачинені брамою прапорця з gates.json
## ([member gate_id]): поки прапорця немає, E — репліка героя (locked_dialogue), а не перехід. Брама-ґрати
## (LockedDoor) тут не годиться: її тіло перегородило б саму дорогу. Так само двері можуть ховатися за брилою на
## задньому плані ([member cover]): поки її не розбито важким ударом, дверей не видно (жодної підказки).
## Кожен вихід освітлений (ExitLight у room_door.tscn): теплий м'який відсвіт на вході, як двері коридору замку в Tails of Iron.

const GATES_PATH := "res://SampleProject/Resources/Data/gates.json"

## Сцена кімнати MetSys, куди ведуть двері.
@export_file("*.tscn") var target_room: String
## Вузол у цільовій кімнаті, де стане герой (зазвичай зворотні двері).
@export var arrival: NodePath
## Брама з gates.json, лише з "flag": двері відчинені, поки стоїть прапорець. Порожньо — завжди відчинені.
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
		assert(gates.has(gate_id) and gates[gate_id].has("flag"), "RoomDoor: '%s' is not a flag gate in gates.json (%s)" % [gate_id, get_path()])
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


## Двері відчинені: брами немає або її прапорець стоїть.
func is_open() -> bool:
	return _gate.is_empty() or bool(Game.get_singleton().get_quest_flag(_gate.flag))


func _on_interacted() -> void:
	if not is_open():
		ServiceLocator.get_dialogue_manager().start_dialogue("res://dialogue_quest/%s.dqd" % _gate.locked_dialogue)
		return
	interactable.enabled = false
	if sets_flag != "":
		Game.get_singleton().set_quest_flag(sets_flag, true)
	# Стару кімнату (разом із цими дверима) звільняє сам teleport_to_room — не посеред обробки вводу.
	Game.get_singleton().teleport_to_room.call_deferred(target_room, arrival)
