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

@export_group("Caster upgrades")
@export var has_piercing_module: bool = true
@export var has_spread_module: bool = true
@export var has_guided_module: bool = true
@export var has_charged_caster: bool = true
@export var has_dash_shot: bool = true
@export var has_buster_v1: bool = false
@export var buster_charge_time: float = 0.5

@export_category("Arc Dagger")
@export var dagger_damage: int = 1
@export var dagger_buffer_time: float = 0.18
@export var dagger_forward_offset: float = 24.0
@export var dagger_vertical_offset: float = 30.0
@export_range(0, 2, 1) var dagger_combo_upgrades: int = 0
@export var dagger_combo_window: float = 0.38
@export var has_up_slash: bool = true
@export var has_downstab: bool = true
@export var has_pogo: bool = true
@export var has_extended_edge_1: bool = false
@export var has_extended_edge_2: bool = false
@export var has_reinforced_edge_1: bool = false
@export var has_reinforced_edge_2: bool = false
@export var edge_damage_per_tier: int = 2
@export var edge_reach_per_tier: float = 0.25

@export_category("Evolved Abilities")
@export var has_vine_whip: bool = false
@export var has_burrow: bool = false
@export_enum("vine_whip", "burrow") var selected_evolved := "vine_whip"
@export var burrow_speed := 150.0
@export var burrow_duration := 5.0
var burrow: Node2D
@export var vine_whip_damage: int = 4
@export var vine_whip_range: float = 220.0
@export var vine_whip_cooldown: float = 0.65

var _vine_cooldown := 0.0
var _vine: Node2D

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
var _charging := false
var _charge_elapsed := 0.0


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
	if character_controller and character_controller.controlling:
		var lifecycle := character_controller.controlling.find_child("PlayerLifecycleComponent", true, false)
		if lifecycle: lifecycle.respawn_started.connect(cancel_charge)
		burrow = preload("res://GameComponents/Combat/burrow_ability.gd").new()
		burrow.name = "BurrowAbility"
		character_controller.controlling.add_child.call_deferred(burrow)


func _process(delta: float) -> void:
	if selected_evolved == "burrow" and not has_burrow and has_vine_whip: selected_evolved = "vine_whip"
	if selected_evolved == "vine_whip" and not has_vine_whip and has_burrow: selected_evolved = "burrow"
	_vine_cooldown = maxf(0, _vine_cooldown - delta)
	if _charging:
		if not has_buster_v1 or not has_charged_caster:
			_charging = false
		else:
			_charge_elapsed += delta
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
		attack_visual_rig.scale = Vector2(character_controller.facing_direction, 1) * dagger_reach_multiplier()
	if authored_hitbox_spawner:
		authored_hitbox_spawner.scale.x = absf(authored_hitbox_spawner.scale.x) * character_controller.facing_direction


func request_caster(module_slot: int = 0) -> void:
	if character_controller and character_controller.burrowing: return
	_charging = has_buster_v1 and has_charged_caster and module_slot == 0
	_charge_elapsed = 0.0
	if module_slot > 0:
		caster_module_requested.emit(module_slot)
		_pending_caster_module = left_caster_module if module_slot == 1 else right_caster_module
		if not is_module_enabled(_pending_caster_module): _pending_caster_module = ""
	else:
		_pending_caster_module = ""
	_caster_buffer = caster_buffer_time


func fire_charged_caster() -> void:
	if not has_charged_caster: return
	_fire_caster(charged_damage_multiplier)


func release_caster() -> void:
	var ready := _charging and has_buster_v1 and has_charged_caster and _charge_elapsed >= buster_charge_time
	_charging = false
	_charge_elapsed = 0.0
	if ready and _caster_cooldown <= 0 and _active_projectiles < max_active_projectiles:
		_pending_caster_module = ""
		fire_charged_caster()


func cancel_charge() -> void:
	_charging = false
	_charge_elapsed = 0.0


func request_dagger(module_slot: int = 0) -> void:
	if character_controller and character_controller.burrowing: return
	if module_slot > 0:
		dagger_module_requested.emit(module_slot)
		return
	if _dagger_phase == DaggerPhase.READY:
		_dagger_buffer = dagger_buffer_time
	else:
		_dagger_chain_queued = true


func request_ability() -> void:
	ability_requested.emit()
	if is_instance_valid(burrow) and burrow.is_inside_tree() and burrow.active:
		burrow.finish()
		return
	if selected_evolved == "burrow" and has_burrow:
		if is_instance_valid(burrow) and burrow.is_inside_tree(): burrow.begin()
		return
	if not has_vine_whip and has_burrow:
		selected_evolved = "burrow"
		if is_instance_valid(burrow) and burrow.is_inside_tree(): burrow.begin()
		return
	if not has_vine_whip or _vine_cooldown > 0 or is_instance_valid(_vine) or not character_controller: return
	var body := character_controller.controlling
	if not body: return
	var health := body.find_child("HealthComponent", true, false) as HealthComponent
	var input := body.find_child("InputHandler2D", true, false) as InputHandler2D
	if (health and health.current_health <= 0) or (input and not input.can_input): return
	_vine = preload("res://GameComponents/Combat/vine_whip_2d.gd").new()
	body.add_child(_vine)
	_vine.setup(body, _get_fire_direction(), vine_whip_range, vine_whip_damage)
	_vine_cooldown = vine_whip_cooldown


func cancel_vine_whip() -> void:
	if is_instance_valid(_vine): _vine.queue_free()


func request_previous_core() -> void:
	core_previous_requested.emit()
	cycle_evolved()


func request_next_core() -> void:
	core_next_requested.emit()
	cycle_evolved()


func cycle_evolved() -> void:
	if character_controller and character_controller.burrowing: return
	if has_burrow and has_vine_whip: selected_evolved = "burrow" if selected_evolved == "vine_whip" else "vine_whip"
	elif has_burrow: selected_evolved = "burrow"
	else: selected_evolved = "vine_whip"


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
	if has_dash_shot and state_machine and state_machine.current_state and state_machine.current_state.name == &"Dash" and not _dash_shot_used:
		damage += dash_shot_bonus_damage
		_dash_shot_used = true
	var hit := HitData.new()
	hit.damage = damage
	hit.attack_type = &"caster"
	hit.faction = &"player"
	if not is_module_enabled(_pending_caster_module): _pending_caster_module = ""
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
	if has_up_slash and character_controller.true_input_direction.y < -0.5:
		_current_dagger_type = &"up_slash"
		_dagger_combo_step = 0
		offset = Vector2(0.0, -dagger_vertical_offset - 20.0)
		if airborne:
			character_controller.velocity.y = minf(character_controller.velocity.y, -90.0)
	elif has_downstab and airborne and character_controller.true_input_direction.y > 0.5:
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
	_pending_dagger_hit = upgraded_dagger_hit(hit)
	dagger_hitbox.scale = Vector2.ONE * dagger_reach_multiplier()
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
	visual.scale *= dagger_reach_multiplier()


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
	if has_pogo and _current_dagger_type == &"downstab":
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



func is_module_enabled(module: String) -> bool:
	match module:
		"piercing": return has_piercing_module
		"spread": return has_spread_module
		"guided": return has_guided_module
	return false


func upgraded_dagger_hit(hit: HitData) -> HitData:
	var result := hit.duplicate() as HitData
	result.damage += (int(has_reinforced_edge_1) + int(has_reinforced_edge_2)) * edge_damage_per_tier
	return result


func dagger_reach_multiplier() -> float:
	return 1.0 + (int(has_extended_edge_1) + int(has_extended_edge_2)) * edge_reach_per_tier
