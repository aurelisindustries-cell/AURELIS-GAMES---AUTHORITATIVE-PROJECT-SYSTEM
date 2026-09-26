@icon("res://addons/at-icons/node2d/hand.svg")
extends Area2D
class_name InteractingComponent2D

signal interaction_requested(interaction_type: StringName)
signal interaction_sent(component: InteractionComponent2D, interaction_type: StringName)

@export var actor: Node2D


func _ready() -> void:
	if not actor:
		actor = get_parent() as Node2D


func request_interaction(interaction_type: StringName) -> void:
	interaction_requested.emit(interaction_type)
	var target := _find_closest_valid_component(interaction_type)
	if not target:
		return
	target.receive_interaction(actor, interaction_type)
	interaction_sent.emit(target, interaction_type)


func _find_closest_valid_component(interaction_type: StringName) -> InteractionComponent2D:
	var closest: InteractionComponent2D
	var closest_distance := INF
	var highest_priority := -2147483648
	for area in get_overlapping_areas():
		if not area is InteractionComponent2D:
			continue
		var component := area as InteractionComponent2D
		if not component.accepts(interaction_type):
			continue
		var distance := actor.global_position.distance_squared_to(component.global_position)
		if component.interaction_priority > highest_priority or (component.interaction_priority == highest_priority and distance < closest_distance):
			closest = component
			closest_distance = distance
			highest_priority = component.interaction_priority
	return closest
