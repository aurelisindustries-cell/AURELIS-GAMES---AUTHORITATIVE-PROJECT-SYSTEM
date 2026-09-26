@icon("res://addons/CutsceneSystem/icons/cutscene_node.png")
extends Node
class_name CutsceneRoot

signal next_dialogue

var cutscene_action: int = 0
var cutscene_running: bool = false
var _pending_action_index: int = -1



func start_cutscene() -> void:
	if cutscene_running:
		return
	Cuts.cutscene_started.emit()
	cutscene_action = 0
	_pending_action_index = -1
	run_cutscene()


func stop_cutscene() -> void:
	cutscene_running = false


func request_label_jump(label: String) -> bool:
	for index in get_child_count():
		var child := get_child(index)
		if child.name == label or _node_label_matches(child, label):
			_pending_action_index = index
			return true
	return false


func _node_label_matches(node: Node, label: String) -> bool:
	for property in node.get_property_list():
		if property.name == &"label_name":
			return node.get("label_name") == label
	return false

func run_cutscene() -> void:
	cutscene_running = true
	while cutscene_running:
		if cutscene_action >= get_child_count():
			cutscene_running = false
			Cuts.cutscene_ended.emit()
			return

		var node: CutsceneNode = get_child(cutscene_action)
		if node.wait_to_finish:
			var action_finished := [false]
			node.action_done.connect(func() -> void: action_finished[0] = true, CONNECT_ONE_SHOT)
			node.do_action()
			if not action_finished[0]:
				await node.action_done
		else:
			node.do_action()
			await get_tree().create_timer(node.wait_time).timeout

		if not cutscene_running:
			return
		if _pending_action_index >= 0:
			cutscene_action = _pending_action_index
			_pending_action_index = -1
		else:
			cutscene_action += 1
		
