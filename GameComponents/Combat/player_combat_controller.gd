@icon("res://addons/at-icons/node2d/swords.svg")
extends Node2D
class_name PlayerCombatController

signal caster_fired(direction: Vector2, damage: int)
signal dagger_used(attack_type: StringName)
signal dagger_phase_changed(phase: StringName, attack_type: StringName)
signal ability_requested
signal core_previous_requested
signal core_next_requested
signal core_wheel_requested(open: bool, direction: int)
signal overclock_requested
signal caster_module_requested(slot: int)
signal dagger_module_requested(slot: int)

@export var character_controller: CharacterController
@export var state_machine: StateMachine
@export var projectile_scene: PackedScene
@export var dagger_hitbox: HitboxComponent2D
@export var dagger_visual_scene: PackedScene
@export var caster_aim_rig: Node2D
@export var caster_muzzle: Marker2D
@export var aim_indicator: AimIndicator2D
@export var combat_animation_player: AnimationPlayer
@export var authored_hitbox_spawner: HitboxSpawner2D
@export var attack_visual_rig: Node2D
@export var caster_burst_scene: PackedScene

@export_category("Arc Caster")
@export var caster_damage: int = 1
@export var dash_shot_bonus_damage: int = 1
@export var caster_cooldown: float = 0.16
@export var caster_buffer_time: float = 0.15
@export_range(1, 12, 1) var max_active_projectiles: int = 3
@export var projectile_spawn_offset: float = 24.0
@export_enum("piercing", "spread", "guided") var left_caster_module: String = "piercing"
@export_enum("piercing", "spread", "guided") var right_caster_module: String = "spread"
@export var charged_damage_multiplier: float = 2.0
@export var guided_turn_strength: float = 7.0
@export var spread_angle_degrees: float = 14.0

@export_category("Arc Dagger")
@export var dagger_damage: int = 1
@export var dagger_buffer_time: float = 0.18
@export var dagger_forward_offset: float = 24.0
@export var dagger_vertical_offset: float = 30.0
@export_range(0, 2, 1) var dagger_combo_upgrades: int = 0
@export var dagger_combo_window: float = 0.38

var aim_direction := Vector2.ZERO
var _caster_buffer := 0.0
var _dagger_buffer := 0.0
var _caster_cooldown := 0.0
enum DaggerPhase { READY, STARTUP, ACTIVE, RECOVERY }

var _dagger_phase := DaggerPhase.READY
var _dagger_combo_remaining := 0.0
var _dagger_combo_step := 0
var _dagger_chain_queued := false
var _pending_dagger_hit: HitData
var _active_projectiles := 0
var _dash_shot_used := false
var _pending_caster_module: String = ""
var _current_dagger_type: StringName = &"normal"


func _ready() -> void:
	if not character_controller:
		character_controller = get_parent().find_child("CharacterController", true, false) as CharacterController
	if not state_machine:
		state_machine = get_parent().find_child("StateMachine", true, false) as StateMachine
	if state_machine:
		state_machine.state_changed.connect(_on_state_changed)
	if dagger_hitbox:
		dagger_hitbox.hit_landed.connect(_on_dagger_hit)
	if authored_hitbox_spawner:
		authored_hitbox_spawner.hit_landed.connect(_on_authored_hitbox_landed)
	if combat_animation_player:
		combat_animation_player.animation_finished.connect(_on_combat_animation_finished)


func _process(delta: float) -> void:
	_update_aim_rig()
	_caster_buffer = maxf(_caster_buffer - delta, 0.0)
	_dagger_buffer = maxf(_dagger_buffer - delta, 0.0)
	_caster_cooldown = maxf(_caster_cooldown - delta, 0.0)
	_dagger_combo_remaining = maxf(_dagger_combo_remaining - delta, 0.0)
	if _caster_buffer > 0.0 and _caster_cooldown <= 0.0 and _active_projectiles < max_active_projectiles:
		_fire_caster()
	if _dagger_buffer > 0.0 and _dagger_phase == DaggerPhase.READY:
		_begin_dagger_attack()


func update_aim(direction: Vector2) -> void:
	aim_direction = direction.normalized() if direction.length() >= 0.35 else Vector2.ZERO
	_update_aim_rig()


func _get_fire_direction() -> Vector2:
	if aim_direction != Vector2.ZERO:
		return _snap_to_eight_directions(aim_direction)
	return Vector2(character_controller.facing_direction, 0.0)


func _update_aim_rig() -> void:
	if not character_controller:
		return
	var direction := _get_fire_direction()
	if caster_aim_rig:
		caster_aim_rig.rotation = direction.angle()
	if aim_indicator:
		aim_indicator.set_engaged(aim_direction != Vector2.ZERO)
	if attack_visual_rig:
		attack_visual_rig.scale.x = absf(attack_visual_rig.scale.x) * character_controller.facing_direction
	if authored_hitbox_spawner:
		authored_hitbox_spawner.scale.x = absf(authored_hitbox_spawner.scale.x) * character_controller.facing_direction


func request_caster(module_slot: int = 0) -> void:
	if module_slot > 0:
		caster_module_requested.emit(module_slot)
		_pending_caster_module = left_caster_module if module_slot == 1 else right_caster_module
	else:
		_pending_caster_module = ""
	_caster_buffer = caster_buffer_time


func fire_charged_caster() -> void:
	_fire_caster(charged_damage_multiplier)


func request_dagger(module_slot: int = 0) -> void:
	if module_slot > 0:
		dagger_module_requested.emit(module_slot)
		return
	if _dagger_phase == DaggerPhase.READY:
		_dagger_buffer = dagger_buffer_time
	else:
		_dagger_chain_queued = true


func request_ability() -> void:
	ability_requested.emit()


func request_previous_core() -> void:
	core_previous_requested.emit()


func request_next_core() -> void:
	core_next_requested.emit()


func open_core_wheel(direction: int) -> void:
	core_wheel_requested.emit(true, direction)


func close_core_wheel() -> void:
	core_wheel_requested.emit(false, 0)


func request_overclock() -> void:
	overclock_requested.emit()


func _fire_caster(damage_multiplier: float = 1.0) -> void:
	if not projectile_scene or not character_controller:
		_caster_buffer = 0.0
		return
	var direction := _get_fire_direction()
	var damage := maxi(roundi(caster_damage * damage_multiplier), 1)
	if state_machine and state_machine.current_state and state_machine.current_state.name == &"Dash" and not _dash_shot_used:
		damage += dash_shot_bonus_damage
		_dash_shot_used = true
	var hit := HitData.new()
	hit.damage = damage
	hit.attack_type = &"caster"
	hit.faction = &"player"
	match _pending_caster_module:
		"spread":
			var spread := deg_to_rad(spread_angle_degrees)
			_spawn_caster_projectile(direction.rotated(-spread), hit)
			_spawn_caster_projectile(direction, hit)
			_spawn_caster_projectile(direction.rotated(spread), hit)
		"piercing":
			_spawn_caster_projectile(direction, hit, 1, true)
		"guided":
			_spawn_caster_projectile(direction, hit, 0, false, guided_turn_strength)
		_:
			_spawn_caster_projectile(direction, hit)
	_spawn_caster_burst()
	_animate_caster_recoil()
	_caster_buffer = 0.0
	_caster_cooldown = caster_cooldown
	caster_fired.emit(direction, damage)
	_pending_caster_module = ""


func _spawn_caster_projectile(direction: Vector2, hit: HitData, pierce: int = 0, terrain_piercing: bool = false, homing: float = 0.0) -> void:
	if _active_projectiles >= max_active_projectiles:
		return
	var projectile := projectile_scene.instantiate() as CombatProjectile2D
	if not projectile:
		return
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = caster_muzzle.global_position if caster_muzzle else global_position + direction * projectile_spawn_offset
	projectile.setup(direction, hit, character_controller.controlling, pierce, terrain_piercing, homing)
	_active_projectiles += 1
	projectile.tree_exited.connect(_on_projectile_removed)


func _spawn_caster_burst() -> void:
	if not caster_burst_scene or not caster_muzzle:
		return
	var burst := caster_burst_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(burst)
	burst.global_position = caster_muzzle.global_position


func _animate_caster_recoil() -> void:
	if not caster_aim_rig:
		return
	caster_aim_rig.scale = Vector2(0.82, 1.18)
	create_tween().tween_property(caster_aim_rig, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _begin_dagger_attack() -> void:
	if not dagger_hitbox or not character_controller:
		_dagger_buffer = 0.0
		return
	var airborne := not character_controller.controlling.is_on_floor()
	_current_dagger_type = &"normal"
	if _dagger_combo_remaining <= 0.0 or _dagger_combo_step >= dagger_combo_upgrades:
		_dagger_combo_step = 0
	elif dagger_combo_upgrades > 0:
		_dagger_combo_step = mini(_dagger_combo_step + 1, dagger_combo_upgrades)
	var offset := Vector2(character_controller.facing_direction * dagger_forward_offset, -20.0)
	if character_controller.true_input_direction.y < -0.5:
		_current_dagger_type = &"up_slash"
		_dagger_combo_step = 0
		offset = Vector2(0.0, -dagger_vertical_offset - 20.0)
		if airborne:
			character_controller.velocity.y = minf(character_controller.velocity.y, -90.0)
	elif airborne and character_controller.true_input_direction.y > 0.5:
		_current_dagger_type = &"downstab"
		_dagger_combo_step = 0
		offset = Vector2(0.0, dagger_vertical_offset)
	elif _dagger_combo_step == 1:
		_current_dagger_type = &"normal_2"
	elif _dagger_combo_step == 2:
		_current_dagger_type = &"normal_3"
	dagger_hitbox.position = offset
	var hit := HitData.new()
	hit.damage = dagger_damage
	hit.attack_type = _current_dagger_type
	hit.hit_stop = 0.035
	if _dagger_combo_step == 1:
		hit.reaction = &"forced_stagger"
		hit.reaction_duration = 0.2
	elif _dagger_combo_step == 2:
		hit.reaction = &"launch"
		hit.knockback = Vector2(0.0, -280.0)
	_pending_dagger_hit = hit
	_play_dagger_animation(_current_dagger_type)
	_dagger_phase = DaggerPhase.STARTUP
	_dagger_buffer = 0.0
	_spawn_dagger_visual(_current_dagger_type)
	dagger_phase_changed.emit(&"startup", _current_dagger_type)
	dagger_used.emit(_current_dagger_type)


func _spawn_dagger_visual(type: StringName, position_offset := Vector2.ZERO, attach_to_player: bool = true) -> void:
	if not dagger_visual_scene or not character_controller or not character_controller.controlling:
		return
	var visual := dagger_visual_scene.instantiate() as DaggerSlashVisual2D
	if not visual:
		return
	if attach_to_player:
		character_controller.controlling.add_child(visual)
		visual.position = Vector2(0.0, -22.0) + position_offset
	else:
		get_tree().current_scene.add_child(visual)
		visual.global_position = character_controller.controlling.global_position + Vector2(0.0, -22.0) + position_offset
	visual.setup(type, character_controller.facing_direction)


func _play_dagger_animation(type: StringName) -> void:
	if not combat_animation_player:
		return
	if authored_hitbox_spawner:
		for child in authored_hitbox_spawner.get_children():
			if child is HitboxAuthoringHandle2D:
				(child as HitboxAuthoringHandle2D).active = false
	var animation_name := StringName("dagger_%s" % type)
	if combat_animation_player.has_animation(animation_name):
		combat_animation_player.play(animation_name)


func _on_combat_animation_finished(animation_name: StringName) -> void:
	if not String(animation_name).begins_with("dagger_"):
		return
	_dagger_phase = DaggerPhase.READY
	_dagger_combo_remaining = dagger_combo_window if _current_dagger_type.begins_with("normal") else 0.0
	dagger_phase_changed.emit(&"ready", _current_dagger_type)
	if _dagger_chain_queued:
		_dagger_chain_queued = false
		_dagger_buffer = dagger_buffer_time


func _on_authored_hitbox_landed(data: HitboxFrameData, hurtbox: HurtboxComponent2D, hit: HitData) -> void:
	_current_dagger_type = StringName(String(data.animation).trim_prefix("dagger_"))
	_on_dagger_hit(hurtbox, hit)


func _on_dagger_hit(_hurtbox: HurtboxComponent2D, _hit: HitData) -> void:
	if not character_controller or character_controller.controlling.is_on_floor():
		return
	character_controller.register_airborne_dagger_hit()
	if _current_dagger_type == &"downstab":
		_spawn_dagger_visual(&"downstab_impact", Vector2(0.0, 42.0), false)
		character_controller.perform_downstab_rebound()


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if current == &"Dash":
		_dash_shot_used = false


func _on_projectile_removed() -> void:
	_active_projectiles = maxi(_active_projectiles - 1, 0)


func _snap_to_eight_directions(direction: Vector2) -> Vector2:
	var step := PI / 4.0
	return Vector2.RIGHT.rotated(roundf(direction.angle() / step) * step)
