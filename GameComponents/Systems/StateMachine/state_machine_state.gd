@icon("res://addons/at-icons/node/cog.svg")
extends Node
class_name State


var active: bool = false
var character: Node

func _process(delta: float) -> void:
	if active: update(delta)

func _physics_process(delta: float) -> void:
	if active: physics_update(delta)


func enter() -> void:
	pass

func exit() -> void:
	pass

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	pass
