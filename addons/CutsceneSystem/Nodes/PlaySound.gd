@icon("res://addons/CutsceneSystem/icons/cutscene_sfx.png")
@tool
extends CutsceneNode
class_name CutscenePlaySound

@export var spacial_sound: bool = false
@export var sound: AudioStream
@export var pitch: float = 1
@export var pitch_randomnes: Vector2 = Vector2(-0.1,0.1)
@export var volume: float = 0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		name = "PlaySound(" + sound.resource_name + ")"

func do_action() -> void:
	var snd
	if spacial_sound:
		snd = AudioStreamPlayer2D.new()
	else:
		snd = AudioStreamPlayer.new()
	add_child(snd)
	snd.stream = sound
	snd.pitch_scale = pitch + randf_range(pitch_randomnes.x,pitch_randomnes.y)
	snd.volume_db = volume
	snd.play()
	await snd.finished
	snd.queue_free()
	action_done.emit()
