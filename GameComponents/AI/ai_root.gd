@icon("res://addons/at-icons/node2d/brain.svg")
extends Node
class_name AIRoot

signal tick_completed(result: AINode.ExecutionSignal)
signal task_requested(action: StringName, data: Variant)

@export var enabled: bool = true
@export var actor: CharacterEntity
@export var state_machine: StateMachine
@export var character_controller: CharacterController
@export var navigator: CharacterNavigator2D
@export var health: HealthComponent
@export var tick_in_physics: bool = true

var memory_bank: Dictionary = {}


func _ready() -> void:
	if not actor: actor = get_parent() as CharacterEntity
	if actor:
		if not state_machine: state_machine = actor.get_component(StateMachine) as StateMachine
		if not character_controller: character_controller = actor.get_component(CharacterController) as CharacterController
		if not navigator: navigator = actor.get_component(CharacterNavigator2D) as CharacterNavigator2D
		if not health: health = actor.get_component(HealthComponent) as HealthComponent
	memory_bank[&"actor"] = actor
	for child in get_children():
		if child is AINode: (child as AINode).setup(self)
	set_process(not tick_in_physics)
	set_physics_process(tick_in_physics)


func _process(delta: float) -> void:
	_run_tree(delta)


func _physics_process(delta: float) -> void:
	_run_tree(delta)


func _run_tree(delta: float) -> void:
	if not enabled: return
	for child in get_children():
		if child is AINode:
			tick_completed.emit((child as AINode).tick(delta))


func clear_memory() -> void:
	var stored_actor := actor
	memory_bank.clear()
	memory_bank[&"actor"] = stored_actor
