extends Node

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func press(key: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)

func run() -> void:
	var data := VaniaStarter.create()
	var runner := VaniaWorldRunner.new()
	runner.world = data
	runner.preview = true
	add_child(runner)
	await get_tree().process_frame
	var menu := get_node("/root/UpgradeMenu") as PlayerUpgradeMenu
	var controller := runner.player.find_child("CharacterController", true, false) as CharacterController
	var combat := runner.player.find_child("PlayerCombatController", true, false) as PlayerCombatController
	var health := runner.player.find_child("HealthComponent", true, false) as HealthComponent
	press(KEY_F2)
	await get_tree().process_frame
	check(menu.opened and get_tree().paused, "F2 opens menu and pauses gameplay")
	check(menu.player == runner.player, "Menu selects live player")
	check(menu.tabs.get_tab_count() == 6, "Upgrades grouped into six categories")
	press(KEY_F2, true)
	check(menu.opened, "Key repeat cannot reopen/close menu")
	menu.set_upgrade(true, "dash")
	check(controller.has_dash and runner.has_ability("dash"), "Dash override affects movement and gates")
	check("dash" not in runner.abilities, "Toggle does not change earned abilities")
	await get_tree().process_frame
	check(not (runner.active_room.get_node("Entities/Exit1") as VaniaMarker).locked, "Movement toggle unlocks matching gate")
	menu.set_upgrade(true, "combo_2")
	check(combat.dagger_combo_upgrades == 2 and menu.toggles.combo_1.button_pressed, "Third combo hit also enables second")
	menu.set_upgrade(false, "combo_1")
	check(combat.dagger_combo_upgrades == 0 and not menu.toggles.combo_2.button_pressed, "Disabling second combo disables finisher")
	menu._set_value("left_caster_module", "guided")
	menu.set_upgrade(false, "has_guided_module")
	combat.request_caster(1)
	check(combat._pending_caster_module == "", "Disabled equipped module falls back to normal shot")
	combat._caster_buffer = 0
	menu.set_upgrade(true, "health")
	menu._set_value("health_count", 3)
	check(health.max_health == 28, "Health upgrade count changes maximum health")
	health.restore_full()
	menu.set_upgrade(false, "has_piercing_module")
	check(health.current_health == 28, "Unrelated toggle does not drain bonus health")
	controller.propulsor_jump_available = true
	menu.set_upgrade(false, "propulsor_step")
	check(not controller.propulsor_jump_available, "Disabling propulsor removes banked extra jump")
	menu.set_upgrade(true, "has_extended_edge_2")
	menu.set_upgrade(true, "has_reinforced_edge_2")
	check(combat.has_extended_edge_1 and combat.has_reinforced_edge_1, "Second edge tiers enable first tiers")
	check(is_equal_approx(combat.dagger_reach_multiplier(), 1.5), "Extended Edge II reaches 150 percent")
	var spawner := combat.authored_hitbox_spawner
	var handle := spawner.get_node("Hitbox_dagger_normal") as HitboxAuthoringHandle2D
	var original_damage := handle.hit.damage
	var runtime_hitbox := spawner._create_handle_instance(handle)
	check(runtime_hitbox.default_hit.damage == original_damage + 4, "Reinforced tiers modify the actual authored attack")
	check(handle.hit.damage == original_damage, "Upgrade does not mutate shared authored damage")
	runtime_hitbox.queue_free()
	handle.active = true
	spawner._refresh_handle_instances()
	var active_hitbox := spawner._instances[handle] as HitboxComponent2D
	check(is_equal_approx(active_hitbox.scale.x, handle.scale.x * 1.5), "Extended tiers enlarge the actual collision shape")
	handle.active = false
	spawner._refresh_handle_instances()
	menu.set_upgrade(false, "has_extended_edge_1")
	menu.set_upgrade(false, "has_reinforced_edge_1")
	check(not combat.has_extended_edge_2 and not combat.has_reinforced_edge_2, "Disabling first edge tiers clears dependent tiers")
	check(combat.upgraded_dagger_hit(handle.hit).damage == original_damage and is_equal_approx(combat.dagger_reach_multiplier(), 1.0), "Disabling edges restores damage and reach")
	menu.set_upgrade(true, "has_buster_v1")
	menu.set_upgrade(false, "has_dash_shot")
	var shots: Array[int] = []
	combat.caster_fired.connect(func(_direction: Vector2, damage: int): shots.append(damage))
	combat.request_caster()
	combat._process(0.01)
	combat._process(combat.buster_charge_time + 0.2)
	combat.release_caster()
	check(shots.size() == 2 and shots[1] == roundi(combat.caster_damage * combat.charged_damage_multiplier), "Holding and releasing Buster V1 fires a stronger shot")
	combat.request_caster()
	menu.set_upgrade(false, "has_buster_v1")
	check(not combat._charging, "Disabling Buster cancels stored charge immediately")
	combat._caster_buffer = 0
	if "--capture-upgrades" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/synthesis-upgrades.png")
	press(KEY_ESCAPE)
	await get_tree().process_frame
	check(not menu.opened and not get_tree().paused, "Escape closes menu without leaving gameplay")
	check(runner.travel("Exit1"), "Temporary ability permits transition")
	await get_tree().create_timer(0.5).timeout
	check(controller.has_dash and health.max_health == 28, "Overrides survive room transition")
	runner._apply_abilities()
	check(controller.has_dash and health.max_health == 28, "Earned-upgrade refresh preserves overrides")
	runner.preview = false
	check(runner.save_progress() == OK, "Progress save succeeds")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(runner.progress_path()))
	check("dash" not in saved.abilities and int(saved.health_upgrades) == 0, "Testing overrides never enter saved progression")
	DirAccess.remove_absolute(runner.progress_path())
	runner.preview = true
	press(KEY_F2)
	menu.set_all(false)
	for id in PlayerUpgradeMenu.MOVEMENT: check(not controller.get("has_" + id), "Disable all: " + id)
	check(combat.dagger_combo_upgrades == 0 and health.max_health == 16, "Bulk disable resets combat tiers and health")
	runner.abilities.append("double_jump")
	menu.restore_normal()
	check(controller.has_double_jump and not controller.has_dash, "Restore uses current earned world upgrades")
	check(combat.has_guided_module and combat.dagger_combo_upgrades == 2, "Restore returns original combat configuration")
	menu.set_all(true)
	for id in PlayerUpgradeMenu.MOVEMENT: check(controller.get("has_" + id), "Enable all: " + id)
	press(KEY_F2)
	check(not get_tree().paused, "F2 also resumes")
	get_tree().paused = true
	menu.open_menu()
	menu.close_menu()
	check(get_tree().paused, "Existing pause is preserved")
	get_tree().paused = false
	menu.open_menu()
	runner.queue_free()
	await get_tree().process_frame
	check(not menu.opened and not get_tree().paused, "Player removal safely closes menu")
	menu.open_menu()
	check(menu.empty_label.visible and not menu.tabs.visible, "No-player state is safe")
	menu.close_menu()
	for entry in data.rooms: DirAccess.remove_absolute(entry.path)
	print("Upgrade menu regression: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
