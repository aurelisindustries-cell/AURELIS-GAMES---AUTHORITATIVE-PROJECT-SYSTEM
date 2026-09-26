extends AINode
class_name AIRepeatFilter

@export var repeat_count: int = -1
var _completed := 0

func tick(delta: float) -> ExecutionSignal:
	var child := _child()
	if not child: return ExecutionSignal.FAILURE
	var result := child.tick(delta)
	if result == ExecutionSignal.ACTIVE: return result
	if result == ExecutionSignal.FAILURE: return result
	_completed += 1
	child.reset()
	if repeat_count < 0 or _completed < repeat_count: return ExecutionSignal.ACTIVE
	_completed = 0
	return ExecutionSignal.SUCCES

func reset() -> void:
	_completed = 0
	super.reset()

func _child() -> AINode:
	for node in get_children():
		if node is AINode: return node
	return null
