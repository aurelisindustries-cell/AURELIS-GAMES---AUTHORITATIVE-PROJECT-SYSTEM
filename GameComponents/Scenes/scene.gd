extends Node2D


func _ready() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		get_tree().change_scene_to_file("res://GameComponents/LevelEditor/level_editor.tscn")
