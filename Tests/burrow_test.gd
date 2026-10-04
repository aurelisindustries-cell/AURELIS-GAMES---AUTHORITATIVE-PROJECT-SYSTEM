extends Node2D

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var soil := preload("res://GameComponents/Interaction/burrow_soil.tscn").instantiate()
	soil.position = Vector2(400, 500)
	add_child(soil)
	var player := preload("res://GameComponents/Player/player.tscn").instantiate()
	player.position = Vector2(400, 420)
	add_child(player)
	var combat := player.find_child("PlayerCombatController", true, false) as PlayerCombatController
	var controller := player.find_child("CharacterController", true, false) as CharacterController
	var input := player.find_child("InputHandler2D", true, false) as InputHandler2D
	await get_tree().create_timer(0.7).timeout
	check(player.is_on_floor(), "Player stands on the burrowable soil")
	check(not combat.burrow.begin(), "Burrow is locked by default")
	var menu := get_node("/root/UpgradeMenu") as PlayerUpgradeMenu
	menu.open_menu()
	menu.set_upgrade(true, "has_burrow")
	menu.set_upgrade(true, "has_vine_whip")
	menu.close_menu()
	combat.request_next_core()
	check(combat.selected_evolved == "burrow", "Ability switching selects Burrow")
	input.ability_requested.emit()
	check(combat.burrow.active and controller.burrowing, "Ability button starts Burrow on soil")
	check(controller.state_machine.current_state.name == "Burrow", "Runtime Burrow state replaces normal movement")
	check(player.position.y > soil.position.y and not player.get_node("Visuals").visible, "Burrow enters beneath the surface")
	input.set_process(false)
	controller.input_update(Vector2.RIGHT)
	await get_tree().create_timer(1.0).timeout
	check(player.position.x > 430 and player.position.x <= 508.1, "Underground movement remains inside the soil strip")
	combat.request_caster()
	combat.request_dagger()
	check(combat._caster_buffer == 0 and combat._dagger_buffer == 0, "Normal attacks are disabled underground")
	controller.input_update(Vector2.ZERO)
	input.ability_requested.emit()
	check(not controller.burrowing and player.position.y < soil.position.y and player.get_node("Visuals").visible, "Ability button restores surface position and visuals")
	await get_tree().create_timer(0.2).timeout
	input.ability_requested.emit()
	check(combat.burrow.active, "Can reenter soil after surfacing")
	controller.input_update(Vector2.LEFT)
	await get_tree().create_timer(0.45).timeout
	controller.input_update(Vector2.ZERO)
	var roof := StaticBody2D.new()
	roof.collision_layer = 2
	roof.position = Vector2(player.position.x, soil.position.y - 30)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 50)
	collision.shape = shape
	roof.add_child(collision)
	add_child(roof)
	await get_tree().physics_frame
	await get_tree().physics_frame
	input.ability_requested.emit()
	check(combat.burrow.active, "Cannot surface through a solid overhead obstacle")
	menu.open_menu()
	menu.set_upgrade(false, "has_burrow")
	menu.close_menu()
	check(not controller.burrowing and not combat.burrow.active, "Disabling the upgrade safely surfaces the player")
	check(player.get_collision_exceptions().is_empty(), "Surface restores terrain collision")
	roof.queue_free()
	await get_tree().create_timer(0.2).timeout
	combat.has_burrow = true
	combat.burrow_duration = 0.1
	check(combat.burrow.begin(), "Burrow can start for duration test")
	await get_tree().create_timer(0.2).timeout
	check(not controller.burrowing, "Burrow duration automatically surfaces the player")
	await get_tree().create_timer(0.2).timeout
	combat.burrow_duration = 5
	check(combat.burrow.begin(), "Enter Burrow for jump regression")
	input.jump_requested.emit()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not combat.burrow.active and not controller.burrowing, "Jump surfaces instead of being consumed by the normal movement state")
	check(player.position.y < soil.position.y and player.get_node("Visuals").visible, "Jump restores visible player above soil")
	check(player.get_collision_exceptions().is_empty(), "Jump restores terrain collision")
	player.position = Vector2(800, 300)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not combat.burrow.begin(), "Cannot burrow in open air")
	print("Burrow regression: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
