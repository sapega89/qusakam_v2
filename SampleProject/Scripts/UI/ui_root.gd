extends Node
class_name UIRoot

const UIStateMachine = preload("res://SampleProject/Scripts/UI/States/ui_state_machine.gd")

@onready var ui_layer: CanvasLayer = $UILayer
@onready var state_root: Control = $UILayer/StateRoot
@onready var state_machine: UIStateMachine = $StateMachine
@onready var modal_layer: Node = $ModalLayer

func get_state_root() -> Control:
	return state_root

func get_state_machine() -> UIStateMachine:
	return state_machine

func get_modal_layer() -> Node:
	return modal_layer
