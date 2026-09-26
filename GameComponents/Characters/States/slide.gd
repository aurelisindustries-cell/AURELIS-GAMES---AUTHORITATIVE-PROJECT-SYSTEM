extends State

@export var speed: float = 360.0
@export var duration: float = 0.25
@export_range(26.0, 64.0, 1.0) var collider_height: float = 28.0
@export var jump_velocity: float = -420.0
@export var tunnel_exit_carry: float = 0.10

var remaining := 0.0
var tunnel_exit_remaining := -1.0
var extended_by_tunnel := false

func enter() -> void:
	var controller := character as CharacterController
	if not controller: return
	remaining = duration
	tunnel_exit_remaining = -1.0
	extended_by_tunnel = false
	controller.set_slide_collider(true, collider_height)
	controller.emit_movement_action(&"slide", &"")
	controller.velocity.x = controller.facing_direction * speed

func exit() -> void:
	var controller := character as CharacterController
	if controller: controller.set_slide_collider(false)

func physics_update(delta: float) -> void:
	var controller := character as CharacterController
	if not controller: return
	remaining -= delta
	controller.velocity.x = controller.facing_direction * speed
	if controller.consume_jump(): controller.start_ground_jump(jump_velocity); controller.state_machine.change_state("Airborne"); return
	if not controller.controlling.is_on_floor(): controller.state_machine.change_state("Airborne"); return
	if remaining > 0.0:
		return
	if not controller.can_stand():
		extended_by_tunnel = true
		tunnel_exit_remaining = -1.0
		return
	if extended_by_tunnel:
		if tunnel_exit_remaining < 0.0:
			tunnel_exit_remaining = tunnel_exit_carry
		tunnel_exit_remaining -= delta
		if tunnel_exit_remaining > 0.0:
			return
	controller.state_machine.change_state("Walk" if absf(controller.input_direction.x) > 0.01 else "Idle")
