@icon("res://addons/at-icons/node2d/brain.svg")
extends Node
class_name AINode

enum ExecutionSignal { SUCCES, FAILURE, ACTIVE }

var ai_root: AIRoot


func setup(root: AIRoot) -> void:
	ai_root = root
	for child in get_children():
		if child is AINode:
			(child as AINode).setup(root)


func tick(_delta: float) -> ExecutionSignal:
	return ExecutionSignal.FAILURE


func reset() -> void:
	for child in get_children():
		if child is AINode:
			(child as AINode).reset()


func memory_get(key: StringName, default_value: Variant = null) -> Variant:
	return ai_root.memory_bank.get(key, default_value) if ai_root else default_value


func memory_set(key: StringName, value: Variant) -> void:
	if ai_root:
		ai_root.memory_bank[key] = value
