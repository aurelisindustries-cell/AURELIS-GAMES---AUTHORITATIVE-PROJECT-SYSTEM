extends AINode
class_name AIMemoryExistsSensor

@export var key: StringName = &"target"

func tick(_delta: float) -> ExecutionSignal:
	var value := memory_get(key)
	return ExecutionSignal.SUCCES if value != null and (not value is Object or is_instance_valid(value)) else ExecutionSignal.FAILURE
