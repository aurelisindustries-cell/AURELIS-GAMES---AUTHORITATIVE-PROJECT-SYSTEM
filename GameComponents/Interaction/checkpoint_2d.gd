extends Area2D
class_name Checkpoint2D

@export var respawn_offset := Vector2(0.0, -8.0)
@export var one_shot: bool = true

var activated := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if activated and one_shot or not body.is_in_group(&"player"): return
	var lifecycle := body.find_child("PlayerLifecycleComponent", true, false) as PlayerLifecycleComponent
	if not lifecycle: return
	var first_activation := not activated
	activated = true
	lifecycle.set_checkpoint(global_position + respawn_offset)
	modulate = Color(0.35, 1.8, 1.5, 1.0)
	if not first_activation: return
	var tween := create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.45)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45)
