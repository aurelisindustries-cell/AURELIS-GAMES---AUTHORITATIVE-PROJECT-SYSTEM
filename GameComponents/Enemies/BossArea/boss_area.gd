@icon("res://addons/at-icons/node2d/shield.svg")
extends Node2D
class_name BossArea

signal encounter_started
signal encounter_completed

@export var boss: CharacterBody2D
@export var trigger: Area2D
@export var gates: Array[BossArenaGate] = []
@export var activate_once: bool = true
@export var close_gates_on_entry: bool = true
@export var boss_display_name: String = "BOSS"
@export_category("Arena Camera")
@export var control_camera: bool = true
@export var camera_zoom_multiplier: float = 1.08
@export var camera_transition_time: float = 0.35
@export var use_trigger_as_camera_bounds: bool = true
@export var camera_bounds := Rect2(-300.0, -180.0, 600.0, 360.0)
@export var camera_bound_padding := Vector2(220.0, 90.0)
@export_range(0.1, 20.0, 0.1) var camera_follow_speed: float = 3.0
@export var camera_follow_distance := Vector2(105.0, 55.0)

var active := false
var completed := false
var _boss_ai: Node
var _camera: Camera2D
var _camera_zoom_source: Node
var _camera_original_zoom := Vector2.ONE
var _camera_original_limits := Rect2i()
var _camera_original_horizontal_drag := false
var _camera_original_vertical_drag := false
var _camera_original_margins := Vector4.ZERO
var _camera_original_smoothing := false
var _camera_original_smoothing_speed := 5.0
var _camera_original_top_level := false
var _camera_original_local_position := Vector2.ZERO
var _arena_player: Node2D
var _active_camera_bounds := Rect2()


func _ready() -> void:
	set_process(false)
	if trigger: trigger.body_entered.connect(_on_body_entered)
	if boss:
		_boss_ai = boss.get_node_or_null("AI")
		if _boss_ai: _boss_ai.process_mode = Node.PROCESS_MODE_DISABLED
		var health := boss.find_child("HealthComponent", true, false) as HealthComponent
		if health: health.died.connect(_on_boss_died)
	_set_gates(false)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player") or active or (completed and activate_once): return
	active = true
	_arena_player = body
	if _boss_ai: _boss_ai.process_mode = Node.PROCESS_MODE_INHERIT
	if close_gates_on_entry: _set_gates(true)
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui and gui.has_method("show_boss"): gui.show_boss(boss, boss_display_name)
	if control_camera: _enter_arena_camera()
	encounter_started.emit()


func _on_boss_died(_hit: HitData) -> void:
	active = false
	set_process(false)
	completed = true
	_set_gates(false)
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui and gui.has_method("hide_boss"): gui.hide_boss()
	if control_camera: _leave_arena_camera()
	encounter_completed.emit()


func _set_gates(locked: bool) -> void:
	for gate in gates:
		if gate: gate.set_locked(locked)


func _enter_arena_camera() -> void:
	_camera = get_viewport().get_camera_2d()
	if not _camera: return
	_camera_original_limits = Rect2i(_camera.limit_left, _camera.limit_top, _camera.limit_right - _camera.limit_left, _camera.limit_bottom - _camera.limit_top)
	_camera_original_horizontal_drag = _camera.drag_horizontal_enabled
	_camera_original_vertical_drag = _camera.drag_vertical_enabled
	_camera_original_margins = Vector4(_camera.drag_left_margin, _camera.drag_top_margin, _camera.drag_right_margin, _camera.drag_bottom_margin)
	_camera_original_smoothing = _camera.position_smoothing_enabled
	_camera_original_smoothing_speed = _camera.position_smoothing_speed
	_camera_original_top_level = _camera.top_level
	_camera_original_local_position = _camera.position
	_camera_zoom_source = _camera
	if _camera is CutsceneCameraController2D and is_instance_valid((_camera as CutsceneCameraController2D).current_camera):
		_camera_zoom_source = (_camera as CutsceneCameraController2D).current_camera
	_camera_original_zoom = _camera_zoom_source.get("camera_zoom") if _camera_zoom_source is CutsceneVirtualCamera2D else _camera.zoom
	_active_camera_bounds = _get_world_camera_bounds()
	var bounds := _active_camera_bounds.grow_individual(camera_bound_padding.x, camera_bound_padding.y, camera_bound_padding.x, camera_bound_padding.y)
	_camera.limit_left = floori(bounds.position.x)
	_camera.limit_top = floori(bounds.position.y)
	_camera.limit_right = ceili(bounds.end.x)
	_camera.limit_bottom = ceili(bounds.end.y)
	_camera.drag_horizontal_enabled = false
	_camera.drag_vertical_enabled = false
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = camera_follow_speed
	if not _camera is CutsceneCameraController2D:
		var world_transform := _camera.global_transform
		_camera.top_level = true
		_camera.global_transform = world_transform
		set_process(true)
	var target_zoom := _camera_original_zoom * camera_zoom_multiplier
	var property := "camera_zoom" if _camera_zoom_source is CutsceneVirtualCamera2D else "zoom"
	create_tween().tween_property(_camera_zoom_source, property, target_zoom, camera_transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _leave_arena_camera() -> void:
	if not is_instance_valid(_camera): return
	_camera.limit_left = _camera_original_limits.position.x
	_camera.limit_top = _camera_original_limits.position.y
	_camera.limit_right = _camera_original_limits.end.x
	_camera.limit_bottom = _camera_original_limits.end.y
	_camera.drag_horizontal_enabled = _camera_original_horizontal_drag
	_camera.drag_vertical_enabled = _camera_original_vertical_drag
	_camera.drag_left_margin = _camera_original_margins.x
	_camera.drag_top_margin = _camera_original_margins.y
	_camera.drag_right_margin = _camera_original_margins.z
	_camera.drag_bottom_margin = _camera_original_margins.w
	_camera.position_smoothing_enabled = _camera_original_smoothing
	_camera.position_smoothing_speed = _camera_original_smoothing_speed
	if not _camera is CutsceneCameraController2D:
		_camera.top_level = _camera_original_top_level
		_camera.position = _camera_original_local_position
	if is_instance_valid(_camera_zoom_source):
		var property := "camera_zoom" if _camera_zoom_source is CutsceneVirtualCamera2D else "zoom"
		create_tween().tween_property(_camera_zoom_source, property, _camera_original_zoom, camera_transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arena_player = null


func _process(delta: float) -> void:
	if not active or not is_instance_valid(_camera) or not is_instance_valid(_arena_player): return
	var half_size := _active_camera_bounds.size * 0.5
	if half_size.x <= 0.0 or half_size.y <= 0.0: return
	var arena_center := _active_camera_bounds.get_center()
	var normalized := (_arena_player.global_position - arena_center) / half_size
	normalized = normalized.clamp(Vector2(-1.0, -1.0), Vector2.ONE)
	var desired := arena_center + normalized * camera_follow_distance
	var weight := 1.0 - exp(-camera_follow_speed * delta)
	_camera.global_position = _camera.global_position.lerp(desired, weight)


func _get_world_camera_bounds() -> Rect2:
	if use_trigger_as_camera_bounds and trigger:
		var shape_node := trigger.find_child("CollisionShape2D", true, false) as CollisionShape2D
		if shape_node and shape_node.shape is RectangleShape2D:
			var size := (shape_node.shape as RectangleShape2D).size * shape_node.global_scale.abs()
			return Rect2(shape_node.global_position - size * 0.5, size)
	var scaled_size := camera_bounds.size * global_scale.abs()
	return Rect2(global_position + camera_bounds.position * global_scale.abs(), scaled_size)
