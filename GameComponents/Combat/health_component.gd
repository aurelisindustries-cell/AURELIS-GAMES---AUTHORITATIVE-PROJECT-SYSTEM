@icon("res://addons/at-icons/node2d/heart.svg")
extends Node
class_name HealthComponent

signal health_changed(current: int, maximum: int)
signal damaged(hit: HitData)
signal died(hit: HitData)

@export_range(1, 999, 1) var max_health: int = 16
@export var start_at_max_health: bool = true

var current_health: int


func _ready() -> void:
	current_health = max_health if start_at_max_health else clampi(current_health, 0, max_health)
	health_changed.emit(current_health, max_health)


func apply_hit(hit: HitData) -> bool:
	if not hit or hit.damage <= 0 or current_health <= 0:
		return false
	current_health = maxi(current_health - hit.damage, 0)
	damaged.emit(hit)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit(hit)
	return true


func heal(amount: int) -> int:
	var previous := current_health
	current_health = mini(current_health + maxi(amount, 0), max_health)
	if current_health != previous:
		health_changed.emit(current_health, max_health)
	return current_health - previous


func restore_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func set_max_health(value: int, refill: bool = false) -> void:
	max_health = clampi(value, 1, 999)
	current_health = max_health if refill else mini(current_health, max_health)
	health_changed.emit(current_health, max_health)
