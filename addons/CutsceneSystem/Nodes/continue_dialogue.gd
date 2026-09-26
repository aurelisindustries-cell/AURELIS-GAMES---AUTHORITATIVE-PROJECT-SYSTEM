@icon("res://addons/CutsceneSystem/icons/continue_dialogue.png")
@tool
extends CutsceneNode
class_name CutsceneDialogue

@export var dialogue_resource: DialogueResource
@export var dialogue_character: DialogueCharacter

func _ready() -> void:
	if Engine.is_editor_hint():
		if !dialogue_resource: 
			dialogue_resource = DialogueResource.new().duplicate()
			dialogue_resource.setup_local_to_scene()

func do_action() -> void:
	var type_speed: float = 0.1
	if dialogue_character: type_speed =dialogue_character.typing_speed
	Gui.dialogue.write_dialogue(dialogue_resource.dialogue, type_speed * dialogue_resource.typing_speed)
	await Gui.dialogue.dialogue_finished
	action_done.emit()
