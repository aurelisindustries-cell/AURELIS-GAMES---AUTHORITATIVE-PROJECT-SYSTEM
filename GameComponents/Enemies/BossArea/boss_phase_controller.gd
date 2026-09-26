@icon("res://addons/at-icons/node2d/bolt.svg")
extends Node
class_name BossPhaseController

signal phase_changed(phase: int)

@export_range(0.05, 0.95, 0.05) var phase_two_health_ratio: float = 0.5
@export_range(0.05, 0.95, 0.05) var phase_three_health_ratio: float = 0.22
@export var phase_two_speed: float = 210.0
@export var phase_two_damage: int = 3
@export var phase_two_windup: float = 0.14
@export var phase_two_recovery: float = 0.38
@export var phase_three_speed: float = 260.0
@export var phase_three_damage: int = 4
@export var health: HealthComponent
@export var combat_controller: EnemyCombatController
@export var character_controller: CharacterController
@export var visuals: CanvasItem

var phase := 1


func _ready() -> void:
	var enemy := get_parent()
	if not health: health = enemy.find_child("HealthComponent", true, false) as HealthComponent
	if not combat_controller: combat_controller = enemy.find_child("EnemyCombatController", true, false) as EnemyCombatController
	if not character_controller: character_controller = enemy.find_child("CharacterController", true, false) as CharacterController
	if not visuals: visuals = enemy.find_child("Visuals", true, false) as CanvasItem
	if health:
		health.health_changed.connect(_on_health_changed)
		_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0 or current <= 0: return
	var ratio := float(current) / float(maximum)
	if ratio <= phase_three_health_ratio and phase < 3:
		_apply_phase_three()
	elif ratio <= phase_two_health_ratio and phase < 2:
		_apply_phase_two()


func _apply_phase_two() -> void:
	phase = 2
	if character_controller:
		character_controller.move_speed = phase_two_speed
		var walk := character_controller.state_machine.find_child("Walk") if character_controller.state_machine else null
		if walk: walk.set("speed", phase_two_speed)
	if combat_controller:
		combat_controller.damage = phase_two_damage
		combat_controller.windup_time = phase_two_windup
		combat_controller.recovery_time = phase_two_recovery
	if visuals: visuals.modulate = Color(1.0, 0.35, 0.22, 1.0)
	phase_changed.emit(phase)


func _apply_phase_three() -> void:
	phase = 3
	if character_controller:
		character_controller.move_speed = phase_three_speed
		var walk := character_controller.state_machine.find_child("Walk") if character_controller.state_machine else null
		if walk: walk.set("speed", phase_three_speed)
	if combat_controller:
		combat_controller.damage = phase_three_damage
		combat_controller.windup_time = 0.3
		combat_controller.recovery_time = 0.22
		combat_controller.charge_speed = 620.0
		combat_controller.charge_duration = 0.24
	if visuals: visuals.modulate = Color(1.4, 0.12, 0.55, 1.0)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.55, 0.8, Vector2(24.0, 16.0), 0.035)
	phase_changed.emit(phase)
