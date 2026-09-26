extends AINode
class_name AIHealthBelowSensor

@export_range(0.0, 1.0) var threshold: float = 0.25

func tick(_delta: float) -> ExecutionSignal:
	if not ai_root.health or ai_root.health.max_health <= 0: return ExecutionSignal.FAILURE
	return ExecutionSignal.SUCCES if float(ai_root.health.current_health) / ai_root.health.max_health <= threshold else ExecutionSignal.FAILURE
