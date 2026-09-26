@tool
extends Node2D
class_name CutsceneVirtualCamera2D

@export var is_player_camera: bool = false
@export var follow_target: Node2D
@export var follow_offset: Vector2 = Vector2.ZERO
@export var follow_damping: bool = true
@export var follow_damping_speed: Vector2 = Vector2(8.0, 8.0)
@export var rotate_with_target: bool = false
@export var camera_zoom: Vector2 = Vector2.ONE
@export var camera_rotation: float = 0.0
@export_group("Limits")
@export var use_limits: bool = false
@export var limit_left: int = -10000000
@export var limit_top: int = -10000000
@export var limit_right: int = 10000000
@export var limit_bottom: int = 10000000


func _enter_tree() -> void:
	add_to_group("cutscene_virtual_cameras")


func get_target_position() -> Vector2:
	if is_instance_valid(follow_target):
		return follow_target.global_position + follow_offset.rotated(follow_target.global_rotation)
	return global_position


func get_target_rotation() -> float:
	if rotate_with_target and is_instance_valid(follow_target):
		return follow_target.global_rotation + camera_rotation
	return camera_rotation
