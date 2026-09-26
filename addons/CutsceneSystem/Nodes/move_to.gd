@icon("res://addons/CutsceneSystem/icons/cutscene_move.png")
@tool
extends CutsceneNode
class_name CutsceneMovement

@export var node_to_move: Node2D:
	set(value):
		node_to_move = value
		notify_property_list_changed()
		
@export var set_position: bool:
	set(value):
		set_position = value
		notify_property_list_changed()

@export var play_animation: bool:
	set(value):
		play_animation = value
		notify_property_list_changed()
@export var use_tween: bool:
	set(value):
		use_tween = value
		notify_property_list_changed()

@export_category("Animations")
@export var animation: String = "Walk"
@export var animation_speed: float = 1

@export_category("Movement")
@export var speed_mod: float = 1
@export_enum("LEFT","RIGHT","UP","DOWN") var end_lookat: String = "LEFT"


@export_category("Tween Movement")
@export var tween_time: float = 2
@export var tween_trans: Tween.TransitionType
@export var tween_ease: Tween.EaseType


const chara_show_props: Array[StringName] = [&"play_animation",&"use_tween"]
const anim_props: Array[StringName] = [&"animation", &"animation_speed"]
const move_props: Array[StringName] = [&"speed_mod",&"end_lookat"]
const tween_props: Array[StringName] = [&"tween_time", &"tween_trans", &"tween_ease"]

var existed_name: String = ""

func _ready() -> void:
	if Engine.is_editor_hint():
		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		add_child(sprite)
		sprite.sprite_frames = load("uid://m3hrjoed6rw6")
		sprite.modulate = Color(1,1,1,0.3)
		sprite.animation = "Idle"
		sprite.position.y -= 100
	else:
		if node_to_move: existed_name = node_to_move.name

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if !node_to_move:
			name = "PleaseSelectNode"
		elif set_position:
			name = "Set" + node_to_move.name + "PositionTo(X" + str(int(global_position.x)) + ",Y" + str(int(global_position.y)) + ")"
		elif use_tween or not node_to_move is CharacterEntity:
			name = "Tween" + node_to_move.name + "To(X" + str(int(global_position.x)) + ",Y" + str(int(global_position.y)) + ")"
		else:
			name = "Move" + node_to_move.name +  "To(X" + str(int(global_position.x)) + ",Y" + str(int(global_position.y)) + ")"

func do_action() -> void:
	if not is_instance_valid(node_to_move):
		if existed_name.is_empty():
			push_error("No node selected")
		else:
			push_error("Node " + existed_name + " no longer exists.")
		action_done.emit()
		return
	
	if set_position:
		move_set()
		return
	elif node_to_move is CharacterEntity and not use_tween:
		if (node_to_move as CharacterEntity).has_component(CharacterController):
			move_real()
		else:
			move_tween()
	else:
		move_tween()


func move_set() -> void:
	node_to_move.global_position = global_position
	await get_tree().process_frame
	action_done.emit()

func move_real() -> void:
	node_to_move.cuts_move(global_position,speed_mod,end_lookat)
	await node_to_move.cutscene_move_done
	action_done.emit()
	
func move_tween() -> void:
	if node_to_move is CharacterEntity:
		(node_to_move as CharacterEntity).collision.set_deferred("disabled", true)
	var ptween: Tween = create_tween().set_ease(tween_ease).set_trans(tween_trans)
	ptween.tween_property(node_to_move,"global_position",global_position,tween_time)
	await ptween.finished
	if node_to_move is CharacterEntity:
		(node_to_move as CharacterEntity).collision.set_deferred("disabled", false)
	action_done.emit()
	


func _validate_property(property: Dictionary) -> void:
	if !node_to_move or set_position:
		if property.name in move_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name in anim_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name in chara_show_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name in tween_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif not node_to_move is CharacterEntity:
		if property.name in move_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name in anim_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name in chara_show_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name in tween_props:
			property.usage = PROPERTY_USAGE_EDITOR
			
	else:
		if use_tween:
			if property.name in move_props:
				property.usage = PROPERTY_USAGE_NO_EDITOR
			elif property.name in tween_props:
				property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		else:
			if property.name in move_props:
				property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			elif property.name in tween_props:
				property.usage = PROPERTY_USAGE_NO_EDITOR

					#
		#if play_animation:
			#if property.name in anim_props:
				#property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		#else:
			#if property.name in anim_props:
				#property.usage = PROPERTY_USAGE_NO_EDITOR
