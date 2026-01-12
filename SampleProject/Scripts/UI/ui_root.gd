extends Node
class_name UIRoot

@onready var ui_layer: CanvasLayer = $UILayer
@onready var state_root: Control = $UILayer/StateRoot
@onready var state_machine: FiniteStateMachine = $StateMachine
@onready var modal_layer: Node = $ModalLayer

func get_state_root() -> Control:
	return state_root

func get_state_machine() -> FiniteStateMachine:
	return state_machine

func get_modal_layer() -> Node:
	return modal_layer
