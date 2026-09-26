extends State

@export var speed: float = 480.0
@export var duration: float = 0.20

var remaining := 0.0
var air_dash := false

func enter() -> void:
	var controller := character as CharacterController
	if not controller or not controller.controlling: return
	remaining = duration
	air_dash = not controller.controlling.is_on_floor()
	if air_dash:
		controller.can_air_dash = false
		controller.velocity.y = 0.0
		controller.emit_movement_action(&"air_dash", &"4")
	else: controller.emit_movement_action(&"ground_dash", &"")
	controller.velocity.x = controller.facing_direction * speed

func physics_update(delta: float) -> void:
	var controller := character as CharacterController
	if not controller: return
	remaining -= delta
	controller.velocity.x = controller.facing_direction * speed
	if not air_dash and controller.consume_jump():
		controller.start_ground_jump(); controller.velocity.x = controller.facing_direction * speed
		controller.carrying_dash_momentum = true
		controller.state_machine.change_state("Airborne"); return
	if remaining <= 0.0:
		controller.state_machine.change_state("Airborne" if air_dash or not controller.controlling.is_on_floor() else "Walk")
