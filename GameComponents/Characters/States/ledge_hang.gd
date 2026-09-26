extends State

@export var vault_height: float = 56.0
@export var vault_forward_distance: float = 24.0
@export var vault_exit_speed: float = 240.0
@export var release_speed: float = 40.0

func enter() -> void:
	var controller := character as CharacterController
	if controller:
		controller.velocity = Vector2.ZERO
		controller.snap_to_ledge_wall()

func physics_update(_delta: float) -> void:
	var controller := character as CharacterController
	if not controller: return
	controller.velocity = Vector2.ZERO
	if controller.input_direction.y > 0.5 and controller.consume_jump():
		controller.velocity.y = release_speed; controller.state_machine.change_state("Airborne"); return
	if controller.input_direction.y < -0.5 or controller.jump_buffer_remaining > 0.0:
		controller.consume_jump()
		controller.controlling.global_position += Vector2(controller.facing_direction * vault_forward_distance, -vault_height)
		controller.velocity = Vector2(controller.facing_direction * vault_exit_speed, 0.0)
		controller.state_machine.change_state("Walk")
