@icon("res://addons/at-icons/node2d/cursor.svg")
extends Area2D
class_name InteractionComponent2D

signal interaction_received(actor: Node2D, interaction_type: StringName)

@export var valid_interactions: Array[StringName] = []
@export var enabled: bool = true
@export var interaction_priority: int = 0


func accepts(interaction_type: StringName) -> bool:
	return enabled and interaction_type in valid_interactions


func receive_interaction(actor: Node2D, interaction_type: StringName) -> void:
	if accepts(interaction_type):
		interaction_received.emit(actor, interaction_type)
