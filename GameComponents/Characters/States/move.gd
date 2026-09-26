extends State

@export var speed: float = 240.0
@export var acceleration: float = 3000.0
@export var jump_velocity: float = -420.0

func physics_update(delta: float) -> void:
	var controller := character as CharacterController
	if not controller or not controller.controlling: return
	if not controller.controlling.is_on_floor(): controller.state_machine.change_state("Airborne"); return
	if controller.consume_jump(): controller.start_ground_jump(jump_velocity); controller.state_machine.change_state("Airborne"); return
	if controller.consume_slide() and controller.has_slide: controller.state_machine.change_state("Slide"); return
	if controller.consume_dash() and controller.has_dash: controller.state_machine.change_state("Dash"); return
	var target := controller.input_direction.x * speed * controller.movement_speed_multiplier
	controller.velocity.x = move_toward(controller.velocity.x, target, acceleration * delta)
	if is_zero_approx(controller.input_direction.x): controller.state_machine.change_state("Idle")
