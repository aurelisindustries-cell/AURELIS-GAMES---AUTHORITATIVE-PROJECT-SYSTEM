extends AINode
class_name AIRequestActionTask

@export var action: StringName = &"attack"
@export var data_key: StringName

func tick(_delta: float) -> ExecutionSignal:
	if not ai_root: return ExecutionSignal.FAILURE
	var data: Variant = memory_get(data_key) if not data_key.is_empty() else null
	ai_root.task_requested.emit(action, data)
	return ExecutionSignal.SUCCES
