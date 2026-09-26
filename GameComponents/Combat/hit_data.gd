@icon("res://addons/at-icons/node2d/database.svg")
extends Resource
class_name HitData

@export var damage: int = 1
@export var knockback := Vector2.ZERO
@export var hit_stop: float = 0.0
@export var attack_type: StringName = &"normal"
@export_enum("hit_recoil", "stun", "knockback", "aerial_interrupt", "forced_stagger", "launch", "toss", "slammed") var reaction: String = "hit_recoil"
@export var reaction_duration: float = 0.0
@export var faction: StringName = &"neutral"

var source: Node


func copy_for(new_source: Node) -> HitData:
	var result := duplicate() as HitData
	result.source = new_source
	return result
