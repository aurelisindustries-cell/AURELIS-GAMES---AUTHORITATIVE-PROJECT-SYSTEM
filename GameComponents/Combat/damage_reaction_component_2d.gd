@icon("res://addons/at-icons/node2d/boxing_glove.svg")
extends Node
class_name DamageReactionComponent2D

signal recoil_started(direction: float, distance: float)
signal hit_stop_requested(duration: float)

@export var hurtbox: HurtboxComponent2D
@export var body: CharacterBody2D
@export var default_recoil_distance: float = 12.0
@export var default_hit_stop: float = 0.035
@export var recoil_duration: float = 0.16

var _remaining_displacement := Vector2.ZERO
var _recoil_remaining := 0.0


func _ready() -> void:
	if not body:
		body = get_parent() as CharacterBody2D
	if not hurtbox:
		hurtbox = get_parent().get_node_or_null("HurtboxComponent2D") as HurtboxComponent2D
	if hurtbox:
		hurtbox.hit_received.connect(_on_hit_received)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not body or _recoil_remaining <= 0.0:
		set_physics_process(false)
		return
	var weight := minf(delta / _recoil_remaining, 1.0)
	var step := _remaining_displacement * weight
	var collision := body.move_and_collide(step)
	_remaining_displacement -= step
	_recoil_remaining = maxf(_recoil_remaining - delta, 0.0)
	if collision or _recoil_remaining <= 0.0:
		_remaining_displacement = Vector2.ZERO
		_recoil_remaining = 0.0
		set_physics_process(false)


func _on_hit_received(hit: HitData) -> void:
	if not body:
		return
	var direction := -1.0
	if hit.source is Node2D:
		direction = signf(body.global_position.x - (hit.source as Node2D).global_position.x)
		if is_zero_approx(direction): direction = -1.0
	var displacement := hit.knockback.x
	if is_zero_approx(displacement):
		displacement = direction * default_recoil_distance
	elif signf(displacement) != direction:
		displacement = absf(displacement) * direction
	_remaining_displacement = Vector2(displacement, hit.knockback.y)
	_recoil_remaining = recoil_duration
	set_physics_process(true)
	recoil_started.emit(direction, absf(displacement))
	hit_stop_requested.emit(hit.hit_stop if hit.hit_stop > 0.0 else default_hit_stop)
