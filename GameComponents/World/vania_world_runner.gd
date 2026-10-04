extends Node2D
class_name VaniaWorldRunner

const PLAYER := preload("res://GameComponents/Player/player.tscn")
var world: VaniaWorldData
var preview := true
var resume_save := false
var active_room: Node2D
var current_room := ""
var player: CharacterBody2D
var camera: Camera2D
var lifecycle: PlayerLifecycleComponent
var abilities: Array = []
var collected: Array = []
var discovered: Array = []
var defeated: Array = []
var checkpoint_room := ""
var checkpoint_position := Vector2.ZERO
var health_upgrades := 0
var markers: Array[Node] = []
var cooldown := 0.0
var busy := false
var arrival_exit := ""
var fade: ColorRect
var respawning := false
var map_view: VaniaWorldMap
var hud: Label
var message := ""
var message_time := 0.0


func _ready() -> void:
	if not world or world.rooms.is_empty(): return
	var background := CanvasLayer.new()
	background.layer = -100
	add_child(background)
	var fill := ColorRect.new()
	fill.color = Color(0.045, 0.06, 0.085)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	abilities = world.starting_abilities.duplicate()
	if resume_save and not preview: load_progress()
	var first := checkpoint_room if not world.room(checkpoint_room).is_empty() else world.start_room
	if not enter_room(first): return
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = checkpoint_position if checkpoint_room == first else _room_spawn()
	add_child(player)
	var debug := player.get_node_or_null("Debug") as CanvasItem
	if debug: debug.hide()
	lifecycle = player.find_child("PlayerLifecycleComponent", true, false) as PlayerLifecycleComponent
	if checkpoint_room.is_empty():
		checkpoint_room = first
		checkpoint_position = player.global_position
	lifecycle.checkpoint_position = checkpoint_position
	lifecycle.checkpoint_changed.connect(_checkpoint_changed)
	lifecycle.respawn_started.connect(_respawn_started)
	lifecycle.respawn_finished.connect(func():
		respawning = false
		_apply_camera_bounds())
	camera = Camera2D.new()
	camera.position = Vector2(0, -64)
	player.add_child(camera)
	camera.make_current()
	_apply_abilities()
	_apply_camera_bounds()
	var ui := CanvasLayer.new()
	ui.layer = 110
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(20, 82)
	hud.add_theme_constant_override("outline_size", 6)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	ui.add_child(hud)
	map_view = VaniaWorldMap.new()
	map_view.world = world
	map_view.reveal_all = false
	map_view.position = Vector2(100, 120)
	map_view.size = get_viewport_rect().size - Vector2(200, 220)
	map_view.hide()
	ui.add_child(map_view)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notify("World test — progress is temporary." if preview else "Adventure started. Checkpoints save your progress.")


func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	cooldown = maxf(0, cooldown - delta)
	message_time = maxf(0, message_time - delta)
	if Input.is_action_just_pressed("Map") and not busy and not respawning:
		map_view.visible = not map_view.visible
		player.process_mode = Node.PROCESS_MODE_DISABLED if map_view.visible else Node.PROCESS_MODE_INHERIT
		active_room.process_mode = player.process_mode
		map_view.discovered = discovered
		map_view.selected = current_room
		map_view.queue_redraw()
	var bounds: Rect2 = world.room(current_room).bounds
	var room_origin := Vector2(world.room(current_room).position * VaniaWorldData.SCREEN)
	if not busy and not respawning and player.global_position.y > room_origin.y + bounds.size.y + 160:
		var health := player.find_child("HealthComponent", true, false) as HealthComponent
		var hit := HitData.new()
		hit.damage = health.max_health
		health.apply_hit(hit)
	var help := "Map: M / map button    Touch a transition to change rooms    Escape: editor"
	hud.text = world.room(current_room).get("name", "") + "\n" + help
	if message_time > 0: hud.text += "\n" + message
	if map_view.visible or busy or respawning: return
	var health := player.find_child("HealthComponent", true, false) as HealthComponent
	if health and health.current_health <= 0: return
	for marker in markers:
		if is_instance_valid(marker) and marker.visible and marker.kind != 0 and player.global_position.distance_to(marker.global_position) <= 40:
			collect(marker)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or busy or respawning or not map_view or map_view.visible: return
	var controller := player.find_child("CharacterController", true, false) as CharacterController
	if controller and controller.burrowing: return
	var health := player.find_child("HealthComponent", true, false) as HealthComponent
	if health.current_health <= 0 or cooldown > 0: return
	for marker in markers:
		if not is_instance_valid(marker) or marker.kind != 0 or not marker.transition_area: continue
		var touching: bool = marker.transition_area.overlaps_body(player)
		if marker.marker_id == arrival_exit:
			# Keep the arrival locked until the player has moved clear of the
			# landing space, including gravity after a vertical transition.
			if not touching and not marker.zone_rect().grow(80).has_point(marker.to_local(player.global_position)):
				arrival_exit = ""
			continue
		if not touching: continue
		var link := world.connection_for(current_room, marker.marker_id)
		if link.is_empty():
			notify("This transition is not connected.")
		elif not link.ability.is_empty() and not has_ability(link.ability):
			notify("Requires " + str(link.ability).replace("_", " "))
		else:
			travel(marker.marker_id)
			return


func enter_room(id: String, exit_id: String = "") -> bool:
	var entry := world.room(id)
	if entry.is_empty(): return false
	var packed := ResourceLoader.load(entry.path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if not packed:
		notify("Room could not be loaded: " + id)
		return false
	var next := packed.instantiate() as Node2D
	if not next:
		notify("Invalid room: " + id)
		return false
	# Place room contents at their auto-layout world position.
	next.position = Vector2(entry.position * VaniaWorldData.SCREEN) - entry.bounds.position
	for enemy in next.get_node("Entities").get_children():
		var key := id + ":" + str(enemy.name)
		if key in defeated:
			enemy.free()
			continue
		var enemy_lifecycle := enemy.find_child("EnemyLifecycleComponent", true, false) as EnemyLifecycleComponent
		if enemy_lifecycle and not enemy_lifecycle.respawn_enabled:
			var health := enemy.find_child("HealthComponent", true, false) as HealthComponent
			if health: health.died.connect(_enemy_defeated.bind(key))
	if is_instance_valid(active_room):
		remove_child(active_room)
		active_room.queue_free()
	active_room = next
	current_room = id
	add_child(active_room)
	var start := active_room.get_node_or_null("PlayerStart") as Node2D
	if start: start.hide()
	markers.clear()
	for node in active_room.get_node("Entities").get_children():
		if node is VaniaMarker:
			markers.append(node)
			node.enable_runtime()
			if node.kind == 0:
				var required: String = world.connection_for(id, node.marker_id).get("ability", "")
				node.set_gate(required, has_ability(required))
			if id + ":" + node.marker_id in collected: node.hide()
		if node is Checkpoint2D: node.one_shot = false
	if id not in discovered: discovered.append(id)
	if is_instance_valid(player):
		var destination := _room_spawn()
		for marker in markers:
			if marker.kind == 0 and marker.marker_id == exit_id: destination = marker.arrival_position()
		player.global_position = destination
		player.velocity = Vector2.ZERO
		var controller := player.find_child("CharacterController", true, false) as CharacterController
		controller.velocity = Vector2.ZERO
		controller.input_direction = Vector2.ZERO
		_apply_camera_bounds()
	arrival_exit = exit_id
	cooldown = 0.25
	return true


func _room_spawn() -> Vector2:
	var start := active_room.get_node_or_null("PlayerStart") as Node2D
	if start: return start.global_position
	return Vector2(world.room(current_room).position * VaniaWorldData.SCREEN) + Vector2(64, 64)


func travel(exit_id: String) -> bool:
	if busy or respawning: return false
	var link := world.connection_for(current_room, exit_id)
	if link.is_empty(): return false
	if world.exit_data(link.b, link.exit_b).is_empty() or world.exit_data(link.a, link.exit_a).is_empty():
		notify("This transition has an invalid destination room or door ID.")
		return false
	if not link.ability.is_empty() and not has_ability(link.ability):
		notify("Find " + str(link.ability).replace("_", " ") + " to open this route.")
		return false
	var forward: bool = link.a == current_room
	busy = true
	_travel_deferred.call_deferred(link.b if forward else link.a, link.exit_b if forward else link.exit_a)
	return true


func _travel_deferred(id: String, exit_id: String) -> void:
	player.process_mode = Node.PROCESS_MODE_DISABLED
	active_room.process_mode = Node.PROCESS_MODE_DISABLED
	var out := create_tween()
	out.tween_property(fade, "color:a", 1.0, 0.12)
	await out.finished
	if enter_room(id, exit_id): save_progress()
	active_room.process_mode = Node.PROCESS_MODE_DISABLED
	var reveal := create_tween()
	reveal.tween_property(fade, "color:a", 0.0, 0.12)
	await reveal.finished
	player.process_mode = Node.PROCESS_MODE_INHERIT
	active_room.process_mode = Node.PROCESS_MODE_INHERIT
	busy = false


func collect(marker: VaniaMarker) -> void:
	var key := current_room + ":" + marker.marker_id
	if key in collected: return
	collected.append(key)
	marker.hide()
	if marker.kind == 1:
		if marker.ability not in abilities: abilities.append(marker.ability)
		notify("Unlocked " + marker.ability.replace("_", " ") + "!")
	elif marker.kind == 2:
		health_upgrades += 1
		notify("Maximum health increased!")
	_apply_abilities()
	save_progress()


func _apply_abilities(refill: bool = true) -> void:
	var controller := player.find_child("CharacterController", true, false) as CharacterController
	for ability in VaniaWorldData.ABILITIES:
		controller.set("has_" + ability, ability in abilities)
	var health := player.find_child("HealthComponent", true, false) as HealthComponent
	var overrides: Dictionary = player.get_meta("testing_upgrade_overrides", {})
	var effective_health_upgrades := int(overrides.get("health_count", health_upgrades))
	health.set_max_health(16 + effective_health_upgrades * 4, refill)
	var upgrade_menu := get_node_or_null("/root/UpgradeMenu")
	if upgrade_menu: upgrade_menu.apply_player_overrides(player)
	for marker in markers:
		if is_instance_valid(marker) and marker.kind == 0:
			var required: String = world.connection_for(current_room, marker.marker_id).get("ability", "")
			marker.set_gate(required, has_ability(required))


func _apply_camera_bounds() -> void:
	if not camera: return
	var entry := world.room(current_room)
	var origin := Vector2(entry.position * VaniaWorldData.SCREEN)
	camera.limit_left = int(origin.x)
	camera.limit_top = int(origin.y)
	camera.limit_right = int(origin.x + entry.bounds.size.x)
	camera.limit_bottom = int(origin.y + entry.bounds.size.y)
	camera.reset_smoothing()
	camera.force_update_scroll()


func _checkpoint_changed(position: Vector2) -> void:
	checkpoint_room = current_room
	checkpoint_position = position
	var health := player.find_child("HealthComponent", true, false) as HealthComponent
	health.restore_full()
	if save_progress() == OK:
		notify("Checkpoint activated." if preview else "Checkpoint saved.")


func _respawn_started() -> void:
	respawning = true
	_restore_checkpoint_room.call_deferred()


func _restore_checkpoint_room() -> void:
	if current_room != checkpoint_room:
		enter_room(checkpoint_room)
	lifecycle.checkpoint_position = checkpoint_position


func _enemy_defeated(_hit: HitData, key: String) -> void:
	if key not in defeated: defeated.append(key)
	save_progress()


func progress_path() -> String:
	return "user://world_progress/%s.json" % world.world_id.validate_filename()


func save_progress() -> Error:
	if preview: return OK
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://world_progress"))
	var data := {"version": 1, "world_id": world.world_id, "checkpoint_room": checkpoint_room,
		"checkpoint": [checkpoint_position.x - float(world.room(checkpoint_room).position.x * VaniaWorldData.SCREEN.x), checkpoint_position.y - float(world.room(checkpoint_room).position.y * VaniaWorldData.SCREEN.y)], "abilities": abilities,
		"collected": collected, "discovered": discovered, "defeated": defeated, "health_upgrades": health_upgrades}
	var path := progress_path()
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if not file:
		notify("Could not save progress.")
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	var error := DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK: notify("Could not save progress: " + error_string(error))
	return error


func load_progress() -> bool:
	if not FileAccess.file_exists(progress_path()): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(progress_path()))
	if not data is Dictionary or data.get("version") != 1 or data.get("world_id") != world.world_id: return false
	if world.room(str(data.get("checkpoint_room", ""))).is_empty(): return false
	var point: Variant = data.get("checkpoint")
	if not point is Array or point.size() != 2: return false
	for key in ["abilities", "collected", "discovered", "defeated"]:
		if not data.get(key) is Array: return false
	checkpoint_room = data.checkpoint_room
	checkpoint_position = Vector2(float(point[0]), float(point[1])) + Vector2(world.room(checkpoint_room).position * VaniaWorldData.SCREEN)
	abilities = data.abilities
	collected = data.collected
	discovered = data.discovered
	defeated = data.defeated
	health_upgrades = clampi(int(data.get("health_upgrades", 0)), 0, 200)
	return true


func notify(text: String) -> void:
	message = text
	message_time = 4



func has_ability(id: String) -> bool:
	if is_instance_valid(player):
		var overrides: Dictionary = player.get_meta("testing_upgrade_overrides", {})
		if overrides.has(id): return bool(overrides[id])
	return id in abilities


func refresh_upgrade_overrides() -> void:
	_apply_abilities(false)
