extends Node2D

## Short-lived, aimed lash. Terrain blocks both the visible vine and its damage.
var source: CharacterBody2D
var direction := Vector2.RIGHT
var reach := 220.0
var damage := 4
var elapsed := 0.0
var startup := 0.08
var active_time := 0.14
var recovery := 0.18
var endpoint := Vector2.ZERO
var hit_targets: Dictionary = {}
var previous_origin := Vector2.ZERO

func setup(body: CharacterBody2D, aim: Vector2, distance: float, hit_damage: int) -> void:
	source = body
	direction = aim.normalized()
	reach = distance
	damage = hit_damage
	previous_origin = body.global_position
	position = Vector2(0, -22)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source): queue_free(); return
	var combat := source.find_child("PlayerCombatController", true, false)
	var health := source.find_child("HealthComponent", true, false) as HealthComponent
	var input := source.find_child("InputHandler2D", true, false) as InputHandler2D
	if not combat or not combat.has_vine_whip or (health and health.current_health <= 0) or (input and not input.can_input) or source.global_position.distance_to(previous_origin) > reach:
		queue_free(); return
	previous_origin = source.global_position
	elapsed += delta
	if elapsed >= startup + active_time + recovery: queue_free(); return
	var extension := clampf(elapsed / startup, 0, 1)
	if elapsed > startup + active_time:
		extension = 1.0 - (elapsed - startup - active_time) / recovery
	endpoint = direction * reach * extension
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + endpoint, 2, [source.get_rid()])
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty(): endpoint = wall.position - global_position
	if elapsed >= startup and elapsed < startup + active_time: _hit_along_vine()
	queue_redraw()

func _hit_along_vine() -> void:
	if endpoint.length() < 1: return
	var shape := CapsuleShape2D.new()
	shape.radius = 10
	shape.height = maxf(20, endpoint.length() + 20)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(direction.angle() - PI / 2, global_position + endpoint * 0.5)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for contact in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var target := contact.collider as HurtboxComponent2D
		if not target or source.is_ancestor_of(target) or target.faction == &"player" or hit_targets.has(target.get_instance_id()): continue
		var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 2, [source.get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var hit := HitData.new()
		hit.damage = damage
		hit.faction = &"player"
		hit.source = source
		hit.attack_type = &"vine_whip"
		hit.reaction = "forced_stagger"
		hit.reaction_duration = 0.25
		if target.receive_hit(hit): hit_targets[target.get_instance_id()] = true

func _draw() -> void:
	var points := PackedVector2Array()
	var normal := direction.orthogonal()
	for i in range(25):
		var t := float(i) / 24
		points.append(endpoint * t + normal * sin(t * TAU * 2 - elapsed * 20) * sin(t * PI) * 6)
	if endpoint.length() < 1: return
	draw_polyline(points, Color(0.08, 0.3, 0.12), 9, true)
	draw_polyline(points, Color(0.35, 0.95, 0.35), 4, true)
	for i in range(3, 23, 4):
		var point := points[i]
		var side := normal * (1 if i % 8 == 3 else -1)
		draw_colored_polygon(PackedVector2Array([point - direction * 5, point + side * 9, point + direction * 5]), Color(0.65, 1, 0.35))
	draw_circle(endpoint, 4, Color(0.8, 1, 0.5))
