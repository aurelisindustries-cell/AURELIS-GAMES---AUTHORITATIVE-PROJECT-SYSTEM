@icon("res://addons/at-icons/node2d/target.svg")
extends CharacterBody2D
class_name CombatDummy

@export var remove_on_death: bool = false
@export var flash_duration: float = 0.08
@export var damage_number_scene: PackedScene
@export var damage_number_offset := Vector2(0.0, -78.0)
@export var return_to_spawn: bool = true
@export_range(0.1, 30.0, 0.1) var return_delay: float = 3.0

@onready var health: HealthComponent = $HealthComponent
@onready var visual: CanvasItem = $Visual

var _original_color := Color.WHITE
var _spawn_position := Vector2.ZERO
var _return_remaining := 0.0


func _ready() -> void:
	add_to_group(&"enemies")
	_spawn_position = global_position
	_original_color = visual.modulate
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_return_remaining = maxf(_return_remaining - delta, 0.0)
	if _return_remaining > 0.0:
		return
	global_position = _spawn_position
	velocity = Vector2.ZERO
	var reaction := get_node_or_null("CombatReactionComponent2D") as CombatReactionComponent2D
	if reaction: reaction.cancel_reaction()
	set_physics_process(false)


func _on_damaged(hit: HitData) -> void:
	if return_to_spawn:
		_return_remaining = return_delay
		set_physics_process(true)
	visual.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_interval(flash_duration)
	tween.tween_property(visual, "modulate", _original_color, flash_duration)
	_spawn_damage_number(hit.damage)


func _on_died(_hit: HitData) -> void:
	if remove_on_death:
		queue_free()


func _spawn_damage_number(amount: int) -> void:
	if not damage_number_scene:
		return
	var number := damage_number_scene.instantiate() as DamageNumber2D
	if not number:
		return
	get_tree().current_scene.add_child(number)
	number.global_position = global_position + damage_number_offset
	number.show_damage(amount)
