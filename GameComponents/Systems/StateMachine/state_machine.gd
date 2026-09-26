@icon("res://addons/at-icons/node/head_with_gear.svg")
extends Node
class_name StateMachine

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: State

var current_state: State


func _ready() -> void:
	if not initial_state:
		for child in get_children():
			if child is State:
				initial_state = child
				break
	if not initial_state:
		push_error("StateMachine requires at least one State child.")
		return
	current_state = initial_state
	current_state.active = true
	current_state.enter()


func change_state(state_name: String) -> void:
	var next_state := find_child(state_name) as State
	if not next_state or next_state == current_state:
		return
	var previous := &""
	if current_state:
		previous = current_state.name
		current_state.exit()
		current_state.active = false
	current_state = next_state
	current_state.active = true
	current_state.enter()
	state_changed.emit(previous, current_state.name)
