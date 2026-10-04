extends Node

var failures := 0
var directory := ""

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func make_room(name: String, side: int, ability: String = "") -> String:
	var root := Node2D.new()
	root.name = name
	var tiles := TileMapLayer.new()
	tiles.name = "TileMapLayer"
	tiles.tile_set = preload("res://GameComponents/LevelEditor/level_tileset.tres")
	root.add_child(tiles)
	tiles.owner = root
	for x in 40: tiles.set_cell(Vector2i(x, 10), 0, Vector2i.ZERO)
	var entities := Node2D.new()
	entities.name = "Entities"
	root.add_child(entities)
	entities.owner = root
	var exit := VaniaMarker.new()
	exit.name = "Exit"
	exit.marker_id = "door"
	exit.side = side
	exit.position = Vector2(160, 96 if side == 2 else 304)
	entities.add_child(exit)
	exit.owner = root
	if not ability.is_empty():
		var pickup := VaniaMarker.new()
		pickup.name = "Pickup"
		pickup.kind = 1
		pickup.marker_id = "upgrade"
		pickup.ability = ability
		pickup.position = Vector2(240, 304)
		entities.add_child(pickup)
		pickup.owner = root
	if name == "second":
		var upgrade := VaniaMarker.new()
		upgrade.name = "HealthUpgrade"
		upgrade.kind = 2
		upgrade.marker_id = "health"
		upgrade.position = Vector2(320, 304)
		entities.add_child(upgrade)
		upgrade.owner = root
	var start := Node2D.new()
	start.name = "PlayerStart"
	start.position = Vector2(64 if side >= 2 else 96, 304)
	root.add_child(start)
	start.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	var path := directory.path_join(name + ".tscn")
	check(ResourceSaver.save(scene, path) == OK, "Fixture saved")
	root.free()
	return path

func run() -> void:
	directory = "user://vania_test_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var first := make_room("first", 1, "dash")
	var second := make_room("second", 0)
	var data := VaniaWorldData.new()
	data.world_id = "regression_" + str(Time.get_ticks_usec())
	check(data.add_room(first).is_empty(), "First room added")
	check(data.add_room(second).is_empty(), "Second room added")
	check(not data.add_room(first).is_empty(), "Duplicate room rejected")
	check(data.rooms[0].bounds.size == Vector2(1280, 736), "Bounds fit contents to one screen")
	data.room("second").exits[0].side = 1
	check(not data.connect_rooms("first", "door", "second", "door").is_empty(), "Same-facing exits rejected")
	data.room("second").exits[0].side = 0
	var tall := {"position": Vector2i.ZERO, "bounds": Rect2(0, 0, 1280, 1472)}
	var small := {"position": Vector2i.ZERO, "bounds": Rect2(0, 0, 1280, 736)}
	check(data.adjacent_position(tall, small, 1, {"position": Vector2(1200, 1000)}, {"position": Vector2(64, 320)}) == Vector2i(1, 1), "Tall-room exit aligns to correct screen row")
	check(data.connect_rooms("first", "door", "second", "door", "dash").is_empty(), "Opposite doors connected")
	check(data.room("second").position == Vector2i(1, 0), "Second room automatically placed to right")
	check(data.validate().is_empty(), "Reachable upgrade passes checks")
	check(not data.connect_rooms("first", "door", "second", "door").is_empty(), "Reused exits rejected")
	data.room("first").abilities.clear()
	data.room("second").abilities.append("dash")
	check(not data.validate().is_empty(), "Upgrade behind own gate reported")
	data.refresh_rooms()
	var world_path := directory.path_join("world.tres")
	check(ResourceSaver.save(data, world_path) == OK, "World saved")
	var loaded := ResourceLoader.load(world_path, "", ResourceLoader.CACHE_MODE_REPLACE) as VaniaWorldData
	check(loaded.connections.size() == 1 and loaded.rooms.size() == 2, "World topology roundtrips")
	var runner := VaniaWorldRunner.new()
	runner.world = loaded
	runner.preview = true
	add_child(runner)
	await get_tree().process_frame
	check(runner.current_room == "first", "Starts in selected room")
	runner.player.global_position = runner.active_room.get_node("Entities/Exit").global_position
	runner.cooldown = 0
	await get_tree().create_timer(0.35).timeout
	check(runner.current_room == "first", "Touching a locked area cannot travel")
	check(not runner.travel("door"), "Gate blocks missing ability")
	var pickup := runner.active_room.get_node("Entities/Pickup") as VaniaMarker
	runner.collect(pickup)
	runner.player.global_position = runner.active_room.get_node("Entities/Exit").global_position
	check("dash" in runner.abilities, "Collect grants ability")
	var controller := runner.player.find_child("CharacterController", true, false) as CharacterController
	check(controller.has_dash and not controller.has_double_jump, "Unlocks control actual movement")
	check(not FileAccess.file_exists(runner.progress_path()), "Preview never writes progression")
	await get_tree().create_timer(0.65).timeout
	check(runner.current_room == "second", "Destination loaded")
	check(runner.camera.limit_left == 1280, "Camera uses world-positioned bounds")
	check(runner.player.global_position.distance_to(runner.active_room.get_node("Entities/Exit").arrival_position()) < 4.0, "Arrives safely inside paired area")
	runner.collect(runner.active_room.get_node("Entities/HealthUpgrade") as VaniaMarker)
	runner.collect(runner.active_room.get_node("Entities/HealthUpgrade") as VaniaMarker)
	check(runner.health_upgrades == 1, "Health upgrade cannot be collected twice")
	check((runner.player.find_child("HealthComponent", true, false) as HealthComponent).max_health == 20, "Health upgrade increases actual health cap")
	await get_tree().create_timer(0.4).timeout
	check(runner.current_room == "second", "No automatic bounce back while arriving")
	var return_marker := runner.active_room.get_node("Entities/Exit") as VaniaMarker
	runner.player.global_position = return_marker.arrival_position() + Vector2(96, 0)
	await get_tree().create_timer(0.1).timeout
	runner.player.global_position = return_marker.global_position
	await get_tree().create_timer(0.65).timeout
	check(runner.current_room == "first", "Touch area works in reverse without pressing Up")
	check(not runner.active_room.get_node("Entities/Pickup").visible, "Collected upgrade remains absent")
	check(runner.travel("door"), "Travel away from checkpoint")
	await get_tree().create_timer(0.4).timeout
	var hit := HitData.new()
	hit.damage = 999
	var health := runner.player.find_child("HealthComponent", true, false) as HealthComponent
	health.apply_hit(hit)
	await get_tree().create_timer(1.0).timeout
	check(runner.current_room == "first", "Death returns to checkpoint room")
	check(not runner.respawning and health.current_health == health.max_health, "Death completes and restores health")
	runner.preview = false
	check(runner.save_progress() == OK, "Persistent save succeeds")
	check(runner.save_progress() == OK, "Existing progress file can be replaced atomically")
	var save_path := runner.progress_path()
	var restored := VaniaWorldRunner.new()
	restored.world = data
	check(restored.load_progress(), "Persistent save reloads")
	check("dash" in restored.abilities and restored.collected.size() == 2 and restored.health_upgrades == 1, "Upgrade state roundtrips")
	check(restored.discovered.size() == 2, "Exploration roundtrips")
	restored.free()
	runner.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(save_path)
	for file in [first, second, world_path]: DirAccess.remove_absolute(file)
	var upper_path := make_room("upper", 3)
	var lower_path := make_room("lower", 2)
	var vertical := VaniaWorldData.new()
	vertical.add_room(upper_path)
	vertical.add_room(lower_path)
	check(vertical.connect_rooms("upper", "door", "lower", "door").is_empty(), "Vertical rooms connect")
	var vertical_runner := VaniaWorldRunner.new()
	vertical_runner.world = vertical
	add_child(vertical_runner)
	await get_tree().process_frame
	vertical_runner.player.global_position = vertical_runner.active_room.get_node("Entities/Exit").global_position
	vertical_runner.cooldown = 0
	await get_tree().create_timer(0.65).timeout
	check(vertical_runner.current_room == "lower", "Touching downward transition enters lower room")
	await get_tree().create_timer(0.35).timeout
	check(vertical_runner.current_room == "lower", "Vertical arrival cannot bounce back")
	vertical_runner.player.global_position = vertical_runner.active_room.get_node("Entities/Exit").global_position
	await get_tree().create_timer(0.65).timeout
	check(vertical_runner.current_room == "upper", "Touching upward transition returns to upper room")
	vertical_runner.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(upper_path)
	DirAccess.remove_absolute(lower_path)
	DirAccess.remove_absolute(directory)
	var starter := VaniaStarter.create()
	check(starter != null and starter.validate().is_empty(), "Playable starter world validates")
	var editor := load("res://GameComponents/LevelEditor/level_editor.tscn").instantiate() as SimpleLevelEditor
	get_tree().root.add_child(editor)
	await get_tree().process_frame
	editor.world_panel.world = starter
	editor.world_panel.world_name.text = starter.display_name
	editor.world_panel._refresh_ui()
	editor._select_panel_tab(4)
	await get_tree().create_timer(0.3).timeout
	check(editor.world_panel.visible, "World opens a dedicated full-screen workspace")
	check(editor.world_panel.map_view.editable, "Full-screen map supports editing")
	editor.world_panel.world.connections.clear()
	editor.world_panel._refresh_ui()
	var room_a: String = starter.rooms[0].id
	var room_b: String = starter.rooms[1].id
	editor.world_panel._pick_exit(room_a, "Exit1")
	check(editor.world_panel.connect_button.disabled, "Connection waits for second area")
	editor.world_panel._pick_exit(room_b, "Exit1")
	check(not editor.world_panel.connect_button.disabled, "Compatible pair enables connection")
	editor.world_panel.gate_ability.select(1)
	editor.world_panel._connect_rooms()
	check(editor.world_panel.world.connections.size() == 1, "Visual selection creates connection")
	check(editor.world_panel.pending.is_empty(), "Connection selection clears after connecting")
	if "--capture-world" in OS.get_cmdline_user_args():
		editor.world_panel.inspector_tabs.current_tab = 0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/synthesis-world-editor.png")
	editor._play_adventure(starter, true, false)
	await get_tree().create_timer(0.3).timeout
	if "--capture-world" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/synthesis-world-play.png")
	editor._stop_playing()
	check(editor.world_panel.visible, "Playtest returns to the world workspace")
	editor.world_panel.close_workspace()
	check(not editor.world_panel.visible, "Back returns to room editing")
	editor._load_level_path(starter.rooms[0].path)
	var editable_exit := editor.entities.get_node("Exit1") as VaniaMarker
	editor.world_panel.edit_transition(editable_exit)
	var dialog := editor.world_panel.get_child(-1) as ConfirmationDialog
	check(dialog != null and dialog.visible, "Clicking a transition opens its settings")
	if "--capture-transition" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/synthesis-transition-settings.png")
	var options := dialog.find_children("*", "OptionButton", true, false)
	var destinations := options[0] as OptionButton
	for i in destinations.item_count:
		if destinations.get_item_metadata(i) == room_b: destinations.select(i)
	destinations.item_selected.emit(destinations.selected)
	check(options[1].item_count > 0, "Destination picker lists saved door IDs")
	dialog.get_ok_button().pressed.emit()
	check(editable_exit.destination_room == room_b and editable_exit.destination_door == "Exit1", "Apply stores chosen room and door")
	editor._save_level()
	starter.refresh_rooms()
	var explicit_link := starter.connection_for(room_a, "Exit1")
	check(explicit_link.get("directed", false) and explicit_link.b == room_b, "Saved area destination overrides the old map connection")
	check(starter.connection_for(room_b, "Exit1").is_empty(), "Area destinations do not create an unwanted return route")
	await get_tree().process_frame
	editor.queue_free()
	await get_tree().process_frame
	var explicit_runner := VaniaWorldRunner.new()
	explicit_runner.world = starter
	add_child(explicit_runner)
	await get_tree().process_frame
	check(explicit_runner.travel("Exit1"), "Area-authored route starts a room transition")
	await get_tree().create_timer(0.4).timeout
	check(explicit_runner.current_room == room_b and explicit_runner.arrival_exit == "Exit1", "Arrives at the configured destination door")
	explicit_runner.queue_free()
	await get_tree().process_frame
	for entry in starter.rooms: DirAccess.remove_absolute(entry.path)
	print("Metroidvania regression: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
