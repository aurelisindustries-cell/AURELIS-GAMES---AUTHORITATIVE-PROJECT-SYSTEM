extends Node2D

var active := false
var soil: StaticBody2D
var body: CharacterBody2D
var controller: CharacterController
var combat: PlayerCombatController
var entry := Vector2.ZERO
var top := 0.0
var elapsed := 0.0
var old_visual_visibility := true
var old_hurtbox_enabled := true
var visuals: CanvasItem
var hurtbox: HurtboxComponent2D

func _ready() -> void:
	body = get_parent() as CharacterBody2D
	controller = body.find_child("CharacterController", true, false)
	combat = body.find_child("PlayerCombatController", true, false)
	visuals = body.get_node("Visuals")
	hurtbox = body.find_child("HurtboxComponent2D", true, false)
	var state := State.new()
	state.name = "Burrow"
	state.character = controller
	controller.state_machine.add_child(state)
	var lifecycle := body.find_child("PlayerLifecycleComponent", true, false)
	if lifecycle: lifecycle.respawn_started.connect(func(): finish(true))

func begin() -> bool:
	if active or not combat.has_burrow or not body.is_on_floor() or not controller.can_stand(): return false
	var input := body.find_child("InputHandler2D", true, false) as InputHandler2D
	var health := body.find_child("HealthComponent", true, false) as HealthComponent
	if not input.can_input or health.current_health <= 0: return false
	var query := PhysicsRayQueryParameters2D.create(body.global_position, body.global_position + Vector2(0, 48), 2, [body.get_rid()])
	var contact := get_world_2d().direct_space_state.intersect_ray(query)
	if contact.is_empty() or not contact.collider.is_in_group("burrow_soil"): return false
	soil = contact.collider
	# The supplied soil strip is axis-aligned and has clear entry/exit space above it.
	if not is_zero_approx(soil.global_rotation) or not soil.global_scale.is_equal_approx(Vector2.ONE): return false
	entry = body.global_position
	top = soil.global_position.y
	if absf(entry.x - soil.global_position.x) > 108: return false
	if not clear_at(Vector2(entry.x, top + 48)): return false
	old_visual_visibility = visuals.visible
	old_hurtbox_enabled = hurtbox.enabled
	body.add_collision_exception_with(soil)
	active = true
	controller.burrowing = true
	controller.state_machine.change_state("Burrow")
	controller.velocity = Vector2.ZERO
	body.global_position = Vector2(entry.x, top + 48)
	visuals.hide()
	hurtbox.enabled = false
	elapsed = 0
	combat.cancel_vine_whip()
	combat.cancel_charge()
	combat._caster_buffer = 0
	combat._dagger_buffer = 0
	if combat.combat_animation_player: combat.combat_animation_player.stop()
	if combat.authored_hitbox_spawner:
		for child in combat.authored_hitbox_spawner.get_children():
			if child is HitboxAuthoringHandle2D: child.active = false
	combat._dagger_phase = PlayerCombatController.DaggerPhase.READY
	return true

func clear_at(at: Vector2) -> bool:
	var collision := controller.body_collision
	if not collision or not collision.shape: return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.transform.origin += at - body.global_position
	query.collision_mask = 2
	var exclusions: Array[RID] = [body.get_rid()]
	if is_instance_valid(soil): exclusions.append(soil.get_rid())
	query.exclude = exclusions
	return get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func finish(force := false) -> bool:
	if not active: return true
	var destination := Vector2(body.global_position.x, entry.y)
	if not clear_at(destination):
		if not force: return false
		destination = entry
		if not clear_at(destination): return false
	active = false
	controller.burrowing = false
	if is_instance_valid(soil): body.remove_collision_exception_with(soil)
	body.global_position = destination
	body.velocity = Vector2.ZERO
	controller.velocity = Vector2.ZERO
	controller.jump_buffer_remaining = 0
	controller.dash_requested = false
	controller.slide_requested = false
	visuals.visible = old_visual_visibility
	hurtbox.enabled = old_hurtbox_enabled
	controller.state_machine.change_state("Airborne")
	queue_redraw()
	return true

func _physics_process(delta: float) -> void:
	if not active: return
	var input := body.find_child("InputHandler2D", true, false) as InputHandler2D
	if not combat.has_burrow or not is_instance_valid(soil) or not input.can_input:
		finish(true); return
	elapsed += delta
	if controller.jump_buffer_remaining > 0 or elapsed >= combat.burrow_duration:
		controller.jump_buffer_remaining = 0
		if finish(): return
	var desired_x := clampf(body.global_position.x + controller.input_direction.x * combat.burrow_speed * delta, soil.global_position.x - 108, soil.global_position.x + 108)
	body.move_and_collide(Vector2(desired_x - body.global_position.x, 0))
	queue_redraw()

func _draw() -> void:
	if not active: return
	var surface := to_local(Vector2(body.global_position.x, top))
	draw_arc(surface, 17, PI, TAU, 20, Color(0.75, 0.5, 0.22), 5, true)
	for i in 5:
		var offset := Vector2((i - 2) * 9, -5 - absf(sin(elapsed * 12 + i)) * 10)
		draw_circle(surface + offset, 2, Color(0.85, 0.65, 0.35))
