@icon("res://addons/at-icons/node2d/heart.svg")
extends Node
class_name EnemyLifecycleComponent

@export var respawn_enabled: bool = true
@export var damage_number_scene: PackedScene
@export var damage_number_offset := Vector2(0.0, -72.0)
@export var flash_duration: float = 0.08
@export var pickup_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var pickup_drop_chance: float = 0.35
@export var body: CharacterBody2D
@export var health: HealthComponent
@export var hurtbox: HurtboxComponent2D
@export var body_collision: CollisionShape2D
@export var visuals: CanvasItem
@export var health_bar: CanvasItem
@export var screen_notifier: VisibleOnScreenNotifier2D

var _spawn_position := Vector2.ZERO
var _original_modulate := Color.WHITE
var _dead := false
var _left_screen_after_death := false


func _ready() -> void:
	if not body: body = get_parent().get_parent() as CharacterBody2D
	if not body: return
	if not health: health = body.find_child("HealthComponent", true, false) as HealthComponent
	if not hurtbox: hurtbox = body.find_child("HurtboxComponent2D", true, false) as HurtboxComponent2D
	if not body_collision: body_collision = body.find_child("Collision", true, false) as CollisionShape2D
	if not visuals: visuals = body.find_child("Visuals", true, false) as CanvasItem
	if not health_bar: health_bar = body.find_child("HealthBar", true, false) as CanvasItem
	if not screen_notifier: screen_notifier = body.find_child("VisibleOnScreenNotifier2D", true, false) as VisibleOnScreenNotifier2D
	_spawn_position = body.global_position
	_original_modulate = visuals.modulate if visuals else Color.WHITE
	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if screen_notifier:
		screen_notifier.screen_exited.connect(_on_screen_exited)
		screen_notifier.screen_entered.connect(_on_screen_entered)


func _on_damaged(hit: HitData) -> void:
	_spawn_damage_number(hit.damage)
	_spawn_hit_sparks()
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.08, 2.4, Vector2(4.0, 3.0), 0.006)
	if visuals and not _dead:
		visuals.modulate = Color.WHITE
		var tween := create_tween()
		tween.tween_interval(flash_duration)
		tween.tween_property(visuals, "modulate", _original_modulate, flash_duration)


func _on_died(_hit: HitData) -> void:
	if _dead: return
	_dead = true
	_spawn_hit_sparks(10)
	_spawn_pickup()
	_left_screen_after_death = not screen_notifier or not screen_notifier.is_on_screen()
	_set_alive(false)
	if not respawn_enabled:
		body.queue_free()


func _on_screen_exited() -> void:
	if _dead:
		_left_screen_after_death = true


func _on_screen_entered() -> void:
	if _dead and respawn_enabled and _left_screen_after_death:
		_respawn()


func _respawn() -> void:
	body.global_position = _spawn_position
	body.velocity = Vector2.ZERO
	if health:
		health.heal(health.max_health)
	for ai_root_node in body.find_children("*", "AIRoot", true, false):
		var root := ai_root_node as AIRoot
		root.clear_memory()
		for child in root.get_children():
			if child is AINode: (child as AINode).reset()
	_dead = false
	_left_screen_after_death = false
	_set_alive(true)


func _set_alive(alive: bool) -> void:
	if visuals:
		visuals.visible = alive
		visuals.modulate = _original_modulate
	if health_bar: health_bar.visible = alive
	if hurtbox: hurtbox.set_deferred("enabled", alive)
	if body_collision: body_collision.set_deferred("disabled", not alive)
	var movement := body.get_node_or_null("Movement")
	var ai := body.get_node_or_null("AI")
	if movement: movement.process_mode = Node.PROCESS_MODE_INHERIT if alive else Node.PROCESS_MODE_DISABLED
	if ai: ai.process_mode = Node.PROCESS_MODE_INHERIT if alive else Node.PROCESS_MODE_DISABLED
	for hitbox in body.find_children("*", "HitboxComponent2D", true, false):
		(hitbox as HitboxComponent2D).set_deferred("monitoring", alive)


func _spawn_damage_number(amount: int) -> void:
	if not damage_number_scene: return
	var number := damage_number_scene.instantiate() as DamageNumber2D
	if not number: return
	get_tree().current_scene.add_child(number)
	number.global_position = body.global_position + damage_number_offset
	number.show_damage(amount)


func _spawn_pickup() -> void:
	if not pickup_scene or randf() > pickup_drop_chance: return
	var pickup := pickup_scene.instantiate() as Node2D
	if not pickup: return
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = body.global_position + Vector2(0.0, -20.0)


func _spawn_hit_sparks(count: int = 5) -> void:
	if not body or not get_tree().current_scene: return
	for index in count:
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(3, 0), Vector2(-2, 2)])
		spark.color = Color(1.0, 0.82, 0.28, 1.0)
		get_tree().current_scene.add_child(spark)
		spark.global_position = body.global_position + Vector2(0.0, -28.0)
		var direction := Vector2.from_angle(TAU * float(index) / float(count) + randf_range(-0.3, 0.3))
		var tween := spark.create_tween().set_parallel()
		tween.tween_property(spark, "global_position", spark.global_position + direction * randf_range(18.0, 38.0), 0.22)
		tween.tween_property(spark, "modulate:a", 0.0, 0.22)
		tween.finished.connect(spark.queue_free)
