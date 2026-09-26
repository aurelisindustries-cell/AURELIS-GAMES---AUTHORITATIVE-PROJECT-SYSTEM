extends Node2D
class_name CutsceneCameras

func _ready() -> void:
	Cuts.cutscene_cameras = self

func clear_cameras() -> void:
	for camera in get_children():
		if camera is CutsceneVirtualCamera2D and not camera.is_player_camera:
			camera.queue_free()
