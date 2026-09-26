@tool
extends CutsceneNode
class_name SetFlag

@export var flag_name: String = "FLAG"
@export var flag_value: Variant

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if flag_name.is_empty():
		name = "Give flag a name"
	elif flag_value == null:
		name = "Give flag a value"
	else:
		var value_text := str(flag_value)
		name = "Set%sTo%s" % [
			flag_name.left(1).to_upper() + flag_name.substr(1),
			value_text.left(1).to_upper() + value_text.substr(1),
		]

func do_action() -> void:
	Prog.update_flag(flag_name, flag_value)
	action_done.emit()
