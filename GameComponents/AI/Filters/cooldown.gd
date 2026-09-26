extends AINode
class_name AICooldownFilter

@export var duration: float = 1.0
var _remaining := 0.0

func tick(delta: float) -> ExecutionSignal:
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining > 0.0: return ExecutionSignal.FAILURE
	var child := _child()
	if not child: return ExecutionSignal.FAILURE
	var result := child.tick(delta)
	if result == ExecutionSignal.SUCCES: _remaining = duration
	return result

func _child() -> AINode:
	for node in get_children():
		if node is AINode: return node
	return null
