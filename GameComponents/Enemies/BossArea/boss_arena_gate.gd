@icon("res://addons/at-icons/node2d/door.svg")
extends StaticBody2D
class_name BossArenaGate

@export var starts_locked: bool = false
@export var gate_visual: CanvasItem
@export var gate_collision: CollisionShape2D


func _ready() -> void:
	if not gate_visual: gate_visual = get_node_or_null("Visual") as CanvasItem
	if not gate_collision: gate_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	set_locked(starts_locked)


func set_locked(locked: bool) -> void:
	if gate_collision: gate_collision.set_deferred("disabled", not locked)
	if gate_visual: gate_visual.visible = locked
