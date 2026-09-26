@icon("res://addons/at-icons/node2d/target.svg")
extends Node2D
class_name AimIndicator2D

@export var length: float = 52.0
@export var start_offset: float = 24.0
@export var line_width: float = 3.0
@export var idle_color := Color(0.35, 0.85, 1.0, 0.55)
@export var aimed_color := Color(0.7, 1.0, 1.0, 0.95)
@export var arrow_size: float = 7.0

var _engaged := false


func set_engaged(value: bool) -> void:
	if _engaged == value:
		return
	_engaged = value
	queue_redraw()


func _draw() -> void:
	var color := aimed_color if _engaged else idle_color
	var start := Vector2(start_offset, 0.0)
	var end := Vector2(length, 0.0)
	draw_line(start, end, color, line_width, true)
	draw_colored_polygon(PackedVector2Array([
		end,
		end + Vector2(-arrow_size, -arrow_size * 0.65),
		end + Vector2(-arrow_size, arrow_size * 0.65)
	]), color)
	draw_circle(start, 2.5, color)
