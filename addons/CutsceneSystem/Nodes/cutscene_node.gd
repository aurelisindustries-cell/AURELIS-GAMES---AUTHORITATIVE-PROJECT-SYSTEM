@icon("res://addons/CutsceneSystem/icons/cutscene_node.png")
extends Node2D
class_name CutsceneNode

signal action_done

@export var wait_to_finish: bool = true
@export var wait_time: float = 0

func do_action() -> void:
	action_done.emit()
