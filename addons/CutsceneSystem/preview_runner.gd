extends Node


func _ready() -> void:
	var preview_path := OS.get_environment("GODOT_CUTSCENE_PREVIEW_PATH")
	if preview_path.is_empty():
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var scene_root := get_tree().current_scene
	var cutscene := scene_root.get_node_or_null(NodePath(preview_path)) as CutsceneRoot
	if not cutscene:
		push_error("Cutscene System: could not find CutsceneRoot at '%s'." % preview_path)
		return

	cutscene.start_cutscene()
