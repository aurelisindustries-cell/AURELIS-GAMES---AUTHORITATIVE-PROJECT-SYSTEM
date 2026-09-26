@icon("res://addons/at-icons/node2d/sword.svg")
extends Node
class_name EnemyCombatController

signal attack_started
signal attack_activated

@export var ai_root: AIRoot
@export var hitbox: HitboxComponent2D
@export var damage: int = 1
@export var windup_time: float = 0.18
@export var active_time: float = 0.12
@export var recovery_time: float = 0.8
@export var knockback := Vector2(42.0, -12.0)
@export var charge_speed: float = 0.0
@export var charge_duration: float = 0.22
@export var character_controller: CharacterController
@export var visuals: CanvasItem

var _active_remaining := 0.0
var _recovery_remaining := 0.0
var _windup_remaining := 0.0
var _attack_pending := false
var _visual_modulate := Color.WHITE
var _charge_displacement := Vector2.ZERO
var _charge_remaining := 0.0
var _telegraph: Line2D

func _ready() -> void:
	if ai_root: ai_root.task_requested.connect(_on_task_requested)
	if ai_root and ai_root.actor:
		if not character_controller: character_controller = ai_root.actor.get_component(CharacterController) as CharacterController
		if not visuals: visuals = ai_root.actor.find_child("Visuals", true, false) as CanvasItem
	if visuals: _visual_modulate = visuals.modulate
	_create_telegraph()


func _physics_process(delta: float) -> void:
	if _charge_remaining <= 0.0 or not character_controller or not character_controller.controlling:
		return
	var weight := minf(delta / _charge_remaining, 1.0)
	var step := _charge_displacement * weight
	if character_controller.controlling.move_and_collide(step):
		_charge_displacement = Vector2.ZERO
		_charge_remaining = 0.0
	else:
		_charge_displacement -= step
		_charge_remaining = maxf(_charge_remaining - delta, 0.0)

func _process(delta: float) -> void:
	_active_remaining = maxf(_active_remaining - delta, 0.0)
	_recovery_remaining = maxf(_recovery_remaining - delta, 0.0)
	_windup_remaining = maxf(_windup_remaining - delta, 0.0)
	_update_hitbox_facing()
	if _attack_pending and _windup_remaining <= 0.0:
		_attack_pending = false
		_activate_attack()
	if hitbox and hitbox.monitoring and _active_remaining <= 0.0: hitbox.deactivate()

func _on_task_requested(action: StringName, _data: Variant) -> void:
	if action != &"attack" or _recovery_remaining > 0.0 or _attack_pending or not hitbox: return
	_attack_pending = true
	attack_started.emit()
	_windup_remaining = windup_time
	_recovery_remaining = windup_time + active_time + recovery_time
	if visuals:
		visuals.modulate = Color(1.5, 0.55, 0.35, 1.0)
		create_tween().tween_property(visuals, "modulate", _visual_modulate, windup_time)
	_show_telegraph()


func _activate_attack() -> void:
	attack_activated.emit()
	var hit := HitData.new()
	hit.damage = damage
	hit.attack_type = &"enemy_attack"
	hit.faction = &"enemy"
	hit.reaction = "knockback"
	hit.knockback = Vector2(absf(knockback.x) * (character_controller.facing_direction if character_controller else 1.0), knockback.y)
	hitbox.activate(hit, get_parent().get_parent())
	_active_remaining = active_time
	if charge_speed > 0.0 and character_controller and character_controller.controlling:
		_charge_remaining = charge_duration
		_charge_displacement = Vector2(character_controller.facing_direction * charge_speed * charge_duration, 0.0)


func _update_hitbox_facing() -> void:
	if hitbox and character_controller:
		hitbox.position.x = absf(hitbox.position.x) * character_controller.facing_direction


func _create_telegraph() -> void:
	_telegraph = Line2D.new()
	_telegraph.name = "AttackTelegraph"
	_telegraph.width = 3.0
	_telegraph.default_color = Color(1.0, 0.18, 0.08, 0.0)
	_telegraph.closed = true
	for index in 17:
		var angle := TAU * float(index) / 16.0
		_telegraph.add_point(Vector2(cos(angle), sin(angle)) * 35.0)
	var actor := get_parent().get_parent()
	actor.add_child.call_deferred(_telegraph)


func _show_telegraph() -> void:
	if not _telegraph: return
	_telegraph.scale = Vector2(0.35, 0.35)
	_telegraph.modulate = Color(1.0, 0.22, 0.08, 1.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_telegraph, "scale", Vector2.ONE, windup_time)
	tween.tween_property(_telegraph, "modulate:a", 0.15, windup_time)
