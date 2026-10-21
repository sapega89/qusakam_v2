class_name RoomDoor
extends Area2D

## Двері в іншу кімнату (BACKLOG 38): поруч — підказка "[E] Enter" (InteractableComponent, D74),
## interact переносить героя в кімнату [member target_room] на вузол [member arrival]
## (Game.teleport_to_room — як вихід із зали мера в лабораторію). Ходити крізь край кімнати не треба:
## клітинки кімнат на карті MetSys відділені стіною.

## Сцена кімнати MetSys, куди ведуть двері.
@export_file("*.tscn") var target_room: String
## Вузол у цільовій кімнаті, де стане герой (зазвичай зворотні двері).
@export var arrival: NodePath

@onready var interactable: InteractableComponent = $Interactable


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	interactable.enabled = false
	# Стару кімнату (разом із цими дверима) звільняє сам teleport_to_room — не посеред обробки вводу.
	Game.get_singleton().teleport_to_room.call_deferred(target_room, arrival)
