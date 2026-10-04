extends Node2D


func _ready() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		get_tree().change_scene_to_file("res://GameComponents/LevelEditor/level_editor.tscn")
