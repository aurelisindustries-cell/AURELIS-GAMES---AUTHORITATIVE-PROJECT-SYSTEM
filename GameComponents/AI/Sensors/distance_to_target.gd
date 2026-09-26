extends AINode
class_name AIDistanceToTargetSensor

@export var target_key: StringName = &"target"
@export var minimum_distance: float = 0.0
@export var maximum_distance: float = 64.0

func tick(_delta: float) -> ExecutionSignal:
	var target := memory_get(target_key) as Node2D
	if not is_instance_valid(target) or not ai_root.actor: return ExecutionSignal.FAILURE
	var distance := ai_root.actor.global_position.distance_to(target.global_position)
	memory_set(&"target_distance", distance)
	return ExecutionSignal.SUCCES if distance >= minimum_distance and distance <= maximum_distance else ExecutionSignal.FAILURE
