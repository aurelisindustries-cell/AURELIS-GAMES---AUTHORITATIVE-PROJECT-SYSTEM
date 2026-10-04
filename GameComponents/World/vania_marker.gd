@tool
extends Node2D
class_name VaniaMarker

@export_enum("Exit", "Ability", "Health upgrade") var kind := 0
@export var marker_id := ""
@export var destination_room := ""
@export var destination_door := ""
@export var required_ability := ""
@export_enum("Left", "Right", "Up", "Down") var side := 1
@export var ability := "dash"
# Zero keeps old room files compatible with the direction's default size.
@export var transition_size := Vector2.ZERO
var transition_area: Area2D
var runtime := false
var locked := false
var gate_label := ""
var gate_collision: CollisionShape2D


func zone_size() -> Vector2:
	if transition_size.x > 0 and transition_size.y > 0: return transition_size
	return Vector2(48, 128) if side < 2 else Vector2(128, 48)


func zone_rect() -> Rect2:
	return Rect2(Vector2(0, -32) - zone_size() * 0.5, zone_size())


func arrival_offset() -> Vector2:
	var inward := -Vector2(VaniaWorldData.DIRECTIONS[side])
	var distance := zone_size().x * 0.5 + 40 if side < 2 else zone_size().y * 0.5 + 64
	return inward * distance


func arrival_position() -> Vector2:
	return to_global(arrival_offset())


func enable_runtime() -> void:
	runtime = true
	queue_redraw()
	if kind != 0 or is_instance_valid(transition_area): return
	transition_area = Area2D.new()
	transition_area.name = "TransitionArea"
	transition_area.collision_layer = 0
	transition_area.collision_mask = 1
	transition_area.monitorable = false
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = zone_size()
	collision.shape = shape
	collision.position = zone_rect().get_center()
	transition_area.add_child(collision)
	add_child(transition_area)
	var blocker := StaticBody2D.new()
	blocker.collision_layer = 2
	blocker.collision_mask = 1
	gate_collision = CollisionShape2D.new()
	gate_collision.shape = shape
	gate_collision.position = collision.position
	gate_collision.disabled = true
	blocker.add_child(gate_collision)
	add_child(blocker)


func set_gate(required: String, unlocked: bool) -> void:
	locked = not required.is_empty() and not unlocked
	gate_label = required.replace("_", " ").to_upper()
	if gate_collision: gate_collision.set_deferred("disabled", not locked)
	queue_redraw()


func _draw() -> void:
	if runtime and kind == 0 and not locked: return
	var color := Color(0.35, 0.95, 1.0) if kind == 0 else Color(1.0, 0.8, 0.3)
	if locked: color = Color(1, 0.75, 0.25)
	var rect := zone_rect() if kind == 0 else Rect2(-14, -48, 28, 48)
	draw_rect(rect, Color(color, 0.15))
	draw_rect(rect, color, false, 2.0)
	var label: String = ["TRANSITION", ability.replace("_", " ").to_upper(), "+ HEALTH"][kind]
	if locked: label = gate_label
	if kind == 0:
		label += " " + ["<", ">", "^", "v"][side]
		draw_line(rect.get_center(), rect.get_center() + Vector2(VaniaWorldData.DIRECTIONS[side]) * 20, color, 3)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
