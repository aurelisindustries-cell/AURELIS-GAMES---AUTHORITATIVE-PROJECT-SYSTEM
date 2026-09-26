@icon("res://addons/at-icons/node2d/arrow_up.svg")
extends Label
class_name DamageNumber2D

@export var rise_distance: float = 30.0
@export var lifetime: float = 0.65
@export var spread: float = 10.0


func show_damage(amount: int, critical: bool = false) -> void:
	text = "%d!" % amount if critical else str(amount)
	if critical:
		modulate = Color(1.0, 0.85, 0.25)
	position.x += randf_range(-spread, spread)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise_distance, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
