extends AINode
class_name AIWaitTask

@export var duration: float = 1.0
var _remaining := -1.0

func tick(delta: float) -> ExecutionSignal:
	if _remaining < 0.0: _remaining = duration
	_remaining -= delta
	if _remaining > 0.0: return ExecutionSignal.ACTIVE
	_remaining = -1.0
	return ExecutionSignal.SUCCES

func reset() -> void:
	_remaining = -1.0
	super.reset()
