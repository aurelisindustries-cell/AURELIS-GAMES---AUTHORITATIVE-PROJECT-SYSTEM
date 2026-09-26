@icon("res://addons/at-icons/node2d/heart.svg")
extends ProgressBar
class_name WorldHealthBar2D

@export var health: HealthComponent
@export var hide_when_full: bool = false


func _ready() -> void:
	if not health:
		health = get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if not health:
		return
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	max_value = maximum
	value = current
	visible = not hide_when_full or current < maximum
	tooltip_text = "%d / %d" % [current, maximum]
