@icon("res://addons/at-icons/node2d/vr_headset.svg")
extends Node2D
class_name CharacterController

signal movement_action(action: StringName, pitch_degree: StringName)
signal propulsor_step_earned
signal landed

@export var controlling: CharacterEntity
@export var character_visual: Node
@export var state_machine: StateMachine

@export_category("Ground Movement")
@export var move_speed: float = 240.0
@export var ground_acceleration: float = 1800.0
@export var ground_deceleration: float = 2200.0

@export_category("Air Movement")
@export var air_acceleration: float = 1200.0
@export var gravity: float = 1100.0
@export var fall_gravity: float = 1450.0
@export var terminal_velocity: float = 900.0
@export var jump_velocity: float = -420.0
@export var pogo_rebound_velocity: float = -420.0
@export_range(0.0, 1.0) var jump_release_multiplier: float = 0.5
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12

@export_category("Dash and Slide")
@export var dash_speed: float = 480.0
@export var dash_duration: float = 0.20
@export var slide_speed: float = 360.0
@export var slide_duration: float = 0.25
@export var sliding_collider_height: float = 28.0

@export_category("Walls and Ledges")
@export var wall_slide_speed: float = 80.0
@export var wall_slide_duration: float = 0.45
@export var wall_jump_push: float = 320.0
@export var wall_jump_velocity: float = -420.0
@export var ledge_vault_height: float = 56.0
@export var ledge_vault_forward: float = 24.0

@export_category("Ability Unlocks")
@export var has_slide: bool = true
@export var has_dash: bool = true
@export var has_air_dash: bool = true
@export var has_propulsor_step: bool = true
@export var has_double_jump: bool = true
@export var has_wall_slide: bool = true
@export var has_wall_jump: bool = true
@export var has_ledge_flow: bool = true

var input_direction := Vector2.ZERO
var true_input_direction := Vector2.ZERO
var velocity := Vector2.ZERO
var facing_direction := 1.0
var movement_speed_multiplier := 1.0
var navigation_active := false

var can_double_jump := true
var can_air_dash := true
var propulsor_jump_available := false
var jump_buffer_remaining := 0.0
var coyote_remaining := 0.0
var dash_requested := false
var slide_requested := false
var jump_cut_requested := false
var carrying_dash_momentum := false
var standing_collider_height := 0.0
var standing_collider_y := 0.0
var body_collision: CollisionShape2D
var was_on_floor := false


func _ready() -> void:
	if not controlling:
		controlling = get_parent() as CharacterEntity
	if not state_machine and controlling:
		state_machine = controlling.find_child("StateMachine", true, false) as StateMachine
	if controlling:
		body_collision = controlling.find_child("Collision", true, false) as CollisionShape2D
	if body_collision:
		standing_collider_height = _get_collider_height()
		standing_collider_y = body_collision.position.y
	setup_states()
	was_on_floor = controlling.is_on_floor() if controlling else false


func setup_states() -> void:
	if not state_machine:
		push_error("CharacterController requires a StateMachine.")
		return
	for state in state_machine.get_children():
		if state is State:
			(state as State).character = self


func _physics_process(delta: float) -> void:
	if not controlling or not state_machine:
		return
	jump_buffer_remaining = maxf(jump_buffer_remaining - delta, 0.0)
	controlling.velocity = velocity
	controlling.move_and_slide()
	velocity = controlling.velocity
	var on_floor_now := controlling.is_on_floor()
	coyote_remaining = coyote_time if on_floor_now else maxf(coyote_remaining - delta, 0.0)
	if on_floor_now:
		can_double_jump = true
		can_air_dash = true
		propulsor_jump_available = false
		carrying_dash_momentum = false
	if on_floor_now and not was_on_floor:
		landed.emit()
	was_on_floor = on_floor_now
	_update_visual_facing()


func input_update(direction: Vector2) -> void:
	if navigation_active:
		return
	input_direction = direction.normalized()
	true_input_direction = direction
	if absf(input_direction.x) > 0.01:
		facing_direction = signf(input_direction.x)


func request_jump() -> void:
	if not navigation_active:
		jump_cut_requested = false
		jump_buffer_remaining = jump_buffer_time


func release_jump() -> void:
	if not navigation_active:
		jump_cut_requested = true


func request_dash() -> void:
	if not navigation_active:
		dash_requested = true


func request_slide() -> void:
	if not navigation_active and controlling and controlling.is_on_floor():
		slide_requested = true


func consume_jump() -> bool:
	if jump_buffer_remaining <= 0.0:
		return false
	jump_buffer_remaining = 0.0
	return true


func consume_dash() -> bool:
	if not dash_requested:
		return false
	dash_requested = false
	slide_requested = false
	return true


func consume_slide() -> bool:
	if not slide_requested:
		return false
	slide_requested = false
	dash_requested = false
	return true


func start_ground_jump(state_jump_velocity: float = jump_velocity) -> void:
	velocity.y = state_jump_velocity
	coyote_remaining = 0.0
	emit_movement_action(&"ground_jump", &"1")


func try_air_jump(state_jump_velocity: float = jump_velocity) -> bool:
	if propulsor_jump_available:
		propulsor_jump_available = false
		velocity.y = state_jump_velocity
		emit_movement_action(&"propulsor_step", &"5")
		return true
	if has_double_jump and can_double_jump:
		can_double_jump = false
		velocity.y = state_jump_velocity
		emit_movement_action(&"double_jump", &"flat_2")
		return true
	return false


func register_airborne_dagger_hit() -> void:
	if has_propulsor_step and controlling and not controlling.is_on_floor():
		propulsor_jump_available = true
		propulsor_step_earned.emit()


func perform_downstab_rebound(rebound_velocity: float = 0.0) -> void:
	velocity.y = rebound_velocity if rebound_velocity < 0.0 else pogo_rebound_velocity
	propulsor_jump_available = false
	can_air_dash = true
	can_double_jump = true
	emit_movement_action(&"downstab_rebound", &"flat_6")
	state_machine.change_state("Airborne")


func emit_movement_action(action: StringName, pitch_degree: StringName) -> void:
	movement_action.emit(action, pitch_degree)


func set_slide_collider(sliding: bool, target_height: float = sliding_collider_height) -> void:
	if not body_collision or not body_collision.shape:
		return
	if sliding:
		var requested_height := minf(target_height, standing_collider_height)
		if body_collision.shape is RectangleShape2D:
			(body_collision.shape as RectangleShape2D).size.y = requested_height
		elif body_collision.shape is CapsuleShape2D:
			var capsule := body_collision.shape as CapsuleShape2D
			capsule.height = maxf(requested_height, capsule.radius * 2.0)
		else:
			return
		var difference := standing_collider_height - _get_collider_height()
		body_collision.position.y = standing_collider_y + difference * 0.5
	else:
		if body_collision.shape is RectangleShape2D:
			(body_collision.shape as RectangleShape2D).size.y = standing_collider_height
		elif body_collision.shape is CapsuleShape2D:
			(body_collision.shape as CapsuleShape2D).height = standing_collider_height
		body_collision.position.y = standing_collider_y


func can_stand() -> bool:
	if not controlling or not body_collision or not body_collision.shape:
		return true
	var current_height := _get_collider_height()
	if standing_collider_height <= current_height:
		return true
	var extra_height := standing_collider_height - current_height
	return not controlling.test_move(controlling.global_transform, Vector2.UP * extra_height)


func is_pressing_toward_wall() -> bool:
	if not controlling or not controlling.is_on_wall():
		return false
	return input_direction.x * controlling.get_wall_normal().x < 0.0


func is_pressing_away_from_wall() -> bool:
	if not controlling or not controlling.is_on_wall() or absf(true_input_direction.x) < 0.2:
		return false
	return true_input_direction.x * controlling.get_wall_normal().x > 0.0


func perform_wall_jump(push: float = wall_jump_push, upward_velocity: float = wall_jump_velocity) -> bool:
	if not has_wall_jump or not controlling or not controlling.is_on_wall():
		return false
	var wall_normal := controlling.get_wall_normal()
	velocity = Vector2(wall_normal.x * push, upward_velocity)
	facing_direction = wall_normal.x
	can_air_dash = true
	can_double_jump = true
	jump_buffer_remaining = 0.0
	emit_movement_action(&"wall_jump", &"3")
	return true


func can_catch_ledge() -> bool:
	if not has_ledge_flow or velocity.y < 0.0:
		return false
	if controlling.is_on_wall():
		var wall_normal := controlling.get_wall_normal()
		if not is_zero_approx(wall_normal.x):
			facing_direction = -wall_normal.x
	var wall_ray := controlling.find_child("WallRay", true, false) as RayCast2D
	var clearance_ray := controlling.find_child("ClearanceRay", true, false) as RayCast2D
	if not wall_ray or not clearance_ray:
		return false
	wall_ray.target_position.x = absf(wall_ray.target_position.x) * facing_direction
	clearance_ray.target_position.x = absf(clearance_ray.target_position.x) * facing_direction
	wall_ray.force_raycast_update()
	clearance_ray.force_raycast_update()
	return wall_ray.is_colliding() and not clearance_ray.is_colliding()


func _get_collider_height() -> float:
	if not body_collision or not body_collision.shape:
		return 0.0
	if body_collision.shape is RectangleShape2D:
		return (body_collision.shape as RectangleShape2D).size.y
	if body_collision.shape is CapsuleShape2D:
		return (body_collision.shape as CapsuleShape2D).height
	return 0.0


func vault_ledge() -> void:
	controlling.global_position += Vector2(facing_direction * ledge_vault_forward, -ledge_vault_height)
	velocity = Vector2(facing_direction * move_speed, 0.0)


func snap_to_ledge_wall() -> void:
	var wall_ray := controlling.find_child("WallRay", true, false) as RayCast2D
	if not wall_ray or not wall_ray.is_colliding():
		return
	var half_width := controlling.get_navigation_radius()
	controlling.global_position.x = wall_ray.get_collision_point().x - facing_direction * (half_width + 0.5)


func begin_navigation(speed_multiplier: float = 1.0) -> void:
	navigation_active = true
	movement_speed_multiplier = maxf(speed_multiplier, 0.01)
	input_direction = Vector2.ZERO


func navigation_input_update(direction: Vector2) -> void:
	if not navigation_active:
		return
	input_direction = direction.normalized()
	true_input_direction = direction
	if absf(input_direction.x) > 0.01:
		facing_direction = signf(input_direction.x)


func get_navigation_speed() -> float:
	var walk_state := state_machine.find_child("Walk") if state_machine else null
	var navigation_speed := float(walk_state.get("speed")) if walk_state is State else move_speed
	return navigation_speed * movement_speed_multiplier


func end_navigation() -> void:
	navigation_active = false
	movement_speed_multiplier = 1.0
	input_direction = Vector2.ZERO
	velocity = Vector2.ZERO


func face_direction(direction: String) -> void:
	match direction.to_upper():
		"LEFT": facing_direction = -1.0
		"RIGHT": facing_direction = 1.0
	_update_visual_facing()


func _update_visual_facing() -> void:
	if not character_visual:
		return
	if character_visual is Node2D:
		(character_visual as Node2D).scale.x = absf((character_visual as Node2D).scale.x) * facing_direction
	elif character_visual is Node3D:
		(character_visual as Node3D).rotation.y = 0.0 if facing_direction > 0.0 else PI
