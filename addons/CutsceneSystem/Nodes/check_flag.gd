@tool
extends CutsceneNode
class_name CheckFlag

signal change_cutscene(cutscene: CutsceneRoot)
signal change_label(label: String)
signal flag_checked(result: bool)

enum Comparison {
	EQUALS,
	NOT_EQUALS,
	GREATER_THAN,
	GREATER_THAN_OR_EQUAL,
	LESS_THAN,
	LESS_THAN_OR_EQUAL,
	EXISTS,
	DOES_NOT_EXIST,
}

@export var flag_name: String
@export var comparison: Comparison = Comparison.EQUALS:
	set(value):
		comparison = value
		notify_property_list_changed()
@export var value_to_check: Variant

@export_category("Destination")
@export var go_to_label: bool = true:
	set(value):
		go_to_label = value
		notify_property_list_changed()

@export var true_cutscene: CutsceneRoot
@export var false_cutscene: CutsceneRoot

@export var true_label: String
@export var false_label: String

var last_result: bool = false


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if flag_name.is_empty():
		name = "Give flag a name"
	elif _comparison_uses_value() and value_to_check == null:
		name = "Give flag a value"
	else:
		name = "Check%s%s" % [_title_case(flag_name), _comparison_suffix()]

func do_action() -> void:
	last_result = evaluate()
	flag_checked.emit(last_result)

	if go_to_label:
		change_label.emit(true_label if last_result else false_label)
	else:
		change_cutscene.emit(get_selected_cutscene())
	action_done.emit()


func get_selected_cutscene() -> CutsceneRoot:
	return true_cutscene if last_result else false_cutscene


func evaluate() -> bool:
	var exists := Prog.has_flag(flag_name)
	match comparison:
		Comparison.EXISTS:
			return exists
		Comparison.DOES_NOT_EXIST:
			return not exists

	if not exists:
		return false

	var current_value: Variant = Prog.check_flag(flag_name)
	match comparison:
		Comparison.EQUALS:
			return current_value == value_to_check
		Comparison.NOT_EQUALS:
			return current_value != value_to_check
		Comparison.GREATER_THAN:
			return _is_number(current_value) and _is_number(value_to_check) and current_value > value_to_check
		Comparison.GREATER_THAN_OR_EQUAL:
			return _is_number(current_value) and _is_number(value_to_check) and current_value >= value_to_check
		Comparison.LESS_THAN:
			return _is_number(current_value) and _is_number(value_to_check) and current_value < value_to_check
		Comparison.LESS_THAN_OR_EQUAL:
			return _is_number(current_value) and _is_number(value_to_check) and current_value <= value_to_check
	return false


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _comparison_uses_value() -> bool:
	return comparison != Comparison.EXISTS and comparison != Comparison.DOES_NOT_EXIST


func _comparison_suffix() -> String:
	if not _comparison_uses_value():
		return Comparison.keys()[comparison].to_pascal_case()
	return "%s%s" % [Comparison.keys()[comparison].to_pascal_case(), _title_case(str(value_to_check))]


func _title_case(value: String) -> String:
	if value.is_empty():
		return ""
	return value.left(1).to_upper() + value.substr(1)


func _validate_property(property: Dictionary) -> void:
	var property_name: StringName = property.name
	if property_name == &"value_to_check" and not _comparison_uses_value():
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property_name in [&"true_cutscene", &"false_cutscene"] and go_to_label:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property_name in [&"true_label", &"false_label"] and not go_to_label:
		property.usage = PROPERTY_USAGE_NO_EDITOR
