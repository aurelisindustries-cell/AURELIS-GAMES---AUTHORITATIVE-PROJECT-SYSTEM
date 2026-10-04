extends "res://GameComponents/AI/ai_node.gd"
class_name AIPatrolBetweenPointsTask

@export var point_a: Node2D
@export var point_b: Node2D
@export var arrival_distance: float = 10.0
@export var pause_at_point: float = 0.35
@export var speed_multiplier: float = 1.0
@export var start_at_point_b: bool = false
@export var use_vertical_movement: bool = false

var _target_index := 0
var _pause_remaining := 0.0


func setup(root) -> void:
	super.setup(root)
	# Authored instance settings survive packing without modifying the enemy scene.
	if ai_root and ai_root.actor and ai_root.actor.has_meta("editor_patrol"):
		var settings: Dictionary = ai_root.actor.get_meta("editor_patrol")
		for key in ["point_a", "point_b"]:
			var point: Node2D = point_a if key == "point_a" else point_b
			if point and settings.has(key):
				point.top_level = false
				point.position = settings[key]
		pause_at_point = float(settings.get("pause", pause_at_point))
		speed_multiplier = float(settings.get("speed", speed_multiplier))
		start_at_point_b = bool(settings.get("start_b", start_at_point_b))
	_target_index = 1 if start_at_point_b else 0
	_detach_point_from_actor(point_a)
	_detach_point_from_actor(point_b)


func tick(delta: float) -> ExecutionSignal:
	var destination := _current_point()
	if not is_instance_valid(destination) or not ai_root or not ai_root.actor or not ai_root.character_controller:
		_stop_moving()
		return ExecutionSignal.FAILURE
	memory_set(&"navigation_point", destination)
	memory_set(&"target_position", destination.global_position)
	var offset := destination.global_position - ai_root.actor.global_position
	var distance := offset.length() if use_vertical_movement else absf(offset.x)
	var point_radius := float(destination.get("radius")) if destination.get("radius") != null else 0.0
	if distance <= maxf(arrival_distance, point_radius):
		_stop_moving()
		_pause_remaining += delta
		if _pause_remaining >= pause_at_point:
			_pause_remaining = 0.0
			_target_index = 1 - _target_index
		return ExecutionSignal.ACTIVE
	_pause_remaining = 0.0
	if not ai_root.character_controller.navigation_active:
		ai_root.character_controller.begin_navigation(speed_multiplier)
	var direction := offset.normalized() if use_vertical_movement else Vector2(signf(offset.x), 0.0)
	ai_root.character_controller.navigation_input_update(direction)
	return ExecutionSignal.ACTIVE


func reset() -> void:
	_stop_moving()
	_pause_remaining = 0.0
	super.reset()


func _current_point() -> Node2D:
	return point_b if _target_index == 1 else point_a


func _stop_moving() -> void:
	if ai_root and ai_root.character_controller and ai_root.character_controller.navigation_active:
		ai_root.character_controller.end_navigation()


func _detach_point_from_actor(point: Node2D) -> void:
	if point and ai_root and ai_root.actor and ai_root.actor.is_ancestor_of(point):
		var world_transform := point.global_transform
		point.top_level = true
		point.global_transform = world_transform
