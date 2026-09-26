@icon("res://addons/CutsceneSystem/icons/screen_vfx.png")
@tool
extends CutsceneNode
class_name CutsceneScreenVFX

@export_enum("SHAKE","FLASH","TINT","FADE","UNFADE") var vfx_type: String = "SHAKE":
	set(value):
		vfx_type = value
		property_list_changed.emit()




@export_category("Shake")
@export var decay: float = 0.8
@export var power: float = 5
@export var max_offset: Vector2 = Vector2(100, 75)
@export var max_roll: float = 0.1
@export var use_custom_noise: bool = false
@export var custom_noise: FastNoiseLite

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


const all_props: Array[StringName] = [&"fade_duration",&"fade_tween_trans",&"fade_tween_ease"
,&"unfade_duration",&"unfade_tween_trans",&"unfade_tween_ease",
&"flash_color",&"flash_tween_start_duration",&"flash_tween_start_trans",&"flash_tween_start_ease"
,&"flash_tween_end_duration",&"flash_tween_end_trans",&"flash_tween_end_ease",
&"tint_color",&"tint_tween_duration",&"tint_tween_trans",&"tint_tween_ease",
&"decay",&"power",&"max_offset",&"max_roll",&"use_custom_noise",&"custom_noise"]

const fade_props: Array[StringName] = [&"fade_duration",&"fade_tween_trans",&"fade_tween_ease"]
const unfade_props: Array[StringName] = [&"unfade_duration",&"unfade_tween_trans",&"unfade_tween_ease"]
const flash_props: Array[StringName] = [&"flash_color",&"flash_tween_start_duration",&"flash_tween_start_trans",&"flash_tween_start_ease"
,&"flash_tween_end_duration",&"flash_tween_end_trans",&"flash_tween_end_ease"]
const tint_props: Array[StringName] = [&"tint_color",&"tint_tween_duration",&"tint_tween_trans",&"tint_tween_ease"]
const shake_props: Array[StringName] = [&"decay",&"power",&"max_roll",&"use_custom_noise",&"custom_noise"]



func _process(delta: float) -> void:
	name = vfx_type + "Screen"
	

func do_action() -> void:
	match vfx_type:
		"SHAKE":
			Cuts.base_camera.add_trauma(power,decay,max_offset,max_roll,use_custom_noise,custom_noise)
			await Cuts.base_camera.shake_done
			if wait_to_finish: action_done.emit()
		"FLASH":
			Gui.flash_screen(flash_color,flash_tween_start_duration,flash_tween_end_duration,flash_tween_start_ease,flash_tween_start_trans,flash_tween_end_ease,flash_tween_end_trans)
			await get_tree().create_timer(flash_tween_start_duration + flash_tween_end_duration).timeout
			if wait_to_finish: action_done.emit()
		"TINT":
			Gui.tint_screen(tint_color,tint_tween_duration,tint_tween_ease,tint_tween_trans)
			await get_tree().create_timer(tint_tween_duration).timeout
			if wait_to_finish: action_done.emit()
		"FADE":
			Gui.fade_screen(Color(0,0,0,1),fade_duration,fade_tween_ease,fade_tween_trans)
			await get_tree().create_timer(fade_duration).timeout
			if wait_to_finish: action_done.emit()
		"UNFADE":
			Gui.fade_screen(Color(0,0,0,0),fade_duration,fade_tween_ease,fade_tween_trans)
			await get_tree().create_timer(unfade_duration).timeout
			if wait_to_finish: action_done.emit()

func _validate_property(property: Dictionary) -> void:
	if property.name in all_props:
		property.usage = PROPERTY_USAGE_NO_EDITOR
		
	match vfx_type:
		"FADE": if property.name in fade_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		"UNFADE": if property.name in unfade_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		"FLASH": if property.name in flash_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		"TINT": if property.name in tint_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		"SHAKE": if property.name in shake_props: property.usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		
