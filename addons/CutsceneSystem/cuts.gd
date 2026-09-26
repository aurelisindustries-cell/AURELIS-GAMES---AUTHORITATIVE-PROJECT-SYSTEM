extends Node

signal cutscene_started
signal cutscene_ended

var cutscene_nodes: Dictionary = {}
var base_camera: CutsceneCameraController2D
var camera_controller: CutsceneCameraController2D
var current_camera: CutsceneVirtualCamera2D
var player_camera: CutsceneVirtualCamera2D
var cutscene_cameras: CutsceneCameras
