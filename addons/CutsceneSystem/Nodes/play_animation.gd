@icon("res://addons/CutsceneSystem/icons/cutscene_animation.png")
@tool
extends CutsceneNode
class_name CutscenePlayAnimation

@export var node_to_animate: Node:
	set(value):
		node_to_animate = value
		property_list_changed.emit()
@export var replace_node: bool:
	set(value):
		replace_node = value
		property_list_changed.emit()
@export_enum("ANIMATEDSPRITE2D","ANIMATIONPLAYER") var animation_node_type: String = "ANIMATEDSPRITE2D":
	set(value):
		animation_node_type = value
		property_list_changed.emit()

@export var times_played: int = 1
@export var speed_mod: float = 1
@export var animation_name: String = "Idle"



@export_category("Character Animation")
@export var loop_after_stop: bool = true
@export var animator_nodepath: String = "Sprite"

@export_category("Replace Animation")
@export var sprite_frames: SpriteFrames
@export var at_node_position: bool = false
@export var offset: Vector2

const anim_player_props: Array[StringName] = [&"times_played",&"speed_mod",&"animation_name"]
const all_hide : Array[StringName] = [&"animation_node_type",&"times_played",&"speed_mod",&"animation_name",
&"replace_node",&"loop_after_stop", &"animator_nodepath",&"sprite_frames",&"at_node_position",&"offset"]
const chara_anim_props : Array[StringName] = [&"loop_after_stop", &"animator_nodepath",&"animation_node_type"]
const rep_anim_props : Array[StringName] = [&"sprite_frames",&"at_node_position",&"offset"]

const animation_type_groups : Array[StringName] = [&"Replace Animation", &"Character Animation"]

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if node_to_animate: name = "Play" + node_to_animate.name + "Animation" + animation_name
		else: name = "PleaseSelectNode"

func do_action() -> void:
	if node_to_animate is AnimationPlayer:
		for i: int in times_played:
			node_to_animate.play(animation_name,-1,speed_mod)
			await node_to_animate.animation_finished
		if wait_to_finish: action_done.emit()
	else:
		if replace_node:
			var node: AnimatedSprite2D = AnimatedSprite2D.new()
			add_child(node)
			node.sprite_frames = sprite_frames
			if at_node_position:
				node.global_position = node_to_animate.global_position + offset
			node_to_animate.hide()
			for i in times_played:
				node.sprite_frames.set_animation_loop(animation_name,false)
				node.play(animation_name,speed_mod)
				await node.animation_finished
			node_to_animate.show()
			node.queue_free()
			if wait_to_finish: node_to_animate.show()
			
		else:
			var node: Node = get_node(str(node_to_animate.get_path()) + "/" + animator_nodepath)
			if animation_node_type == "ANIMATEDSPRITE2D":
				for i in times_played:
					node.sprite_frames.set_animation_loop(animation_name,false)
					node.play(animation_name,speed_mod)
					await node.animation_finished
				if loop_after_stop: 
					node.sprite_frames.set_animation_loop(animation_name,true)
					node.play(animation_name,speed_mod)
				if wait_to_finish: action_done.emit()
			else:
				for i in times_played:
					node.play(animation_name,-1,speed_mod)
					await node.animation_finished
				if wait_to_finish: action_done.emit()


func _validate_property(property: Dictionary) -> void:
	if node_to_animate is AnimationPlayer:
		if property.name in anim_player_props:
			property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		elif property.name in all_hide:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif node_to_animate is Node:

		if replace_node:
			if property.name in chara_anim_props:
				property.usage = PROPERTY_USAGE_NO_EDITOR
			if property.name in rep_anim_props:
				property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		else:
			if property.name in chara_anim_props:
				property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			if property.name in rep_anim_props:
				property.usage = PROPERTY_USAGE_NO_EDITOR
				
		if animation_node_type == "ANIMATIONPLAYER":
			if property.name == &"loop_after_stop":
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property.name in chara_anim_props:
				property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	else:
		if property.name in all_hide:
			property.usage = PROPERTY_USAGE_NO_EDITOR
