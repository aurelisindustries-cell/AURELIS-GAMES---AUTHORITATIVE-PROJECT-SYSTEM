@icon("res://addons/at-icons/node2d/map.svg")
extends Node2D
class_name CharacterNavigator2D

signal navigation_finished
signal navigation_failed(reason: String)
signal navigation_cancelled

@export_range(0.5, 128.0, 0.5, "or_greater") var arrival_distance: float = 4.0
@export_range(0.1, 30.0, 0.1, "or_greater") var stuck_timeout: float = 3.0
@export_range(0.1, 60.0, 0.1, "or_greater") var maximum_duration: float = 20.0

var character: CharacterEntity
var controller: CharacterController
var navigation_agent: NavigationAgent2D

var _requested_target: Vector2
var _target_position: Vector2
var _speed_multiplier := 1.0
var _final_facing := ""
var _active := false
var _elapsed := 0.0
var _stuck_elapsed := 0.0
var _last_position := Vector2.ZERO
var _desired_direction := Vector2.ZERO
var _target_refresh_elapsed := 0.0


func setup(owner_character: CharacterEntity, character_controller: CharacterController) -> void:
	character = owner_character
	controller = character_controller
	_ensure_agent()


func navigate_to(target: Vector2, speed_multiplier := 1.0, final_facing := "") -> void:
	if not is_instance_valid(character) or not is_instance_valid(controller):
		_fail("CharacterNavigator2D requires a Character and CharacterController.")
		return

	_ensure_agent()
	_requested_target = target
	_target_position = target
	_speed_multiplier = maxf(speed_multiplier, 0.01)
	_final_facing = final_facing
	_elapsed = 0.0
	_stuck_elapsed = 0.0
	_target_refresh_elapsed = 0.0
	_last_position = character.global_position
	_desired_direction = Vector2.ZERO
	controller.begin_navigation(_speed_multiplier)
	character.set_navigation_obstacle_enabled(false)
	navigation_agent.max_speed = controller.get_navigation_speed()
	_active = true

	await get_tree().physics_frame
	if not is_inside_tree() or not _active:
		return
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) == 0:
		_fail("No synchronized NavigationRegion2D is available for this character.")
		return

	_target_position = _resolve_unoccupied_target(_requested_target)
	navigation_agent.target_position = _target_position
	await get_tree().physics_frame
	if not _active:
		return
	if not navigation_agent.is_target_reachable():
		_fail("The requested cutscene movement target is unreachable.")
		return


func cancel_navigation() -> void:
	if not _active:
		return
	_active = false
	_finish_controller_movement()
	navigation_cancelled.emit()


func _physics_process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	_target_refresh_elapsed += delta
	if _elapsed >= maximum_duration:
		_fail("Cutscene navigation exceeded its maximum duration.")
		return
	if _target_refresh_elapsed >= 0.2:
		_target_refresh_elapsed = 0.0
		var adjusted_target := _resolve_unoccupied_target(_requested_target)
		if adjusted_target.distance_squared_to(_target_position) > 1.0:
			_target_position = adjusted_target
			navigation_agent.target_position = _target_position

	if navigation_agent.is_navigation_finished() or character.global_position.distance_to(_target_position) <= arrival_distance:
		_complete()
		return

	var next_position := navigation_agent.get_next_path_position()
	_desired_direction = character.global_position.direction_to(next_position)
	navigation_agent.velocity = _desired_direction * controller.get_navigation_speed()

	if character.global_position.distance_to(_last_position) <= 0.05:
		_stuck_elapsed += delta
		if _stuck_elapsed >= stuck_timeout:
			_fail("Character became stuck while following the navigation path.")
			return
	else:
		_stuck_elapsed = 0.0
		_last_position = character.global_position


func _ensure_agent() -> void:
	if is_instance_valid(navigation_agent):
		return
	navigation_agent = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if not navigation_agent:
		navigation_agent = NavigationAgent2D.new()
		navigation_agent.name = "NavigationAgent2D"
		add_child(navigation_agent)
	navigation_agent.path_desired_distance = arrival_distance
	navigation_agent.target_desired_distance = arrival_distance
	navigation_agent.radius = character.get_navigation_radius() + 1.0 if is_instance_valid(character) else 7.0
	navigation_agent.neighbor_distance = 96.0
	navigation_agent.max_neighbors = 16
	navigation_agent.time_horizon_agents = 1.0
	navigation_agent.time_horizon_obstacles = 0.75
	navigation_agent.avoidance_enabled = true
	if not navigation_agent.velocity_computed.is_connected(_on_velocity_computed):
		navigation_agent.velocity_computed.connect(_on_velocity_computed)


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if not _active or not is_instance_valid(controller):
		return
	var safe_direction := safe_velocity.normalized()
	controller.navigation_input_update(safe_direction)


func _resolve_unoccupied_target(requested_target: Vector2) -> Vector2:
	if not is_instance_valid(character):
		return requested_target

	var resolved_target := requested_target
	var own_radius: float = character.get_navigation_radius()
	for other in get_tree().get_nodes_in_group("characters"):
		if other == character or not other is CharacterEntity:
			continue
		var other_character := other as CharacterEntity
		var clearance: float = own_radius + other_character.get_navigation_radius() + 2.0
		if other_character.global_position.distance_to(requested_target) >= clearance:
			continue

		var away_direction: Vector2 = other_character.global_position.direction_to(character.global_position)
		if away_direction == Vector2.ZERO:
			away_direction = Vector2.DOWN
		resolved_target = other_character.global_position + away_direction * clearance
		break

	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid() and NavigationServer2D.map_get_iteration_id(navigation_map) > 0:
		resolved_target = NavigationServer2D.map_get_closest_point(navigation_map, resolved_target)
	return resolved_target


func _complete() -> void:
	_active = false
	_finish_controller_movement()
	navigation_finished.emit()


func _fail(reason: String) -> void:
	_active = false
	_finish_controller_movement()
	navigation_failed.emit(reason)


func _finish_controller_movement() -> void:
	if is_instance_valid(navigation_agent):
		navigation_agent.velocity = Vector2.ZERO
	if is_instance_valid(character):
		character.set_navigation_obstacle_enabled(true)
	if not is_instance_valid(controller):
		return
	controller.end_navigation()
	controller.face_direction(_final_facing)
