extends AINode
class_name AIStepSequence

var _index := 0

func tick(delta: float) -> ExecutionSignal:
	var nodes := _children()
	while _index < nodes.size():
		var result := nodes[_index].tick(delta)
		if result == ExecutionSignal.ACTIVE: return result
		if result == ExecutionSignal.FAILURE:
			reset(); return result
		_index += 1
	reset()
	return ExecutionSignal.SUCCES

func reset() -> void:
	_index = 0
	super.reset()

func _children() -> Array[AINode]:
	var result: Array[AINode] = []
	for child in get_children():
		if child is AINode: result.append(child)
	return result
