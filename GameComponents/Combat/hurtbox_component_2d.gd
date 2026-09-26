@icon("res://addons/at-icons/node2d/shield.svg")
extends Area2D
class_name HurtboxComponent2D

signal hit_received(hit: HitData)

@export var health: HealthComponent
@export var faction: StringName = &"neutral"
@export_range(0.0, 5.0, 0.05) var invulnerability_duration: float = 0.0
@export var enabled: bool = true:
	set(value):
		enabled = value
		monitorable = value


func _ready() -> void:
	add_to_group(&"combat_hurtboxes")
	if not health:
		health = get_parent().get_node_or_null("HealthComponent") as HealthComponent
	monitorable = enabled


func receive_hit(hit: HitData) -> bool:
	if not enabled or not hit:
		return false
	if hit.faction != &"neutral" and hit.faction == faction:
		return false
	var accepted := health.apply_hit(hit) if health else true
	if accepted:
		hit_received.emit(hit)
		if invulnerability_duration > 0.0:
			_begin_invulnerability()
	return accepted


func _begin_invulnerability() -> void:
	enabled = false
	await get_tree().create_timer(invulnerability_duration).timeout
	enabled = true
