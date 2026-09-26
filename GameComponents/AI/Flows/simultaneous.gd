extends AINode
class_name AISimultaneous

func tick(delta: float) -> ExecutionSignal:
	var any_active := false
	for child in get_children():
		if not child is AINode: continue
		var result := (child as AINode).tick(delta)
		if result == ExecutionSignal.FAILURE:
			reset(); return result
		if result == ExecutionSignal.ACTIVE: any_active = true
	if any_active: return ExecutionSignal.ACTIVE
	reset()
	return ExecutionSignal.SUCCES
