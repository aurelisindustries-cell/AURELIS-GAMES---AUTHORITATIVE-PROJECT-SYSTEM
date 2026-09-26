@tool
@icon("res://addons/at-icons/node2d/target.svg")
extends Node2D
class_name HitboxAuthoringHandle2D

@export var active: bool = false:
	set(value):
		active = value
		queue_redraw()
@export var shape: Shape2D:
	set(value):
		shape = value
		queue_redraw()
@export var hit: HitData
@export var preview_fill := Color(0.1, 0.85, 1.0, 0.24)
@export var preview_outline := Color(0.65, 1.0, 1.0, 0.95)


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or not active or not shape:
		return
	if shape is RectangleShape2D:
		var size := (shape as RectangleShape2D).size
		var rect := Rect2(-size * 0.5, size)
		draw_rect(rect, preview_fill, true)
		draw_rect(rect, preview_outline, false, 2.0)
	elif shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		draw_circle(Vector2.ZERO, radius, preview_fill)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, preview_outline, 2.0, true)
	draw_line(Vector2(-6, 0), Vector2(6, 0), preview_outline, 1.0)
	draw_line(Vector2(0, -6), Vector2(0, 6), preview_outline, 1.0)
