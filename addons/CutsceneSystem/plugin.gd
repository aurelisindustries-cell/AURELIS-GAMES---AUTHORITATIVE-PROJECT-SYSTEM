@tool
extends EditorPlugin

const PREVIEW_AUTOLOAD := "CutscenePreviewRunner"
const PREVIEW_RUNNER := "res://addons/CutsceneSystem/preview_runner.gd"

var inspector_plugin: EditorInspectorPlugin


func _enable_plugin() -> void:
	add_autoload_singleton(PREVIEW_AUTOLOAD, PREVIEW_RUNNER)


func _disable_plugin() -> void:
	remove_autoload_singleton(PREVIEW_AUTOLOAD)


func _enter_tree() -> void:
	inspector_plugin = CutscenePreviewInspector.new()
	inspector_plugin.preview_requested.connect(_preview_cutscene)
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)
		inspector_plugin = null


func _preview_cutscene(cutscene: CutsceneRoot) -> void:
	var edited_root := EditorInterface.get_edited_scene_root()
	if not edited_root or not edited_root.is_ancestor_of(cutscene):
		push_error("Cutscene System: the cutscene must belong to the currently edited scene.")
		return

	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()

	var save_error := EditorInterface.save_scene()
	if save_error != OK:
		push_error("Cutscene System: could not save the current scene.")
		return

	OS.set_environment("GODOT_CUTSCENE_PREVIEW_PATH", str(edited_root.get_path_to(cutscene)))
	EditorInterface.play_current_scene()
	OS.unset_environment("GODOT_CUTSCENE_PREVIEW_PATH")


class CutscenePreviewInspector extends EditorInspectorPlugin:
	signal preview_requested(cutscene: CutsceneRoot)

	func _can_handle(object: Object) -> bool:
		return object is CutsceneRoot

	func _parse_begin(object: Object) -> void:
		var button := Button.new()
		button.text = "Preview Cutscene"
		button.tooltip_text = "Save and run this scene, then play this cutscene automatically."
		button.icon = EditorInterface.get_editor_theme().get_icon("Play", "EditorIcons")
		button.pressed.connect(func() -> void: preview_requested.emit(object as CutsceneRoot))
		add_custom_control(button)
