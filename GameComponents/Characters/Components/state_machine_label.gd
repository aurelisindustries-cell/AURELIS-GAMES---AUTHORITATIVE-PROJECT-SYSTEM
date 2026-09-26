extends Label
class_name StateMachineLabel

@export var state_machine: StateMachine
@export var controller: CharacterController
@export var show_movement_details: bool = true


func _ready() -> void:
	if not state_machine:
		state_machine = get_parent().find_child("StateMachine", true, false) as StateMachine
	if not controller:
		controller = get_parent().find_child("CharacterController", true, false) as CharacterController
	_update_text()


func _process(_delta: float) -> void:
	_update_text()


func _update_text() -> void:
	if not state_machine:
		text = "State: Unavailable"
		return
	var state_name := "None"
	if state_machine.current_state:
		state_name = state_machine.current_state.name
	text = "State: %s" % state_name
	if not show_movement_details or not controller:
		return
	var grounded := controller.controlling != null and controller.controlling.is_on_floor()
	text += "\nVelocity: (%d, %d)" % [roundi(controller.velocity.x), roundi(controller.velocity.y)]
	text += "\nGrounded: %s" % ("Yes" if grounded else "No")
	text += "\nFacing: %s" % ("Right" if controller.facing_direction > 0.0 else "Left")
	text += "\nDouble Jump: %s" % ("Ready" if controller.can_double_jump else "Spent")
	text += "\nAir Dash: %s" % ("Ready" if controller.can_air_dash else "Spent")
	text += "\nPropulsor Step: %s" % ("Ready" if controller.propulsor_jump_available else "Empty")
