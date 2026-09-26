@icon("res://addons/at-icons/node2d/dagger.svg")
extends Node2D
class_name DaggerSlashVisual2D

@export var lifetime: float = 0.16
@export var inner_color := Color(0.8, 1.0, 1.0, 1.0)
@export var outer_color := Color(0.15, 0.75, 1.0, 0.7)
@export var radius: float = 42.0

var attack_type: StringName = &"normal"
var facing := 1.0
var _elapsed := 0.0


func setup(type: StringName, direction: float) -> void:
	attack_type = type
	facing = direction
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(_elapsed / lifetime, 0.0, 1.0)
	var alpha := 1.0 - ease(progress, 2.0)
	var glow := outer_color
	var core := inner_color
	glow.a *= alpha
	core.a *= alpha
	match attack_type:
		&"up_slash":
			_draw_sweep(-2.8, -0.35, progress, glow, core, facing)
		&"downstab":
			var length := lerpf(12.0, 58.0, minf(progress * 2.0, 1.0))
			draw_line(Vector2(0, -18), Vector2(0, length), glow, 12.0, true)
			draw_line(Vector2(0, -18), Vector2(0, length), core, 4.0, true)
		&"downstab_impact":
			var impact_radius := lerpf(8.0, 46.0, progress)
			draw_arc(Vector2.ZERO, impact_radius, PI, TAU, 20, glow, 9.0, true)
			draw_arc(Vector2.ZERO, impact_radius, PI, TAU, 20, core, 3.0, true)
		_:
			_draw_sweep(-1.15, 1.15, progress, glow, core, facing)
	draw_circle(Vector2.ZERO, 3.0, core)


func _draw_sweep(from_angle: float, to_angle: float, progress: float, glow: Color, core: Color, direction: float) -> void:
	var visible_end := lerpf(from_angle, to_angle, minf(progress * 1.8, 1.0))
	var points := PackedVector2Array()
	for index in range(18):
		var weight := float(index) / 17.0
		var angle := lerpf(from_angle, visible_end, weight)
		points.append(Vector2(cos(angle) * radius * direction, sin(angle) * radius))
	if points.size() > 1:
		draw_polyline(points, glow, 13.0, true)
		draw_polyline(points, core, 4.0, true)
