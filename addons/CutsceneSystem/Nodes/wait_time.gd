@icon("res://addons/CutsceneSystem/icons/cutscene_wait.png")
@tool
extends CutsceneNode
class_name CutsceneWaitTime

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		name = "WaitTime-" + str(wait_time) + " 01"
		

func do_action() -> void:
	await get_tree().create_timer(wait_time).timeout
	action_done.emit()
