extends State

@export var air_speed: float = 240.0
@export var air_acceleration: float = 1200.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0
@export var fall_gravity: float = 1450.0
@export var terminal_velocity: float = 900.0
@export_range(0.0, 1.0) var jump_release_multiplier: float = 0.5

func physics_update(delta: float) -> void:
	var controller := character as CharacterController
	if not controller or not controller.controlling: return
	if controller.controlling.is_on_floor() and controller.velocity.y >= 0.0:
		controller.state_machine.change_state("Walk" if absf(controller.input_direction.x) > 0.01 else "Idle"); return
	if controller.consume_dash() and controller.has_air_dash and controller.can_air_dash:
		controller.state_machine.change_state("Dash"); return
	if controller.jump_buffer_remaining > 0.0 and controller.controlling.is_on_wall() and controller.perform_wall_jump():
		return
	if controller.consume_jump():
		if controller.coyote_remaining > 0.0: controller.start_ground_jump(jump_velocity)
		else: controller.try_air_jump(jump_velocity)
	if controller.jump_cut_requested:
		controller.jump_cut_requested = false
		if controller.velocity.y < 0.0: controller.velocity.y *= jump_release_multiplier
	if controller.can_catch_ledge(): controller.state_machine.change_state("LedgeHang"); return
	if controller.has_wall_slide and controller.controlling.is_on_wall() and controller.velocity.y > 0.0:
		controller.state_machine.change_state("WallSlide"); return
	var target := controller.input_direction.x * air_speed
	if controller.carrying_dash_momentum:
		var opposing_dash := absf(controller.input_direction.x) > 0.01 and signf(controller.input_direction.x) != signf(controller.velocity.x)
		if opposing_dash:
			controller.carrying_dash_momentum = false
		elif absf(controller.velocity.x) > air_speed:
			target = controller.velocity.x
		else:
			controller.carrying_dash_momentum = false
	controller.velocity.x = move_toward(controller.velocity.x, target, air_acceleration * delta)
	var active_gravity := gravity if controller.velocity.y < 0.0 else fall_gravity
	controller.velocity.y = minf(controller.velocity.y + active_gravity * delta, terminal_velocity)
