extends Node2D

## Будинок мера: після розмови з мером гравця переносить у Лабораторію
## (Sapega, 2026-10-12). Лабораторія лежить на окремому шарі MetSys і не має
## проходів у місто, тож дороги назад немає — так задумано.

const MAYOR_DIALOGUE := "City_MayorHall"
const LAB_ROOM := "res://SampleProject/Maps/Laboratory.tscn"


func _ready() -> void:
	EventBus.dialogue_finished.connect(_on_dialogue_finished)


func _on_dialogue_finished(dialogue_id: String) -> void:
	if dialogue_id.get_file().get_basename() != MAYOR_DIALOGUE:
		return
	var game := Game.get_singleton()
	game.set_quest_flag("city_mayor_hall_complete", true)
	game.teleport_to_room(LAB_ROOM, ^"SavePoint_Entrance")
