@icon("res://addons/at-icons/node2d/arrow_projectile.svg")
extends Area2D
class_name CombatProjectile2D

signal hit_landed(hurtbox: HurtboxComponent2D, hit: HitData)

@export var speed: float = 640.0
@export var lifetime: float = 1.25
@export var impact_scene: PackedScene

var direction := Vector2.RIGHT
var hit_data: HitData
var source: Node
var pierce_remaining: int = 0
var ignores_terrain: bool = false
var homing_strength: float = 0.0
var _homing_target: HurtboxComponent2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(new_direction: Vector2, new_hit: HitData, attack_source: Node, pierce: int = 0, terrain_piercing: bool = false, homing: float = 0.0) -> void:
	direction = new_direction.normalized()
	hit_data = new_hit
	source = attack_source
	pierce_remaining = pierce
	ignores_terrain = terrain_piercing
	homing_strength = homing
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if homing_strength > 0.0:
		_update_homing(delta)
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent2D
	if not hurtbox or (source and source.is_ancestor_of(hurtbox)):
		return
	var hit := hit_data.copy_for(source) if hit_data else HitData.new()
	if hurtbox.receive_hit(hit):
		hit_landed.emit(hurtbox, hit)
		_spawn_impact()
		if pierce_remaining > 0:
			pierce_remaining -= 1
		else:
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == source:
		return
	if body.get_node_or_null("HurtboxComponent2D"):
		return
	if not ignores_terrain:
		_spawn_impact()
		queue_free()


func _update_homing(delta: float) -> void:
	if not is_instance_valid(_homing_target):
		_homing_target = _find_homing_target()
	if not _homing_target:
		return
	var desired := global_position.direction_to(_homing_target.global_position)
	direction = direction.lerp(desired, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
	rotation = direction.angle()


func _find_homing_target() -> HurtboxComponent2D:
	var nearest: HurtboxComponent2D
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(&"combat_hurtboxes"):
		var hurtbox := node as HurtboxComponent2D
		if not hurtbox or (source and source.is_ancestor_of(hurtbox)):
			continue
		if hit_data and hit_data.faction != &"neutral" and hurtbox.faction == hit_data.faction:
			continue
		var distance := global_position.distance_squared_to(hurtbox.global_position)
		if distance < nearest_distance:
			nearest = hurtbox
			nearest_distance = distance
	return nearest


func _spawn_impact() -> void:
	if not impact_scene:
		return
	var impact := impact_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position
