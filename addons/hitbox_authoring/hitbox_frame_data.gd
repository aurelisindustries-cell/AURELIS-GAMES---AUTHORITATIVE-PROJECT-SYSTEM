@tool
@icon("res://addons/at-icons/node2d/clock.svg")
extends Resource
class_name HitboxFrameData

@export var animation: StringName
@export_range(0.0, 3600.0, 0.001, "suffix:s") var start_time: float
@export_range(0.001, 10.0, 0.001, "suffix:s") var duration: float = 0.1
@export var position := Vector2.ZERO
@export var rotation: float
@export var scale := Vector2.ONE
@export var shape: Shape2D
@export var hit: HitData


func is_active(animation_name: StringName, time: float) -> bool:
	return animation == animation_name and time >= start_time and time < start_time + duration
