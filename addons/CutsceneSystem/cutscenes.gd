@icon("res://addons/CutsceneSystem/icons/cutscene_node.png")
extends Node
class_name Cutscenes


func _ready() -> void:
	for child in get_children():
		if child is CutsceneRoot:
			Cuts.cutscene_nodes[child.name] = child
	_connect_branch_signals(self)


func _connect_branch_signals(node: Node) -> void:
	for child in node.get_children():
		if child.has_signal("change_cutscene"):
			var cutscene_callback := change_cutscene.bind(child)
			if not child.is_connected("change_cutscene", cutscene_callback):
				child.connect("change_cutscene", cutscene_callback)

		if child.has_signal("change_label"):
			var label_callback := change_label.bind(child)
			if not child.is_connected("change_label", label_callback):
				child.connect("change_label", label_callback)

		_connect_branch_signals(child)


func change_cutscene(destination: CutsceneRoot, source: Node) -> void:
	if not is_instance_valid(destination):
		return

	var current := _find_cutscene_root(source)
	if is_instance_valid(current):
		current.stop_cutscene()

	destination.call_deferred("start_cutscene")


func change_label(label: String, source: Node) -> void:
	if label.is_empty():
		return
	var current := _find_cutscene_root(source)
	if is_instance_valid(current):
		current.request_label_jump(label)


func _find_cutscene_root(node: Node) -> CutsceneRoot:
	var current := node
	while is_instance_valid(current):
		if current is CutsceneRoot:
			return current
		current = current.get_parent()
	return null
