@icon("res://addons/CutsceneSystem/icons/cutscene_vfx.png")
@tool
extends CutsceneNode
class_name CutsceneVFXPlay

@export var vfx: PackedScene

func _process(delta: float) -> void:
	if vfx: 
		var path = vfx.get_path()
		name = path.right(-path.rfind("/") - 1).left(-5)
	else: name = "PleaseChooseAScene"

func do_action() -> void:
	var fx: VFXNode = vfx.instantiate()
	add_child(fx)
	fx.play_vfx()
	await fx.vfx_done
	fx.queue_free()
	if wait_to_finish: action_done.emit()
