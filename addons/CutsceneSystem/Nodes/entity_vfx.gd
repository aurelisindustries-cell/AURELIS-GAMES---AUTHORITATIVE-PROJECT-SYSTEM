@icon("res://addons/CutsceneSystem/icons/cutscene_vfx.png")
@tool
extends CutsceneNode
class_name CutsceneEntityVFX

@export var target_node: Node2D
@export_enum("FADE","UNFADE","HIDE","SHOW","FLASH","TINT","SHAKE") var vfx_type: String = "FADE":
	set(value):
		vfx_type = value
		property_list_changed.emit()

@export_category("Fade")
@export var fade_duration: float = 1
@export var fade_tween_trans: Tween.TransitionType
@export var fade_tween_ease: Tween.EaseType

@export_category("Unfade")
@export var unfade_duration: float = 1
@export var unfade_tween_trans: Tween.TransitionType
@export var unfade_tween_ease: Tween.EaseType

@export_category("Flash")
@export var flash_color: Color = Color(5,5,5,1)
@export var flash_tween_start_duration: float = 0.3
@export var flash_tween_start_trans: Tween.TransitionType
@export var flash_tween_start_ease: Tween.EaseType
@export var flash_tween_end_duration: float = 0.3
@export var flash_tween_end_trans: Tween.TransitionType
@export var flash_tween_end_ease: Tween.EaseType

@export_category("Tint")
@export var tint_color: Color = Color(1,1,1,1)
@export var tint_tween_duration: float = 0.6
@export var tint_tween_trans: Tween.TransitionType
@export var tint_tween_ease: Tween.EaseType

@export_category("Shake")
@export var shake_duration: float = 0.8
@export var shake_strength: float = 10
@export var rotation_range: Vector2 = Vector2(0,0)
@export var shakes: int = 5
@export var axis: Vector2 = Vector2(1,1)

const all_props: Array[StringName] = [&"fade_duration",&"fade_tween_trans",&"fade_tween_ease"
,&"unfade_duration",&"unfade_tween_trans",&"unfade_tween_ease",
&"flash_color",&"flash_tween_start_duration",&"flash_tween_start_trans",&"flash_tween_start_ease"
,&"flash_tween_end_duration",&"flash_tween_end_trans",&"flash_tween_end_ease",
&"tint_color",&"tint_tween_duration",&"tint_tween_trans",&"tint_tween_ease",
&"shake_duration",&"shake_strength",&"rotation_range",&"shakes",&"axis"]

const fade_props: Array[StringName] = [&"fade_duration",&"fade_tween_trans",&"fade_tween_ease"]
const unfade_props: Array[StringName] = [&"unfade_duration",&"unfade_tween_trans",&"unfade_tween_ease"]
const flash_props: Array[StringName] = [&"flash_color",&"flash_tween_start_duration",&"flash_tween_start_trans",&"flash_tween_start_ease"
,&"flash_tween_end_duration",&"flash_tween_end_trans",&"flash_tween_end_ease"]
const tint_props: Array[StringName] = [&"tint_color",&"tint_tween_duration",&"tint_tween_trans",&"tint_tween_ease"]
const shake_props: Array[StringName] = [&"shake_duration",&"shake_strength",&"rotation_range",&"shakes",&"axis"]


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if target_node:
			name = vfx_type + target_node.name
		else:
			name = "PleaseSelectEntity"
	

func do_action() -> void:
	match vfx_type:
		"FADE": 
			var ctween: Tween = create_tween().set_ease(fade_tween_ease).set_trans(fade_tween_trans)
			target_node.show()
			ctween.tween_property(target_node,"modulate",Color(1,1,1,0),0.6)
			await ctween.finished
			target_node.hide()
			if wait_to_finish:action_done.emit()
		"UNFADE": 
			var ctween: Tween = create_tween().set_ease(unfade_tween_ease).set_trans(unfade_tween_trans)
			target_node.show()
			target_node.modulate = Color(1,1,1,0)
			ctween.tween_property(target_node,"modulate",Color(1,1,1,1),0.6)
			await ctween.finished
			if wait_to_finish:action_done.emit()
		"HIDE": 
			target_node.hide()
			await get_tree().physics_frame
			if wait_to_finish:action_done.emit()
		"SHOW": 
			target_node.show()
			await get_tree().physics_frame
			if wait_to_finish:action_done.emit()
		"FLASH":
			var original_modulate = target_node.modulate
			var ctween: Tween = create_tween().set_ease(flash_tween_start_ease).set_trans(flash_tween_start_trans)
			ctween.tween_property(target_node,"modulate",flash_color,0.2)
			await ctween.finished
			var ctween2: Tween = create_tween().set_ease(flash_tween_end_ease).set_trans(flash_tween_end_trans)
			ctween2.tween_property(target_node,"modulate",original_modulate,0.2)
			await ctween2.finished
			if wait_to_finish:action_done.emit()
		"TINT": 
			var ctween: Tween = create_tween()
			ctween.tween_property(target_node,"modulate",tint_color,0.6)
			await ctween.finished
			if wait_to_finish:action_done.emit()
		"SHAKE":
			if target_node is Character:
				target_node.collision.disabled = true
			TweenFX.shake(target_node,shake_duration,shake_strength,shakes,axis,rotation_range)
			await get_tree().create_timer(shake_duration).timeout
			if target_node is Character:
				target_node.collision.disabled = false
			if wait_to_finish:action_done.emit()
			

func _validate_property(property: Dictionary) -> void:
	if property.name in all_props:
		property.usage = PROPERTY_USAGE_NO_EDITOR
		
	match vfx_type:
		"FADE": if property.name in fade_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		"UNFADE": if property.name in unfade_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		"FLASH": if property.name in flash_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		"TINT": if property.name in tint_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		"SHAKE": if property.name in shake_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		
