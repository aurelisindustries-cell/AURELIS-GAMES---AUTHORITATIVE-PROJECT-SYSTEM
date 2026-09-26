extends AINode
class_name AIFindTargetSensor

@export var target_group: StringName = &"player"
@export var maximum_distance: float = 500.0
@export var require_line_of_sight: bool = false
@export_flags_2d_physics var sight_collision_mask: int = 2
@export var target_key: StringName = &"target"

func tick(_delta: float) -> ExecutionSignal:
	if not ai_root or not ai_root.actor: return ExecutionSignal.FAILURE
	var nearest: Node2D
	var nearest_distance := maximum_distance * maximum_distance
	for node in get_tree().get_nodes_in_group(target_group):
		if not node is Node2D or node == ai_root.actor: continue
		var distance := ai_root.actor.global_position.distance_squared_to((node as Node2D).global_position)
		if distance <= nearest_distance and (not require_line_of_sight or _has_sight(node as Node2D)):
			nearest = node; nearest_distance = distance
	if not nearest:
		memory_set(target_key, null); return ExecutionSignal.FAILURE
	memory_set(target_key, nearest)
	memory_set(&"target_position", nearest.global_position)
	memory_set(&"target_distance", sqrt(nearest_distance))
	return ExecutionSignal.SUCCES

func _has_sight(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(ai_root.actor.global_position, target.global_position, sight_collision_mask)
	query.exclude = [ai_root.actor]
	var result := ai_root.actor.get_world_2d().direct_space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == target
