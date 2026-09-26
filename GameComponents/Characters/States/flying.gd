extends State
class_name FlyingState

@export var speed: float = 100.0
@export var acceleration: float = 700.0
@export var deceleration: float = 900.0


func physics_update(delta: float) -> void:
	var controller := character as CharacterController
	if not controller or not controller.controlling: return
	var target := controller.input_direction * speed * controller.movement_speed_multiplier
	var rate := acceleration if not controller.input_direction.is_zero_approx() else deceleration
	controller.velocity = controller.velocity.move_toward(target, rate * delta)
