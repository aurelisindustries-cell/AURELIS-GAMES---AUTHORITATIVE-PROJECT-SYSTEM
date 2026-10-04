extends Node2D

var failures := 0

func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)

func target(at: Vector2, faction: StringName = &"enemy") -> HurtboxComponent2D:
	var health := HealthComponent.new()
	health.max_health = 100
	add_child(health)
	var hurtbox := HurtboxComponent2D.new()
	hurtbox.position = at
	hurtbox.health = health
	hurtbox.faction = faction
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12
	collision.shape = shape
	hurtbox.add_child(collision)
	add_child(hurtbox)
	return hurtbox

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var player := preload("res://GameComponents/Player/player.tscn").instantiate()
	player.position = Vector2(400, 400)
	add_child(player)
	player.get_node("Movement").process_mode = Node.PROCESS_MODE_DISABLED
	var combat := player.find_child("PlayerCombatController", true, false) as PlayerCombatController
	var input := player.find_child("InputHandler2D", true, false) as InputHandler2D
	var first := target(Vector2(490, 378))
	var second := target(Vector2(560, 378))
	var beyond := target(Vector2(700, 378))
	var behind := target(Vector2(340, 378))
	var friendly := target(Vector2(520, 378), &"player")
	await get_tree().physics_frame
	input.ability_requested.emit()
	check(not is_instance_valid(combat._vine), "Locked Vine Whip cannot fire")
	var menu := get_node("/root/UpgradeMenu") as PlayerUpgradeMenu
	menu.open_menu()
	menu.set_upgrade(true, "has_vine_whip")
	menu.close_menu()
	input.ability_requested.emit()
	var first_vine := combat._vine
	input.ability_requested.emit()
	check(is_instance_valid(first_vine) and combat._vine == first_vine, "Ability input fires one whip and prevents spam")
	await get_tree().create_timer(0.3).timeout
	check(first.health.current_health == 96 and second.health.current_health == 96, "One cast hits multiple enemies exactly once")
	check(beyond.health.current_health == 100 and behind.health.current_health == 100, "Whip respects direction and range")
	check(friendly.health.current_health == 100, "Whip cannot damage allies")
	await get_tree().create_timer(0.4).timeout
	check(not is_instance_valid(combat._vine), "Whip cleans itself up")
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.position = Vector2(530, 378)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 140)
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	input.ability_requested.emit()
	await get_tree().create_timer(0.25).timeout
	check(first.health.current_health == 92 and second.health.current_health == 96, "Terrain blocks damage behind the wall")
	menu.open_menu()
	menu.set_upgrade(false, "has_vine_whip")
	menu.close_menu()
	await get_tree().process_frame
	check(not is_instance_valid(combat._vine), "Disabling Vine Whip cancels active lash")
	menu.open_menu()
	menu.set_all(true)
	check(combat.has_vine_whip, "Enable all includes evolved abilities")
	menu.restore_normal()
	check(not combat.has_vine_whip, "Restore normal restores original locked ability")
	menu.close_menu()
	print("Vine Whip regression: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
