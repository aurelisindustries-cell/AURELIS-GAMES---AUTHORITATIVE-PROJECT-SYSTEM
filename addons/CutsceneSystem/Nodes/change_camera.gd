@icon("res://addons/CutsceneSystem/icons/cutscene_camera.png")
@tool
extends CutsceneNode
class_name CutsceneCamera

@export var reset_camera: bool:
	set(value):
		reset_camera = value
		property_list_changed.emit()

@export var follow_camera: bool:
	set(value):
		follow_camera = value
		property_list_changed.emit()

@export_category("Properties")
@export var transition: CutsceneCameraTransition = CutsceneCameraTransition.new()
@export var zoom: Vector2 = Vector2(1,1)
@export var cam_rotation: float = 0.0

@export_category("Follow")
@export var target: Node2D
@export var follow_offset: Vector2 = Vector2(0,-190)
@export var follow_dampening: bool = true
@export var follow_dampening_value: Vector2 = Vector2(0.2,0.2)
@export var rotate_with_target: bool = false

####### EDITOR ONLY
var cam_shown: bool = false
var is_reset: bool = false
var cam: Camera2D

const hide_props : Array[StringName] = [&"follow_camera",&"zoom",&"cam_rotation"]
const follow_props : Array[StringName] = [&"target", &"follow_offset",&"follow_dampening", &"follow_dampening_value",&"rotate_with_target"]


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if !reset_camera:
			if !cam_shown:
				cam = Camera2D.new()
				add_child(cam)
				cam_shown = true
				is_reset = false
			cam.zoom = zoom
			if follow_camera:
				if target:
					name = "CameraFollow" + target.name
				else:
					name = "CooseFollowTarget"
			else:
				name = "MoveCameraTo(X" + str(int(global_position.x)) + ",Y" + str(int(global_position.y)) + ")"
		if reset_camera and !is_reset and cam_shown:
			cam.queue_free()
			name = "ResetCamera"
			is_reset = true
			cam_shown = false


func do_action() -> void:
	if not is_instance_valid(Cuts.camera_controller):
		push_error("Cutscene System: no CutsceneCameraController2D exists in the scene.")
		action_done.emit()
		return
	if not is_instance_valid(Cuts.cutscene_cameras):
		Cuts.camera_controller._setup_camera_system()
	var transition_duration := transition.duration if transition else 0.0

	if reset_camera:
		if not is_instance_valid(Cuts.player_camera):
			push_error("Cutscene System: no player virtual camera is configured.")
			action_done.emit()
			return
		Cuts.camera_controller.transition_to(Cuts.player_camera, transition)
		if transition_duration > 0.0:
			await Cuts.camera_controller.transition_finished
		if is_instance_valid(Cuts.cutscene_cameras):
			Cuts.cutscene_cameras.clear_cameras()
		action_done.emit()
	else:
		var cam := CutsceneVirtualCamera2D.new()
		cam.global_position = global_position
		cam.camera_zoom = zoom
		cam.camera_rotation = cam_rotation
		if follow_camera:
			cam.follow_target = target
			cam.follow_offset = follow_offset
			cam.follow_damping = follow_dampening
			cam.follow_damping_speed = Vector2(
				1.0 / maxf(follow_dampening_value.x, 0.001),
				1.0 / maxf(follow_dampening_value.y, 0.001)
			)
			cam.rotate_with_target = rotate_with_target

		Cuts.cutscene_cameras.add_child(cam)
		Cuts.camera_controller.transition_to(cam, transition)
		if transition_duration > 0.0:
			await Cuts.camera_controller.transition_finished
		action_done.emit()


func _validate_property(property: Dictionary) -> void:
	if reset_camera:
		if property.name in hide_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		elif property.name in follow_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in hide_props:
			property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR

			
	if follow_camera:
		if property.name in follow_props:
			property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	else:
		if property.name in follow_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
