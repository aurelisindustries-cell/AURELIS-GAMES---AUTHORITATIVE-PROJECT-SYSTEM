extends AINode
class_name AIMoveToTargetTask

@export var target_key: StringName = &"target"
@export var stop_distance: float = 40.0
@export var speed_multiplier: float = 1.0

func tick(_delta: float) -> ExecutionSignal:
	var target := memory_get(target_key) as Node2D
	if not is_instance_valid(target) or not ai_root.character_controller: return ExecutionSignal.FAILURE
	var offset := target.global_position - ai_root.actor.global_position
	if absf(offset.x) <= stop_distance:
		ai_root.character_controller.navigation_input_update(Vector2.ZERO)
		return ExecutionSignal.SUCCES
	if not ai_root.character_controller.navigation_active:
		ai_root.character_controller.begin_navigation(speed_multiplier)
	ai_root.character_controller.navigation_input_update(Vector2(signf(offset.x), 0.0))
	memory_set(&"target_position", target.global_position)
	return ExecutionSignal.ACTIVE

func reset() -> void:
	if ai_root and ai_root.character_controller and ai_root.character_controller.navigation_active:
		ai_root.character_controller.end_navigation()
	super.reset()
