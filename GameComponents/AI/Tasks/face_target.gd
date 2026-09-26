extends AINode
class_name AIFaceTargetTask

@export var target_key: StringName = &"target"

func tick(_delta: float) -> ExecutionSignal:
	var target := memory_get(target_key) as Node2D
	if not is_instance_valid(target) or not ai_root.character_controller: return ExecutionSignal.FAILURE
	ai_root.character_controller.face_direction("RIGHT" if target.global_position.x >= ai_root.actor.global_position.x else "LEFT")
	return ExecutionSignal.SUCCES
