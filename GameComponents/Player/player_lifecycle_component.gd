extends Node
class_name PlayerLifecycleComponent

signal checkpoint_changed(position: Vector2)
signal respawn_started
signal respawn_finished

@export var body: CharacterBody2D
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent2D
@export var visuals: CanvasItem
@export var respawn_delay: float = 0.8
@export var hit_flash_duration: float = 0.1

var checkpoint_position := Vector2.ZERO
var _original_modulate := Color.WHITE
var _dead := false


func _ready() -> void:
	if not body: body = get_parent().get_parent() as CharacterBody2D
	if not body: return
	if not health: health = body.find_child("HealthComponent", true, false) as HealthComponent
	if not hurtbox: hurtbox = body.find_child("HurtboxComponent2D", true, false) as HurtboxComponent2D
	if not visuals: visuals = body.find_child("Visuals", true, false) as CanvasItem
	checkpoint_position = body.global_position
	_original_modulate = visuals.modulate if visuals else Color.WHITE
	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)


func set_checkpoint(new_position: Vector2) -> void:
	checkpoint_position = new_position
	checkpoint_changed.emit(new_position)


func _on_damaged(_hit: HitData) -> void:
	if not visuals or _dead: return
	var tween := create_tween().set_loops(4)
	tween.tween_property(visuals, "modulate", Color(3.0, 3.0, 3.0, 0.35), hit_flash_duration * 0.5)
	tween.tween_property(visuals, "modulate", _original_modulate, hit_flash_duration * 0.5)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.18, 1.8, Vector2(9.0, 6.0), 0.015)


func _on_died(_hit: HitData) -> void:
	if _dead: return
	_dead = true
	respawn_started.emit()
	_set_player_active(false)
	if visuals:
		var tween := create_tween()
		tween.tween_property(visuals, "modulate:a", 0.0, respawn_delay * 0.7)
	await get_tree().create_timer(respawn_delay).timeout
	body.global_position = checkpoint_position
	body.velocity = Vector2.ZERO
	var controller := body.find_child("CharacterController", true, false) as CharacterController
	if controller: controller.velocity = Vector2.ZERO
	if health: health.restore_full()
	if visuals:
		visuals.modulate = _original_modulate
	_set_player_active(true)
	_dead = false
	respawn_finished.emit()


func _set_player_active(active: bool) -> void:
	var movement := body.get_node_or_null("Movement")
	var combat := body.get_node_or_null("Combat")
	if movement: movement.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if combat:
		for child in combat.get_children():
			if child != self:
				child.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	var body_collision := body.find_child("Collision", true, false) as CollisionShape2D
	if body_collision: body_collision.set_deferred("disabled", not active)
	if hurtbox: hurtbox.set_deferred("enabled", active)
