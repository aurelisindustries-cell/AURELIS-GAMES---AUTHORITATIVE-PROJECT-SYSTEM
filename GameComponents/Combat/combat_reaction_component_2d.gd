@icon("res://addons/at-icons/node2d/boxing_glove.svg")
extends Node
class_name CombatReactionComponent2D

signal reaction_started(type: StringName, duration: float)
signal reaction_finished(type: StringName)

enum BodySize { SMALL, MEDIUM, LARGE }

@export var hurtbox: HurtboxComponent2D
@export var body: CharacterBody2D
@export var body_size: BodySize = BodySize.MEDIUM
@export var gravity: float = 1100.0
@export var recoil_distance: float = 12.0
@export var recoil_duration: float = 0.12
@export var forced_stagger_distance: float = 72.0
@export_range(0.0, 2.0, 0.05) var knockback_multiplier: float = 1.0

var reaction_velocity := Vector2.ZERO
var reaction_displacement := Vector2.ZERO
var reaction_remaining := 0.0
var current_reaction: StringName


func _ready() -> void:
	if hurtbox:
		hurtbox.hit_received.connect(apply_reaction)


func _physics_process(delta: float) -> void:
	if reaction_remaining <= 0.0 or not body:
		return
	if not reaction_displacement.is_zero_approx():
		var weight := minf(delta / reaction_remaining, 1.0)
		var step := reaction_displacement * weight
		if body.move_and_collide(step):
			reaction_displacement = Vector2.ZERO
		else:
			reaction_displacement -= step
	reaction_remaining = maxf(reaction_remaining - delta, 0.0)
	if current_reaction in [&"launch", &"knockback", &"aerial_interrupt", &"toss", &"slammed"]:
		reaction_velocity.y += gravity * delta
		body.velocity = reaction_velocity
		body.move_and_slide()
		reaction_velocity = body.velocity
	if reaction_remaining <= 0.0:
		var completed := current_reaction
		current_reaction = &""
		reaction_displacement = Vector2.ZERO
		reaction_finished.emit(completed)


func apply_reaction(hit: HitData) -> void:
	if not body or not hit:
		return
	var direction := _direction_from_source(hit.source)
	current_reaction = StringName(hit.reaction)
	reaction_remaining = hit.reaction_duration
	reaction_displacement = Vector2.ZERO
	match current_reaction:
		&"hit_recoil":
			reaction_displacement = Vector2(direction * recoil_distance * knockback_multiplier, 0.0)
			reaction_remaining = maxf(reaction_remaining, recoil_duration)
		&"forced_stagger":
			if body_size != BodySize.LARGE:
				reaction_displacement = Vector2(direction * forced_stagger_distance * knockback_multiplier, 0.0)
				reaction_remaining = maxf(reaction_remaining, 0.2)
		&"launch":
			if body_size != BodySize.LARGE:
				reaction_velocity = Vector2(hit.knockback.x, hit.knockback.y if hit.knockback.y < 0.0 else -280.0) * knockback_multiplier
				reaction_remaining = maxf(reaction_remaining, 0.5)
		&"knockback", &"aerial_interrupt", &"toss", &"slammed":
			reaction_velocity = hit.knockback * knockback_multiplier
			if is_zero_approx(reaction_velocity.x): reaction_velocity.x = direction * 220.0 * knockback_multiplier
			reaction_remaining = maxf(reaction_remaining, 0.35)
		&"stun":
			reaction_remaining = maxf(reaction_remaining, 0.75)
	reaction_started.emit(current_reaction, reaction_remaining)


func is_control_locked() -> bool:
	return reaction_remaining > 0.0 and current_reaction in [&"stun", &"aerial_interrupt", &"toss", &"slammed"]


func cancel_reaction() -> void:
	reaction_remaining = 0.0
	reaction_velocity = Vector2.ZERO
	reaction_displacement = Vector2.ZERO
	current_reaction = &""


func _direction_from_source(source: Node) -> float:
	if source is Node2D:
		var result := signf(body.global_position.x - (source as Node2D).global_position.x)
		return result if not is_zero_approx(result) else 1.0
	return 1.0
