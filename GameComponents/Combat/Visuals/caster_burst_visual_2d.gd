extends Node2D
class_name CasterBurstVisual2D

@export var lifetime: float = 0.12
@export var color := Color(0.35, 0.9, 1.0, 1.0)
@export var maximum_radius: float = 18.0
var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= lifetime: queue_free()

func _draw() -> void:
	var progress := clampf(_elapsed / lifetime, 0.0, 1.0)
	var draw_color := color
	draw_color.a *= 1.0 - progress
	draw_circle(Vector2.ZERO, lerpf(3.0, maximum_radius, progress), draw_color, false, 3.0, true)
