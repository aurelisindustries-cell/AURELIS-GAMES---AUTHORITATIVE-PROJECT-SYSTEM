@icon("res://addons/at-icons/node2d/move.svg")
extends Node
class_name InputHandler2D

signal update_input(dir:Vector2)
signal interaction_pressed(interaction_type: StringName)
signal jump_requested
signal jump_released
signal dash_requested
signal slide_requested
signal aim_updated(direction: Vector2)
signal caster_requested(module_slot: int)
signal caster_released
signal dagger_requested(module_slot: int)
signal ability_requested
signal core_previous_requested
signal core_next_requested
signal core_wheel_opened(direction: int)
signal core_wheel_closed
signal overclock_requested
signal map_requested
signal menu_requested

@export var up_input: StringName = &"Up"
@export var down_input: StringName = &"Down"
@export var left_input: StringName = &"Left"
@export var right_input: StringName = &"Right"

@export var jump_input: StringName = &"Jump"
@export var dash_input: StringName = &"Dash"
@export var slide_input: StringName = &"Slide"
@export var aim_up_input: StringName = &"AimUp"
@export var aim_down_input: StringName = &"AimDown"
@export var aim_left_input: StringName = &"AimLeft"
@export var aim_right_input: StringName = &"AimRight"
@export var caster_input: StringName = &"ArcCaster"
@export var dagger_input: StringName = &"ArcDagger"
@export var ability_input: StringName = &"EvolvedAbility"
@export var core_previous_input: StringName = &"CorePrevious"
@export var core_next_input: StringName = &"CoreNext"
@export var overclock_modifier_input: StringName = &"OverclockModifier"
@export var overclock_input: StringName = &"Overclock"
@export var left_paddle_input: StringName = &"LeftPaddle"
@export var right_paddle_input: StringName = &"RightPaddle"
@export var map_input: StringName = &"Map"
@export var menu_input: StringName = &"Menu"
@export var core_wheel_hold_time: float = 0.25
@export var interaction_inputs: Array[StringName] = [&"Up", &"Down", &"Left", &"Right", &"Jump", &"Dash", &"Slide"]

var can_input: bool = true
var _waiting_for_interaction_release: bool = false
var _core_previous_held := 0.0
var _core_next_held := 0.0
var _core_wheel_direction := 0
var _overclock_chord_active := false

func _ready() -> void:
	Cuts.cutscene_ended.connect(unlock_input)
	Cuts.cutscene_started.connect(lock_input)


func _process(delta: float) -> void:
	if _waiting_for_interaction_release and not _is_any_interaction_pressed():
		_waiting_for_interaction_release = false
		can_input = true
	input(delta)
	
	
func input(delta: float = 0.0) -> void:
	if !can_input: return
	var input_dir: Vector2 = Input.get_vector(left_input,right_input,up_input,down_input)
	update_input.emit(input_dir)
	aim_updated.emit(Input.get_vector(aim_left_input, aim_right_input, aim_up_input, aim_down_input))
	
	for interaction_type in interaction_inputs:
		if _is_action_just_pressed(interaction_type):
			interaction_pressed.emit(interaction_type)
	if _is_action_just_pressed(jump_input): jump_requested.emit()
	if _is_action_just_released(jump_input): jump_released.emit()
	if _is_action_just_pressed(slide_input): slide_requested.emit()
	if _is_action_just_pressed(dash_input):
		if Input.is_action_pressed(down_input): slide_requested.emit()
		else: dash_requested.emit()
	if _is_action_just_pressed(caster_input): caster_requested.emit(_get_module_slot())
	if _is_action_just_released(caster_input): caster_released.emit()
	if _is_action_just_pressed(dagger_input): dagger_requested.emit(_get_module_slot())
	if _is_action_just_pressed(ability_input): ability_requested.emit()
	if _is_action_just_pressed(map_input): map_requested.emit()
	if _is_action_just_pressed(menu_input): menu_requested.emit()
	_update_core_inputs(delta)
	_update_overclock_input()


func _update_core_inputs(delta: float) -> void:
	if _is_action_pressed(core_previous_input):
		_core_previous_held += delta
		if _core_previous_held >= core_wheel_hold_time and _core_wheel_direction == 0:
			_core_wheel_direction = -1
			core_wheel_opened.emit(-1)
	elif _core_previous_held > 0.0:
		if _core_wheel_direction == -1: core_wheel_closed.emit()
		else: core_previous_requested.emit()
		_core_previous_held = 0.0
		_core_wheel_direction = 0
	if _is_action_pressed(core_next_input):
		_core_next_held += delta
		if _core_next_held >= core_wheel_hold_time and _core_wheel_direction == 0:
			_core_wheel_direction = 1
			core_wheel_opened.emit(1)
	elif _core_next_held > 0.0:
		if _core_wheel_direction == 1: core_wheel_closed.emit()
		else: core_next_requested.emit()
		_core_next_held = 0.0
		_core_wheel_direction = 0


func _update_overclock_input() -> void:
	var chord_pressed := _is_action_pressed(overclock_modifier_input) and _is_action_pressed(overclock_input)
	if chord_pressed and not _overclock_chord_active:
		overclock_requested.emit()
	_overclock_chord_active = chord_pressed


func _get_module_slot() -> int:
	if _is_action_pressed(left_paddle_input): return 1
	if _is_action_pressed(right_paddle_input): return 2
	return 0
	
func lock_input() -> void:
	can_input = false
	_waiting_for_interaction_release = false
	update_input.emit(Vector2(0,0))
	aim_updated.emit(Vector2.ZERO)
	_core_previous_held = 0.0
	_core_next_held = 0.0
	_core_wheel_direction = 0
	_overclock_chord_active = false

func unlock_input() -> void:
	_waiting_for_interaction_release = _is_any_interaction_pressed()
	can_input = not _waiting_for_interaction_release


func _is_any_interaction_pressed() -> bool:
	for interaction_type in interaction_inputs:
		if _is_action_pressed(interaction_type):
			return true
	return false


func _has_action(action: StringName) -> bool:
	return not action.is_empty() and InputMap.has_action(action)


func _is_action_pressed(action: StringName) -> bool:
	return _has_action(action) and Input.is_action_pressed(action)


func _is_action_just_pressed(action: StringName) -> bool:
	return _has_action(action) and Input.is_action_just_pressed(action)


func _is_action_just_released(action: StringName) -> bool:
	return _has_action(action) and Input.is_action_just_released(action)
