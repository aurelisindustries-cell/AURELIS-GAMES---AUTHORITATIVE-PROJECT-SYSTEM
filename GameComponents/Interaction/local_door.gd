@icon("res://addons/at-icons/node2d/door.svg")
extends Node2D
class_name LocalDoor

signal used(actor: Node2D, destination: LocalDoor)

@export var door_id: StringName
@export var target_door_id: StringName
@export var arrival_offset: Vector2 = Vector2.ZERO


func _enter_tree() -> void:
	add_to_group(&"local_doors")


func _on_interaction_received(actor: Node2D, interaction_type: StringName) -> void:
	if interaction_type != &"Up":
		return
	var destination := _find_destination()
	if not destination:
		push_warning("LocalDoor '%s' could not find destination ID '%s'." % [door_id, target_door_id])
		return
	var arrival_point := destination.get_node_or_null("ArrivalPoint") as Node2D
	actor.global_position = (arrival_point.global_position if arrival_point else destination.global_position) + destination.arrival_offset
	var character := actor as CharacterEntity
	if character:
		var controller := character.get_component(CharacterController) as CharacterController
		if controller:
			controller.velocity = Vector2.ZERO
			controller.input_direction = Vector2.ZERO
	used.emit(actor, destination)


func _find_destination() -> LocalDoor:
	var scene_root := get_tree().current_scene
	for node in get_tree().get_nodes_in_group(&"local_doors"):
		if node == self or not node is LocalDoor:
			continue
		var door := node as LocalDoor
		if scene_root and not scene_root.is_ancestor_of(door):
			continue
		if door.door_id == target_door_id:
			return door
	return null
