extends Node
class_name CharacterMotionAnimator

@export var body: CharacterBody2D
@export var visuals: Node2D
@export var controller: CharacterController
@export var state_machine: StateMachine
@export var enemy_combat: EnemyCombatController
@export var health: HealthComponent
@export var run_bob_height: float = 2.5
@export var max_lean: float = 0.08

var _base_position := Vector2.ZERO
var _run_time := 0.0
var _action_scale := Vector2.ONE
var _action_offset := Vector2.ZERO
var _action_rotation := 0.0
var _hurt_offset := Vector2.ZERO


func _ready() -> void:
	if not body: body = get_parent() as CharacterBody2D
	if not body: return
	if not visuals: visuals = body.find_child("Visuals", true, false) as Node2D
	if not controller: controller = body.find_child("CharacterController", true, false) as CharacterController
	if not state_machine: state_machine = body.find_child("StateMachine", true, false) as StateMachine
	if not enemy_combat: enemy_combat = body.find_child("EnemyCombatController", true, false) as EnemyCombatController
	if not health: health = body.find_child("HealthComponent", true, false) as HealthComponent
	if not visuals: return
	_base_position = visuals.position
	if controller:
		controller.movement_action.connect(_on_movement_action)
		controller.landed.connect(_on_landed)
	if state_machine: state_machine.state_changed.connect(_on_state_changed)
	if enemy_combat:
		enemy_combat.attack_started.connect(_on_enemy_attack_started)
		enemy_combat.attack_activated.connect(_on_enemy_attack_activated)
	var player_combat := body.find_child("PlayerCombatController", true, false) as PlayerCombatController
	if player_combat:
		player_combat.dagger_used.connect(_on_player_dagger)
		player_combat.caster_fired.connect(_on_player_caster)
	if health: health.damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	if not visuals or not controller: return
	var horizontal_speed := absf(controller.velocity.x)
	var on_floor := body.is_on_floor()
	var floating := body.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING
	var moving := on_floor and horizontal_speed > 8.0
	if moving: _run_time += delta * (8.0 + horizontal_speed / 45.0)
	if floating: _run_time += delta * 3.5
	var bob := sin(_run_time) * run_bob_height if moving or floating else 0.0
	var lean_target := clampf(controller.velocity.x / 500.0, -1.0, 1.0) * max_lean
	var locomotion_scale := Vector2.ONE
	if not on_floor:
		var vertical_stretch := clampf(absf(controller.velocity.y) / 900.0, 0.0, 0.14)
		locomotion_scale = Vector2(1.0 - vertical_stretch * 0.45, 1.0 + vertical_stretch)
	elif moving:
		locomotion_scale = Vector2(1.0 + cos(_run_time) * 0.025, 1.0 - cos(_run_time) * 0.025)
	_hurt_offset = _hurt_offset.move_toward(Vector2.ZERO, 90.0 * delta)
	var facing_sign := controller.facing_direction if controller.character_visual == visuals else 1.0
	var target_scale := locomotion_scale * _action_scale
	target_scale.x *= facing_sign
	visuals.position = _base_position + Vector2(0.0, bob) + _action_offset + _hurt_offset
	visuals.rotation = lerp_angle(visuals.rotation, lean_target + _action_rotation, 1.0 - exp(-14.0 * delta))
	visuals.scale = visuals.scale.lerp(target_scale, 1.0 - exp(-18.0 * delta))


func _on_movement_action(action: StringName, _pitch: StringName) -> void:
	match action:
		&"ground_jump", &"double_jump", &"wall_jump", &"propulsor_step":
			_pulse(Vector2(0.82, 1.22), Vector2(0.0, 3.0), 0.13)
		&"ground_dash", &"air_dash":
			_pulse(Vector2(1.28, 0.72), Vector2(-controller.facing_direction * 5.0, 0.0), 0.18)
		&"slide":
			_pulse(Vector2(1.2, 0.68), Vector2(0.0, 7.0), 0.22)


func _on_landed() -> void:
	_pulse(Vector2(1.22, 0.72), Vector2(0.0, 5.0), 0.16)


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if current == &"WallSlide":
		_pulse(Vector2(0.88, 1.1), Vector2(controller.facing_direction * 3.0, 0.0), 0.12)


func _on_player_dagger(_type: StringName) -> void:
	_action_rotation = controller.facing_direction * 0.16
	_pulse(Vector2(1.18, 0.86), Vector2(controller.facing_direction * 5.0, 0.0), 0.12)
	create_tween().tween_property(self, "_action_rotation", 0.0, 0.14).set_trans(Tween.TRANS_BACK)


func _on_player_caster(_direction: Vector2, _damage: int) -> void:
	_pulse(Vector2(0.9, 1.1), Vector2(-controller.facing_direction * 4.0, 0.0), 0.15)


func _on_enemy_attack_started() -> void:
	var direction := controller.facing_direction if controller else 1.0
	var duration := enemy_combat.windup_time if enemy_combat else 0.2
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_action_scale", Vector2(0.78, 1.18), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_action_offset", Vector2(-direction * 8.0, 2.0), duration).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "_action_rotation", -direction * 0.12, duration)


func _on_enemy_attack_activated() -> void:
	var direction := controller.facing_direction if controller else 1.0
	_action_scale = Vector2(1.32, 0.76)
	_action_offset = Vector2(direction * 9.0, 0.0)
	_action_rotation = direction * 0.13
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_action_scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_action_offset", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_action_rotation", 0.0, 0.2)


func _on_damaged(hit: HitData) -> void:
	var direction := -signf(hit.knockback.x)
	if is_zero_approx(direction): direction = -controller.facing_direction if controller else -1.0
	_hurt_offset = Vector2(direction * 6.0, -2.0)
	_pulse(Vector2(1.16, 0.82), Vector2.ZERO, 0.11)


func _pulse(target_scale: Vector2, target_offset: Vector2, duration: float) -> void:
	_action_scale = target_scale
	_action_offset = target_offset
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_action_scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_action_offset", Vector2.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
