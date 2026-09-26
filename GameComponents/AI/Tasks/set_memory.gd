extends AINode
class_name AISetMemoryTask

@export var key: StringName
@export var value: Variant

func tick(_delta: float) -> ExecutionSignal:
	if key.is_empty(): return ExecutionSignal.FAILURE
	memory_set(key, value)
	return ExecutionSignal.SUCCES
