@icon("res://addons/at-icons/node2d/sword.svg")
extends Area2D
class_name HitboxComponent2D

signal hit_landed(hurtbox: HurtboxComponent2D, hit: HitData)

@export var default_hit: HitData
@export var active_on_ready: bool = false
@export_range(0.0, 10.0, 0.05) var repeat_hit_interval: float = 0.0
@export_category("Greybox Display")
@export var show_active_shape: bool = true
@export var active_fill_color := Color(0.1, 0.85, 1.0, 0.24)
@export var active_outline_color := Color(0.65, 1.0, 1.0, 0.9)

var source: Node
var _already_hit: Dictionary = {}
var _repeat_remaining := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = false
	if active_on_ready:
		activate(default_hit, _find_character_body())


func _physics_process(delta: float) -> void:
	if not monitoring or repeat_hit_interval <= 0.0:
		return
	_repeat_remaining = maxf(_repeat_remaining - delta, 0.0)
	if _repeat_remaining > 0.0:
		return
	_already_hit.clear()
	_repeat_remaining = repeat_hit_interval
	for area in get_overlapping_areas():
		_on_area_entered(area)


func activate(hit: HitData = default_hit, attack_source: Node = null) -> void:
	default_hit = hit
	source = attack_source
	_already_hit.clear()
	_repeat_remaining = repeat_hit_interval
	monitoring = true
	queue_redraw()


func deactivate() -> void:
	monitoring = false
	_already_hit.clear()
	queue_redraw()


func _draw() -> void:
	if not show_active_shape or not monitoring:
		return
	var collision := _find_collision_shape()
	if not collision or not collision.shape:
		return
	var shape := collision.shape
	if shape is RectangleShape2D:
		var size := (shape as RectangleShape2D).size
		var rect := Rect2(collision.position - size * 0.5, size)
		draw_rect(rect, active_fill_color, true)
		draw_rect(rect, active_outline_color, false, 2.0)
	elif shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		draw_circle(collision.position, radius, active_fill_color)
		draw_arc(collision.position, radius, 0.0, TAU, 28, active_outline_color, 2.0, true)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var rect := Rect2(collision.position - Vector2(capsule.radius, capsule.height * 0.5), Vector2(capsule.radius * 2.0, capsule.height))
		draw_rect(rect, active_fill_color, true)
		draw_rect(rect, active_outline_color, false, 2.0)


func _find_collision_shape() -> CollisionShape2D:
	for child in get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null


func _find_character_body() -> CharacterBody2D:
	var ancestor := get_parent()
	while ancestor:
		if ancestor is CharacterBody2D:
			return ancestor as CharacterBody2D
		ancestor = ancestor.get_parent()
	return null


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent2D
	if not hurtbox or _already_hit.has(hurtbox) or (source and source.is_ancestor_of(hurtbox)):
		return
	_already_hit[hurtbox] = true
	var hit := default_hit.copy_for(source) if default_hit else HitData.new()
	if hurtbox.receive_hit(hit):
		if hit.hit_stop > 0.0:
			_apply_hit_stop(hit.hit_stop)
		hit_landed.emit(hurtbox, hit)


func _apply_hit_stop(duration: float) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
