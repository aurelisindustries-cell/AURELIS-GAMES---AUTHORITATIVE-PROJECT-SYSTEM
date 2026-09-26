extends AINode
class_name AIInverterFilter

func tick(delta: float) -> ExecutionSignal:
	var child := _child()
	if not child: return ExecutionSignal.FAILURE
	var result := child.tick(delta)
	if result == ExecutionSignal.SUCCES: return ExecutionSignal.FAILURE
	if result == ExecutionSignal.FAILURE: return ExecutionSignal.SUCCES
	return result

func _child() -> AINode:
	for node in get_children():
		if node is AINode: return node
	return null
