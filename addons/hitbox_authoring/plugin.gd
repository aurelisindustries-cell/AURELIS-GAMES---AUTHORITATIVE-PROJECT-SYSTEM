@tool
extends EditorPlugin

var _button: Button
var _status: Label
var _dock: VBoxContainer
var _active_spawner: HitboxSpawner2D
var _last_animation_player: AnimationPlayer
var _last_animation: StringName


func _enter_tree() -> void:
	_button = Button.new()
	_button.text = "Add Hitbox"
	_button.tooltip_text = "Add a hitbox at the current AnimationPlayer time"
	_button.pressed.connect(_add_hitbox)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _button)

	_dock = VBoxContainer.new()
	_dock.name = "Hitboxes"
	var heading := Label.new()
	heading.text = "Animation Hitboxes"
	_dock.add_child(heading)
	var add_button := Button.new()
	add_button.text = "Add Hitbox at Current Time"
	add_button.pressed.connect(_add_hitbox)
	_dock.add_child(add_button)
	var key_button := Button.new()
	key_button.text = "Key Selected Hitbox Position"
	key_button.pressed.connect(_key_selected_hitbox_position)
	_dock.add_child(key_button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Select an AnimationPlayer or HitboxSpawner2D."
	_dock.add_child(_status)
	add_control_to_bottom_panel(_dock, "Hitboxes")
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)


func _exit_tree() -> void:
	_hide_active_preview()
	if get_editor_interface().get_selection().selection_changed.is_connected(_selection_changed):
		get_editor_interface().get_selection().selection_changed.disconnect(_selection_changed)
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _button)
	remove_control_from_bottom_panel(_dock)
	_button.queue_free()
	_dock.queue_free()


func _process(_delta: float) -> void:
	var context := _find_context()
	var player := context.get("player") as AnimationPlayer
	var spawner := context.get("spawner") as HitboxSpawner2D
	var animation_name := _get_editor_animation(player)
	if spawner != _active_spawner:
		_hide_active_preview()
		_active_spawner = spawner
	if not player or not spawner or animation_name.is_empty():
		if _active_spawner:
			_deactivate_all_handles(_active_spawner)
			_active_spawner.hide_editor_preview()
		_last_animation_player = null
		_last_animation = &""
		_status.text = "Select an AnimationPlayer with an active animation."
		return
	if player != _last_animation_player or animation_name != _last_animation:
		_deactivate_all_handles(spawner)
		_last_animation_player = player
		_last_animation = animation_name
		player.seek(player.current_animation_position, true)
	spawner.show_editor_preview(animation_name, player.current_animation_position)
	_status.text = "%s  •  %.3fs  •  %d hitboxes" % [animation_name, player.current_animation_position, _count_handles(spawner)]


func _add_hitbox() -> void:
	var context := _find_context()
	var player := context.get("player") as AnimationPlayer
	var spawner := context.get("spawner") as HitboxSpawner2D
	var animation_name := _get_editor_animation(player)
	if not player:
		_status.text = "Select an AnimationPlayer first."
		return
	if animation_name.is_empty():
		_status.text = "Choose an animation in the Animation panel first."
		return
	if not spawner:
		spawner = _create_spawner(player)
	var handle := HitboxAuthoringHandle2D.new()
	handle.name = _unique_handle_name(spawner, animation_name)
	handle.shape = RectangleShape2D.new()
	(handle.shape as RectangleShape2D).size = Vector2(32.0, 24.0)
	handle.hit = HitData.new()
	spawner.add_child(handle)
	handle.owner = get_editor_interface().get_edited_scene_root()
	_add_timeline_tracks(player, handle, player.current_animation_position, 0.1)
	_active_spawner = spawner
	var selection := get_editor_interface().get_selection()
	selection.clear()
	selection.add_node(handle)
	_status.text = "Hitbox added. Move the handle, then key Position in the Inspector."


func _add_timeline_tracks(player: AnimationPlayer, handle: HitboxAuthoringHandle2D, start_time: float, duration: float) -> void:
	var animation := player.get_animation(_get_editor_animation(player))
	var root := player.get_node(player.root_node)
	var node_path := root.get_path_to(handle)
	var active_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(active_track, NodePath("%s:active" % node_path))
	animation.value_track_set_update_mode(active_track, Animation.UPDATE_DISCRETE)
	if start_time > 0.0:
		animation.track_insert_key(active_track, 0.0, false)
	animation.track_insert_key(active_track, start_time, true)
	animation.track_insert_key(active_track, minf(start_time + duration, animation.length), false)
	var position_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, NodePath("%s:position" % node_path))
	animation.track_insert_key(position_track, start_time, handle.position)


func _unique_handle_name(spawner: HitboxSpawner2D, animation_name: StringName) -> String:
	var base := "Hitbox_%s" % String(animation_name).to_snake_case()
	var candidate := base
	var suffix := 2
	while spawner.has_node(candidate):
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return candidate


func _key_selected_hitbox_position() -> void:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty() or not selected[0] is HitboxAuthoringHandle2D:
		_status.text = "Select a hitbox handle first."
		return
	var handle := selected[0] as HitboxAuthoringHandle2D
	var context := _find_context()
	var player := context.get("player") as AnimationPlayer
	var animation_name := _get_editor_animation(player)
	if not player or animation_name.is_empty():
		_status.text = "Choose an animation and playhead position first."
		return
	var animation := player.get_animation(animation_name)
	var root := player.get_node(player.root_node)
	var property_path := NodePath("%s:position" % root.get_path_to(handle))
	var track := animation.find_track(property_path, Animation.TYPE_VALUE)
	if track < 0:
		track = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, property_path)
	animation.track_insert_key(track, player.current_animation_position, handle.position)
	_status.text = "Position keyed at %.3fs." % player.current_animation_position


func _count_handles(spawner: HitboxSpawner2D) -> int:
	var count := 0
	for child in spawner.get_children():
		if child is HitboxAuthoringHandle2D:
			count += 1
	return count


func _create_spawner(player: AnimationPlayer) -> HitboxSpawner2D:
	var spawner := HitboxSpawner2D.new()
	spawner.name = "HitboxSpawner2D"
	spawner.animation_player = player
	spawner.attack_source = player.get_parent()
	player.get_parent().add_child(spawner)
	spawner.owner = player.owner if player.owner else player.get_parent()
	return spawner


func _select_preview(spawner: HitboxSpawner2D, data: HitboxFrameData) -> void:
	var preview := spawner.get_preview_for(data)
	if not preview:
		return
	var selection := get_editor_interface().get_selection()
	selection.clear()
	selection.add_node(preview)


func _selection_changed() -> void:
	var context := _find_context()
	if not context.get("spawner"):
		_hide_active_preview()


func _find_context() -> Dictionary:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		return {}
	var node := selected[0] as Node
	var player := node as AnimationPlayer
	var spawner := node as HitboxSpawner2D
	var cursor := node
	while cursor and not spawner:
		spawner = cursor as HitboxSpawner2D
		cursor = cursor.get_parent()
	if spawner and not player:
		player = spawner.animation_player
	if player and not spawner:
		spawner = player.get_parent().get_node_or_null("HitboxSpawner2D") as HitboxSpawner2D
	return {"player": player, "spawner": spawner}


func _hide_active_preview() -> void:
	if _active_spawner:
		_deactivate_all_handles(_active_spawner)
		_active_spawner.hide_editor_preview()
	_active_spawner = null
	_last_animation_player = null
	_last_animation = &""


func _deactivate_all_handles(spawner: HitboxSpawner2D) -> void:
	for child in spawner.get_children():
		if child is HitboxAuthoringHandle2D:
			(child as HitboxAuthoringHandle2D).active = false


func _get_editor_animation(player: AnimationPlayer) -> StringName:
	if not player:
		return &""
	if not player.assigned_animation.is_empty():
		return player.assigned_animation
	return player.current_animation
