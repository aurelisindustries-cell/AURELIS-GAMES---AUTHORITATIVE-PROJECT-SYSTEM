extends State

@export var slide_speed: float = 80.0
@export var gravity: float = 1100.0
@export var duration: float = 0.45
@export var jump_push: float = 320.0
@export var jump_velocity: float = -420.0

var remaining := 0.0

func enter() -> void:
	remaining = duration

func physics_update(delta: float) -> void:
	var controller := character as CharacterController
	if not controller or not controller.controlling: return
	if controller.controlling.is_on_floor(): controller.state_machine.change_state("Idle"); return
	if controller.can_catch_ledge(): controller.state_machine.change_state("LedgeHang"); return
	remaining -= delta
	if not controller.controlling.is_on_wall() or remaining <= 0.0: controller.state_machine.change_state("Airborne"); return
	if controller.is_pressing_away_from_wall(): controller.state_machine.change_state("Airborne"); return
	controller.velocity.y = minf(controller.velocity.y + gravity * delta, slide_speed)
	if controller.consume_jump():
		if controller.perform_wall_jump(jump_push, jump_velocity):
			controller.state_machine.change_state("Airborne")
		return
	if controller.consume_dash() and controller.has_air_dash and controller.can_air_dash:
		controller.facing_direction = controller.controlling.get_wall_normal().x
		controller.state_machine.change_state("Dash")
