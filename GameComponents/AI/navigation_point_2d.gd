@tool
@icon("res://addons/at-icons/node2d/location.svg")
extends Marker2D
class_name NavigationPoint2D

@export var radius: float = 8.0:
	set(value):
		radius = maxf(value, 2.0)
		queue_redraw()
@export var color: Color = Color(0.25, 0.85, 1.0, 0.9):
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color, 0.16))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 2.0)
	draw_line(Vector2(-radius - 4.0, 0.0), Vector2(radius + 4.0, 0.0), color, 1.0)
	draw_line(Vector2(0.0, -radius - 4.0), Vector2(0.0, radius + 4.0), color, 1.0)
