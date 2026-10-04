extends Node2D
class_name SimpleLevelEditor

enum Tool { TILE, PLAYER_START, PATROL, CHASER, FLYING, CHECKPOINT, ERASE, CURSOR, FLYING_PATROL, WORLD_MARKER, BURROW_SOIL }
enum PaintMode { PENCIL, LINE, RECTANGLE }

const TILE_SET := preload("res://GameComponents/LevelEditor/level_tileset.tres")
const PATROL_ENEMY := preload("res://GameComponents/Enemies/patrol_enemy.tscn")
const CHASE_ENEMY := preload("res://GameComponents/Enemies/chase_enemy.tscn")
const FLYING_ENEMY := preload("res://GameComponents/Enemies/flying_enemy.tscn")
const FLYING_PATROL_ENEMY := preload("res://GameComponents/Enemies/flying_patrol_enemy.tscn")
const CHECKPOINT := preload("res://GameComponents/Interaction/checkpoint_2d.tscn")
const BURROW_SOIL := preload("res://GameComponents/Interaction/burrow_soil.tscn")
const PLAYER := preload("res://GameComponents/Player/player.tscn")
const TILE_TEXTURE := preload("res://Assets/Sprites/Tilesets/TestTileset.png")
const LEVEL_DIRECTORY := "user://levels"
const CELL_SIZE := 32

var current_tool := Tool.TILE
var undo_steps: Array[PackedScene] = []
var redo_steps: Array[PackedScene] = []
var gesture_recorded := false
var gesture_active := false
var clipboard_tiles: Array[Dictionary] = []
var clipboard_objects: Array[Dictionary] = []
var erase_previous := Vector2i(999999, 999999)
var selected_tile := Vector2i.ZERO
var level_root: Node2D
var tile_layer: TileMapLayer
var entities: Node2D
var editor_camera: Camera2D
var name_edit: LineEdit
var level_list: OptionButton
var status_label: Label
var editor_ui: CanvasLayer
var rotation_button: Button
var tool_buttons: Array[Button] = []
var tile_buttons: Array[Button] = []
var paint_buttons: Array[Button] = []
var panel_tabs: Array[Button] = []
var panel_pages: Array[Control] = []
var panel_content: PanelContainer
var selected_panel_tab := -1
var dragging_camera := false
var last_mouse_position := Vector2.ZERO
var last_painted_cell := Vector2i(999999, 999999)
var tile_rotation := 0
var paint_mode := PaintMode.PENCIL
var shape_dragging := false
var shape_start_cell := Vector2i.ZERO
var shape_preview_layer: TileMapLayer
var placement_preview: Node2D
var preview_cell := Vector2i.ZERO
var play_player: Node2D
var is_playing := false
var selected_cells: Array[Vector2i] = []
var selected_entities: Array[Node2D] = []
var cursor_drag_start := Vector2i.ZERO
var cursor_drag_current := Vector2i.ZERO
var cursor_marquee_dragging := false
var cursor_move_dragging := false
var patrol_target: Node2D
var patrol_point_key := ""
var patrol_title: Label
var patrol_controls: VBoxContainer
var patrol_pause: SpinBox
var patrol_speed: SpinBox
var patrol_start: CheckButton
var patrol_point_buttons: Array[Button] = []
var play_world: Node2D
var panel_scroll: ScrollContainer
var patrol_overlay: Node2D
var drawer_clip: Control
var tab_rail: VBoxContainer
var drawer_open := false
var drawer_tween: Tween
var world_panel: VaniaWorldEditor
const DRAWER_WIDTH := 350.0
const TAB_WIDTH := 92.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LEVEL_DIRECTORY))
	_build_world()
	_build_interface()
	_refresh_level_list()
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = false


func _exit_tree() -> void:
	if is_instance_valid(level_root) and not level_root.is_inside_tree():
		level_root.free()
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = true


func _input(event: InputEvent) -> void:
	if not is_playing and event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			gesture_active = true
			gesture_recorded = false
			erase_previous = Vector2i(999999, 999999)
		else:
			_end_edit_gesture.call_deferred()
	# A release over a panel is consumed by the GUI, but must still end a drag.
	if is_playing or not event is InputEventMouseButton or event.pressed: return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		dragging_camera = false
	if event.button_index == MOUSE_BUTTON_LEFT and _mouse_over_interface():
		_cancel_shape_paint()
		cursor_move_dragging = false
		cursor_marquee_dragging = false
		last_painted_cell = Vector2i(999999, 999999)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing and world_panel and world_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			world_panel.close_workspace()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not patrol_point_key.is_empty():
			_cancel_patrol_placement()
			return
		if is_playing:
			_stop_playing()
			get_viewport().set_input_as_handled()
			return
		get_tree().change_scene_to_file("res://GameComponents/Scenes/test_world.tscn")
		return
	if is_playing: return
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit: return
		match event.keycode:
			KEY_Z: _redo_edit() if event.shift_pressed else _undo_edit()
			KEY_Y: _redo_edit()
			KEY_C: _copy_selection()
			KEY_V: _paste_selection(_mouse_cell())
			_: return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_rotate_tile()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE and current_tool == Tool.CURSOR:
		_delete_selection()
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			dragging_camera = mouse_button.pressed
			last_mouse_position = mouse_button.position
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_set_zoom(editor_camera.zoom.x * 1.12)
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_set_zoom(editor_camera.zoom.x / 1.12)
			return
		if _mouse_over_interface(): return
		if not patrol_point_key.is_empty():
			if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
				_place_patrol_point(_mouse_cell())
			elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_patrol_placement()
			return
		if current_tool == Tool.CURSOR and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed: _begin_cursor_drag()
			else: _finish_cursor_drag()
			return
		if current_tool == Tool.CURSOR and mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_clear_selection()
			_set_status("Selection cleared")
			queue_redraw()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				if current_tool == Tool.TILE and paint_mode != PaintMode.PENCIL:
					_begin_shape_paint()
				else:
					_apply_tool(false)
			else:
				if shape_dragging: _finish_shape_paint()
				last_painted_cell = Vector2i(999999, 999999)
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_cancel_shape_paint()
			_apply_tool(true)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not patrol_point_key.is_empty(): return
		if dragging_camera:
			editor_camera.position -= motion.relative / editor_camera.zoom
			last_mouse_position = motion.position
		elif current_tool == Tool.CURSOR and (cursor_marquee_dragging or cursor_move_dragging):
			cursor_drag_current = _mouse_cell()
			queue_redraw()
		elif not _mouse_over_interface() and ((Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and current_tool == Tool.ERASE) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and current_tool != Tool.CURSOR)):
			_apply_tool(true)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and current_tool == Tool.TILE and not _mouse_over_interface():
			if paint_mode == PaintMode.PENCIL:
				_apply_tool(false)
			elif shape_dragging:
				_update_shape_preview(_mouse_cell())


func _process(delta: float) -> void:
	if is_playing or (world_panel and world_panel.visible): return
	var pan := Input.get_vector(&"Left", &"Right", &"Up", &"Down")
	if pan != Vector2.ZERO and not get_viewport().gui_get_focus_owner() is LineEdit:
		editor_camera.position += pan * 620.0 * delta / editor_camera.zoom.x
	_update_placement_preview()
	patrol_overlay.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if is_playing or not tile_layer or not editor_camera: return
	var viewport_size := get_viewport_rect().size / editor_camera.zoom
	var top_left := editor_camera.position - viewport_size * 0.5
	var bottom_right := editor_camera.position + viewport_size * 0.5
	var start_x := floori(top_left.x / CELL_SIZE) * CELL_SIZE
	var start_y := floori(top_left.y / CELL_SIZE) * CELL_SIZE
	for x in range(start_x, ceili(bottom_right.x) + CELL_SIZE, CELL_SIZE):
		draw_line(Vector2(x, top_left.y), Vector2(x, bottom_right.y), Color(0.4, 0.7, 0.9, 0.12), 1.0)
	for y in range(start_y, ceili(bottom_right.y) + CELL_SIZE, CELL_SIZE):
		draw_line(Vector2(top_left.x, y), Vector2(bottom_right.x, y), Color(0.4, 0.7, 0.9, 0.12), 1.0)
	_draw_cursor_selection()
	if selected_panel_tab == 3 and drawer_open:
		var bounds := VaniaWorldData.measure_room(level_root)
		draw_rect(bounds, Color(0.4, 0.9, 1.0), false, 3.0)


func _end_edit_gesture() -> void:
	gesture_active = false
	gesture_recorded = false
	erase_previous = Vector2i(999999, 999999)


func _snapshot() -> PackedScene:
	_own_level_nodes(level_root)
	var packed := PackedScene.new()
	packed.pack(level_root)
	return packed.duplicate(true) as PackedScene


func _record_edit() -> void:
	if gesture_active and gesture_recorded: return
	undo_steps.append(_snapshot())
	if undo_steps.size() > 50: undo_steps.pop_front()
	redo_steps.clear()
	gesture_recorded = gesture_active


func _restore_snapshot(packed: PackedScene) -> void:
	_cancel_shape_paint()
	_cancel_patrol_placement()
	_clear_selection()
	remove_child(level_root)
	level_root.queue_free()
	level_root = packed.instantiate() as Node2D
	tile_layer = level_root.get_node("TileMapLayer")
	entities = level_root.get_node("Entities")
	add_child(level_root)
	_set_entities_editing(true)
	_ensure_shape_preview_layer()
	_end_edit_gesture()
	queue_redraw()


func _undo_edit() -> void:
	if undo_steps.is_empty(): return
	redo_steps.append(_snapshot())
	_restore_snapshot(undo_steps.pop_back())
	_set_status("Undo")


func _redo_edit() -> void:
	if redo_steps.is_empty(): return
	undo_steps.append(_snapshot())
	_restore_snapshot(redo_steps.pop_back())
	_set_status("Redo")


func _erase_stroke_to(cell: Vector2i) -> void:
	var start := cell if erase_previous == Vector2i(999999, 999999) else erase_previous
	var difference := cell - start
	var count := maxi(absi(difference.x), absi(difference.y))
	for i in range(count + 1):
		var at := Vector2i(Vector2(start).lerp(Vector2(cell), float(i) / maxf(1, count)).round())
		if tile_layer.get_cell_source_id(at) < 0 and _entities_at_cell(at).is_empty(): continue
		_record_edit()
		tile_layer.erase_cell(at)
		_erase_entity_at(at)
	erase_previous = cell


func _clipboard_own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty(): _clipboard_own(child, root)


func _copy_selection() -> void:
	if selected_cells.is_empty() and selected_entities.is_empty():
		_set_status("Use Select / Move to select tiles or objects first.")
		return
	clipboard_tiles.clear()
	clipboard_objects.clear()
	var anchor := Vector2i(2147483647, 2147483647)
	for cell in selected_cells: anchor = anchor.min(cell)
	for node in selected_entities:
		anchor = anchor.min(tile_layer.local_to_map(tile_layer.to_local(node.global_position)))
	var origin := tile_layer.to_global(tile_layer.map_to_local(anchor))
	for cell in selected_cells:
		if tile_layer.get_cell_source_id(cell) >= 0:
			clipboard_tiles.append({"offset": cell - anchor, "source": tile_layer.get_cell_source_id(cell), "atlas": tile_layer.get_cell_atlas_coords(cell), "alternative": tile_layer.get_cell_alternative_tile(cell)})
	for node in selected_entities:
		var clone := node.duplicate() as Node2D
		_clipboard_own(clone, clone)
		var packed := PackedScene.new()
		packed.pack(clone)
		clipboard_objects.append({"scene": packed.duplicate(true), "offset": node.global_position - origin, "start": node.name == "PlayerStart"})
		clone.free()
	_set_status("Copied %d tiles and %d objects. Ctrl+V pastes at the pointer." % [clipboard_tiles.size(), clipboard_objects.size()])


func _paste_selection(cell: Vector2i) -> void:
	if clipboard_tiles.is_empty() and clipboard_objects.is_empty(): return
	_record_edit()
	_clear_selection()
	_select_tool(Tool.CURSOR)
	var origin := tile_layer.to_global(tile_layer.map_to_local(cell))
	for tile in clipboard_tiles:
		var destination: Vector2i = cell + tile.offset
		tile_layer.set_cell(destination, tile.source, tile.atlas, tile.alternative)
		selected_cells.append(destination)
	for item in clipboard_objects:
		var node := (item.scene as PackedScene).instantiate() as Node2D
		if item.start:
			var previous := level_root.get_node_or_null("PlayerStart")
			if previous:
				level_root.remove_child(previous)
				previous.queue_free()
			node.name = "PlayerStart"
		if node is VaniaMarker:
			node.marker_id = "copy_%d_%d" % [Time.get_ticks_usec(), selected_entities.size()]
			node.name = node.marker_id
		node.process_mode = Node.PROCESS_MODE_DISABLED
		var parent := level_root if item.start else entities
		node.position = parent.to_local(origin + Vector2(item.offset))
		parent.add_child(node, true)
		node.owner = level_root
		_prepare_patrol_for_editing(node)
		selected_entities.append(node)
	_refresh_patrol_controls()
	queue_redraw()
	_set_status("Pasted selection. Drag it to move, or Ctrl+Z to undo.")


func _build_world() -> void:
	editor_camera = Camera2D.new()
	editor_camera.name = "EditorCamera"
	editor_camera.position = Vector2(640, 360)
	add_child(editor_camera)
	patrol_overlay = Node2D.new()
	patrol_overlay.z_index = 101
	patrol_overlay.draw.connect(_draw_patrol_route)
	add_child(patrol_overlay)
	_new_level()


func _new_level() -> void:
	undo_steps.clear()
	redo_steps.clear()
	_clear_selection()
	if is_instance_valid(level_root): level_root.queue_free()
	level_root = Node2D.new()
	level_root.name = "CreatedLevel"
	add_child(level_root)
	tile_layer = TileMapLayer.new()
	tile_layer.name = "TileMapLayer"
	tile_layer.tile_set = TILE_SET
	level_root.add_child(tile_layer)
	entities = Node2D.new()
	entities.name = "Entities"
	level_root.add_child(entities)
	_ensure_shape_preview_layer()
	if name_edit: name_edit.text = "new_level"
	_set_status("New level")
	_rebuild_placement_preview()


func _build_interface() -> void:
	editor_ui = CanvasLayer.new()
	editor_ui.name = "EditorUI"
	editor_ui.layer = 100
	add_child(editor_ui)
	drawer_clip = Control.new()
	drawer_clip.clip_contents = true
	drawer_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor_ui.add_child(drawer_clip)
	tab_rail = VBoxContainer.new()
	tab_rail.add_theme_constant_override("separation", 20)
	editor_ui.add_child(tab_rail)
	_add_panel_tab(tab_rail, "TILES", 0)
	_add_panel_tab(tab_rail, "OBJECTS", 1)
	_add_panel_tab(tab_rail, "LEVEL", 2)
	_add_panel_tab(tab_rail, "ROOM", 3)
	_add_panel_tab(tab_rail, "WORLD", 4)
	panel_content = PanelContainer.new()
	panel_content.custom_minimum_size = Vector2(DRAWER_WIDTH, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.075, 0.095, 0.12, 0.98)
	panel_style.set_corner_radius_all(6)
	panel_content.add_theme_stylebox_override("panel", panel_style)
	drawer_clip.add_child(panel_content)
	panel_content.position.x = DRAWER_WIDTH
	panel_content.hide()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel_scroll = ScrollContainer.new()
	panel_scroll.custom_minimum_size = Vector2(DRAWER_WIDTH, 0)
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_content.add_child(panel_scroll)
	panel_scroll.add_child(margin)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	get_viewport().size_changed.connect(_resize_panel)
	_resize_panel()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "LEVEL EDITOR"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	layout.add_child(title)
	var instructions := Label.new()
	instructions.text = "Choose a tool, then click in the level.\nClick the side tab again to tuck it away."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_color_override("font_color", Color(0.7, 0.76, 0.82))
	layout.add_child(instructions)
	layout.add_child(HSeparator.new())
	var tile_page := VBoxContainer.new()
	tile_page.add_theme_constant_override("separation", 8)
	layout.add_child(tile_page)
	panel_pages.append(tile_page)
	var edit_section := _add_section(tile_page, "Select & move")
	_add_tool_button(edit_section, "Select / Move", Tool.CURSOR)
	var cursor_help := Label.new()
	cursor_help.text = "Drag empty space to box select\nShift+drag: add    Delete: remove\nCtrl+C / V: copy / paste at pointer\nCtrl+Z / Y: undo / redo\nErase tool or right-drag: erase"
	cursor_help.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	edit_section.add_child(cursor_help)
	var palette_section := _add_section(tile_page, "Choose a tile")
	_add_tool_button(palette_section, "Paint Tiles", Tool.TILE)
	var tile_label := Label.new()
	tile_label.text = "Choose a tile"
	palette_section.add_child(tile_label)
	var tile_row := GridContainer.new()
	tile_row.columns = 5
	palette_section.add_child(tile_row)
	for index in 5:
		var button := Button.new()
		button.custom_minimum_size = Vector2(50, 50)
		button.tooltip_text = "Tile %d" % (index + 1)
		button.toggle_mode = true
		button.pressed.connect(_select_tile.bind(index))
		tile_row.add_child(button)
		tile_buttons.append(button)
	rotation_button = Button.new()
	rotation_button.pressed.connect(_rotate_tile)
	palette_section.add_child(rotation_button)
	_update_rotation_button()
	var paint_section := _add_section(tile_page, "Drawing tools")
	var paint_row := HBoxContainer.new()
	paint_row.add_theme_constant_override("separation", 5)
	paint_section.add_child(paint_row)
	_add_paint_button(paint_row, "Pencil", PaintMode.PENCIL)
	_add_paint_button(paint_row, "Line", PaintMode.LINE)
	_add_paint_button(paint_row, "Rectangle", PaintMode.RECTANGLE)
	_add_tool_button(paint_section, "Erase tiles & objects", Tool.ERASE)
	var object_page := VBoxContainer.new()
	object_page.add_theme_constant_override("separation", 7)
	layout.add_child(object_page)
	panel_pages.append(object_page)
	var player_section := _add_section(object_page, "Player & checkpoints")
	_add_tool_button(player_section, "Player Start", Tool.PLAYER_START)
	_add_tool_button(player_section, "Checkpoint", Tool.CHECKPOINT)
	_add_tool_button(player_section, "Burrowable Soil", Tool.BURROW_SOIL)
	_add_help(player_section, "Soil is a 256 x 96 ground strip. Leave its interior free of tiles and keep space above it for surfacing.")
	var enemy_section := _add_section(object_page, "Place enemies")
	_add_help(enemy_section, "Choose an enemy, then click to place it.")
	_add_tool_button(enemy_section, "Patrol Enemy", Tool.PATROL)
	_add_tool_button(enemy_section, "Chase Enemy", Tool.CHASER)
	_add_tool_button(enemy_section, "Flying Enemy", Tool.FLYING)
	_add_tool_button(enemy_section, "Flying Patrol Enemy", Tool.FLYING_PATROL)
	var patrol_section := _add_section(object_page, "Enemy patrol settings")
	_add_tool_button(patrol_section, "Select an enemy to edit", Tool.CURSOR)
	_build_patrol_controls(patrol_section)
	var level_page := VBoxContainer.new()
	level_page.add_theme_constant_override("separation", 8)
	layout.add_child(level_page)
	panel_pages.append(level_page)
	var file_section := _add_section(level_page, "Name & save")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Level name"
	name_edit.text = "new_level"
	file_section.add_child(name_edit)
	var save_row := HBoxContainer.new()
	file_section.add_child(save_row)
	var new_button := Button.new()
	new_button.text = "New level"
	new_button.pressed.connect(_confirm_new_level)
	save_row.add_child(new_button)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_level)
	save_row.add_child(save_button)
	var play_button := Button.new()
	play_button.text = "Play Level"
	play_button.pressed.connect(_play_level)
	var test_section := _add_section(level_page, "Test your level")
	_add_help(test_section, "Place a Player Start first. Press Escape to return to editing.")
	test_section.add_child(play_button)
	var load_section := _add_section(level_page, "Open a saved level")
	level_list = OptionButton.new()
	level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_section.add_child(level_list)
	var load_button := Button.new()
	load_button.text = "Load Selected"
	load_button.pressed.connect(_confirm_load_level)
	load_section.add_child(load_button)
	var help_section := _add_section(level_page, "Help & camera")
	_add_help(help_section, "Left click: use tool\nRight click: erase (or cancel a patrol point)\nArrow keys / middle mouse drag: move view\nMouse wheel: zoom\nR: rotate tile\nDelete: remove selection\nEscape: stop testing / leave editor")
	var home_button := Button.new()
	home_button.text = "Reset camera"
	home_button.pressed.connect(func():
		editor_camera.position = Vector2(640, 360)
		_set_zoom(1.0))
	help_section.add_child(home_button)
	world_panel = VaniaWorldEditor.new()
	world_panel.editor = self
	editor_ui.add_child(world_panel)
	var world_tools := VBoxContainer.new()
	world_tools.add_theme_constant_override("separation", 8)
	layout.add_child(world_tools)
	panel_pages.append(world_tools)
	world_panel.build_room_tools(world_tools)
	status_label = Label.new()
	status_label.text = "Ready"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.7))
	layout.add_child(status_label)
	_build_tile_icons()
	_select_tile(0)
	_select_paint_mode(PaintMode.PENCIL)
	_select_panel_tab(0)


func _add_tool_button(parent: Control, label: String, tool: int) -> void:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.set_meta("tool", tool)
	button.pressed.connect(_select_tool.bind(tool))
	parent.add_child(button)
	tool_buttons.append(button)


func _add_panel_tab(parent: Control, label: String, index: int) -> void:
	var button := Button.new()
	button.text = "<  " + label
	button.set_meta("label", label)
	button.custom_minimum_size = Vector2(TAB_WIDTH, 92)
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.075, 0.095, 0.12, 0.98)
	tab_style.corner_radius_top_left = 12
	tab_style.corner_radius_bottom_left = 12
	button.add_theme_stylebox_override("normal", tab_style)
	var active_style := tab_style.duplicate() as StyleBoxFlat
	active_style.bg_color = Color(0.1, 0.24, 0.29)
	active_style.border_width_left = 3
	active_style.border_color = Color(0.35, 0.9, 1.0)
	button.add_theme_stylebox_override("pressed", active_style)
	button.add_theme_stylebox_override("hover", active_style)
	button.toggle_mode = true
	button.tooltip_text = "Open %s panel" % label.to_lower()
	button.pressed.connect(_select_panel_tab.bind(index))
	parent.add_child(button)
	panel_tabs.append(button)


func _add_paint_button(parent: Control, label: String, mode: int) -> void:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_select_paint_mode.bind(mode))
	parent.add_child(button)
	paint_buttons.append(button)


func _select_panel_tab(index: int) -> void:
	if index == 4:
		world_panel.open_workspace()
		return
	var close := selected_panel_tab == index and drawer_open
	selected_panel_tab = index
	drawer_open = not close
	for tab_index in panel_tabs.size():
		var active := tab_index == index and drawer_open
		panel_tabs[tab_index].button_pressed = active
		panel_tabs[tab_index].text = (">  " if active else "<  ") + str(panel_tabs[tab_index].get_meta("label"))
	if drawer_open:
		panel_content.show()
		for page_index in panel_pages.size():
			panel_pages[page_index].visible = page_index == index
		panel_scroll.scroll_vertical = 0
	if drawer_tween: drawer_tween.kill()
	drawer_tween = create_tween()
	drawer_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drawer_tween.tween_property(panel_content, "position:x", 0.0 if drawer_open else DRAWER_WIDTH, 0.22)
	if not drawer_open:
		drawer_tween.tween_callback(panel_content.hide)


func _select_paint_mode(mode: int) -> void:
	paint_mode = mode
	for index in paint_buttons.size():
		paint_buttons[index].button_pressed = index == mode
	_select_tool(Tool.TILE)
	var names := ["Pencil", "Line", "Rectangle"]
	_set_status("%s paint tool selected" % names[mode])


func _select_tool(tool: int) -> void:
	_cancel_patrol_placement()
	if current_tool != tool: _cancel_shape_paint()
	current_tool = tool
	for button in tool_buttons:
		button.button_pressed = int(button.get_meta("tool")) == tool
	_rebuild_placement_preview()
	var hints := {
		Tool.TILE: "Click or drag to paint. Choose a drawing tool for lines or rectangles.",
		Tool.CURSOR: "Click an object to select it, then drag to move. Drag empty space to select a group.",
		Tool.ERASE: "Click to erase a tile or object.",
		Tool.PLAYER_START: "Click to choose where the player begins.",
	}
	_set_status(hints.get(tool, "Click in the level to place this object."))


func _select_tile(index: int) -> void:
	_cancel_shape_paint()
	var tiles := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]
	selected_tile = tiles[index]
	for button_index in tile_buttons.size():
		tile_buttons[button_index].button_pressed = button_index == index
	_select_tool(Tool.TILE)
	_set_status("Selected tile %d" % (index + 1))


func _apply_tool(force_erase: bool) -> void:
	var cell := tile_layer.local_to_map(tile_layer.to_local(get_global_mouse_position()))
	var erase := force_erase or current_tool == Tool.ERASE
	if erase:
		_erase_stroke_to(cell)
		return
	if current_tool == Tool.TILE:
		if cell == last_painted_cell: return
		_record_edit()
		last_painted_cell = cell
		tile_layer.set_cell(cell, 0, selected_tile, _tile_alternative_id())
		return
	if current_tool == Tool.PLAYER_START:
		_place_player_start(cell)
		return
	if current_tool == Tool.WORLD_MARKER:
		world_panel.place_marker(cell)
		return
	var scene: PackedScene
	match current_tool:
		Tool.PATROL: scene = PATROL_ENEMY
		Tool.CHASER: scene = CHASE_ENEMY
		Tool.FLYING: scene = FLYING_ENEMY
		Tool.FLYING_PATROL: scene = FLYING_PATROL_ENEMY
		Tool.CHECKPOINT: scene = CHECKPOINT
		Tool.BURROW_SOIL: scene = BURROW_SOIL
	if scene: _place_entity(scene, cell)


func _place_entity(scene: PackedScene, cell: Vector2i) -> void:
	var position := tile_layer.to_global(tile_layer.map_to_local(cell))
	for child in entities.get_children():
		if (child as Node2D).global_position.distance_to(position) < 8.0: return
	_record_edit()
	var instance := scene.instantiate() as Node2D
	if not instance: return
	instance.position = entities.to_local(position)
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	entities.add_child(instance)
	_prepare_patrol_for_editing(instance)
	instance.owner = level_root
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	_set_status("Placed %s" % instance.name)
	if _patrol_task(instance):
		_clear_selection()
		selected_entities.append(instance)
		_refresh_patrol_controls()
		_set_status("Enemy placed. Use Set point A / B to choose its patrol route.")


func _erase_entity_at(cell: Vector2i) -> void:
	var position := tile_layer.to_global(tile_layer.map_to_local(cell))
	var closest: Node2D
	var closest_distance := 24.0
	for child in entities.get_children():
		var node := child as Node2D
		var distance := node.global_position.distance_to(position)
		if distance < closest_distance:
			closest = node
			closest_distance = distance
	if closest:
		selected_entities.erase(closest)
		closest.get_parent().remove_child(closest)
		closest.queue_free()
		_refresh_patrol_controls()
	var player_start := level_root.get_node_or_null("PlayerStart") as Node2D
	if player_start and player_start.global_position.distance_to(position) < 24.0:
		level_root.remove_child(player_start)
		player_start.queue_free()


func _save_level() -> void:
	var clean_name := _sanitize_name(name_edit.text)
	if clean_name.is_empty():
		_set_status("Enter a level name")
		return
	level_root.set_meta("room_bounds", VaniaWorldData.measure_room(level_root))
	_own_level_nodes(level_root)
	_set_entities_editing(false)
	var packed := PackedScene.new()
	var result := packed.pack(level_root)
	if result != OK:
		_set_entities_editing(true)
		_set_status("Could not pack level: %s" % error_string(result))
		return
	var path := "%s/%s.tscn" % [LEVEL_DIRECTORY, clean_name]
	result = ResourceSaver.save(packed, path)
	_set_entities_editing(true)
	if result == OK:
		name_edit.text = clean_name
		_set_status("Saved %s" % path)
		_refresh_level_list(clean_name)
		if world_panel: world_panel.refresh_files()
	else:
		_set_status("Save failed: %s" % error_string(result))


func _load_selected_level() -> void:
	if level_list.item_count == 0:
		_set_status("No saved levels")
		return
	var file_name := level_list.get_item_metadata(level_list.selected) as String
	var path := "%s/%s" % [LEVEL_DIRECTORY, file_name]
	_load_level_path(path)


func _load_level_path(path: String) -> void:
	var file_name := path.get_file()
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if not packed:
		_set_status("Could not load %s" % file_name)
		return
	var loaded := packed.instantiate() as Node2D
	if not loaded:
		_set_status("Invalid level scene")
		return
	if not loaded.get_node_or_null("TileMapLayer") is TileMapLayer or not loaded.get_node_or_null("Entities") is Node2D:
		loaded.free()
		_set_status("This file is not an editable level.")
		return
	undo_steps.clear()
	redo_steps.clear()
	if is_instance_valid(level_root):
		_clear_selection()
		remove_child(level_root)
		level_root.queue_free()
	level_root = loaded
	add_child(level_root)
	tile_layer = level_root.get_node_or_null("TileMapLayer") as TileMapLayer
	entities = level_root.get_node_or_null("Entities") as Node2D
	if not tile_layer or not entities:
		_set_status("Saved scene is missing editor nodes")
		return
	_ensure_shape_preview_layer()
	_set_entities_editing(true)
	name_edit.text = file_name.get_basename()
	_set_status("Loaded %s" % file_name)
	_rebuild_placement_preview()


func _place_player_start(cell: Vector2i) -> void:
	_record_edit()
	var old_start := level_root.get_node_or_null("PlayerStart")
	if old_start:
		level_root.remove_child(old_start)
		old_start.free()
	var marker := Node2D.new()
	marker.name = "PlayerStart"
	marker.position = tile_layer.map_to_local(cell)
	marker.set_meta("level_editor_player_start", true)
	level_root.add_child(marker)
	marker.owner = level_root
	_add_player_marker_visual(marker)
	_set_status("Player start set to %s" % cell)


func _add_player_marker_visual(marker: Node2D) -> void:
	var body := Polygon2D.new()
	body.name = "EditorVisual"
	body.polygon = PackedVector2Array([
		Vector2(-11, 13), Vector2(-11, -17), Vector2(-7, -23),
		Vector2(0, -27), Vector2(7, -23), Vector2(11, -17), Vector2(11, 13)
	])
	body.color = Color(0.25, 1.0, 0.45, 0.8)
	marker.add_child(body)
	body.owner = level_root
	var label := Label.new()
	label.name = "EditorLabel"
	label.text = "START"
	label.position = Vector2(-25, -52)
	label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)
	label.owner = level_root


func _rotate_tile() -> void:
	_cancel_shape_paint()
	tile_rotation = (tile_rotation + 1) % 4
	_select_tool(Tool.TILE)
	_update_rotation_button()
	_set_status("Tile rotation: %d degrees" % (tile_rotation * 90))


func _tile_alternative_id() -> int:
	match tile_rotation:
		1: return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		2: return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
		3: return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V
	return 0


func _ensure_shape_preview_layer() -> void:
	if not is_instance_valid(shape_preview_layer):
		shape_preview_layer = TileMapLayer.new()
		shape_preview_layer.name = "ShapePreview"
		shape_preview_layer.z_index = 99
		shape_preview_layer.modulate = Color(1, 1, 1, 0.5)
		add_child(shape_preview_layer)
	shape_preview_layer.clear()
	shape_preview_layer.tile_set = TILE_SET
	if tile_layer:
		shape_preview_layer.global_transform = tile_layer.global_transform


func _mouse_cell() -> Vector2i:
	return tile_layer.local_to_map(tile_layer.to_local(get_global_mouse_position()))


func _begin_shape_paint() -> void:
	shape_dragging = true
	shape_start_cell = _mouse_cell()
	_update_shape_preview(shape_start_cell)


func _finish_shape_paint() -> void:
	if shape_dragging: _record_edit()
	if not shape_dragging: return
	var cells := _shape_cells(shape_start_cell, _mouse_cell())
	for cell in cells:
		tile_layer.set_cell(cell, 0, selected_tile, _tile_alternative_id())
	shape_dragging = false
	shape_preview_layer.clear()
	_set_status("Painted %d tiles" % cells.size())


func _cancel_shape_paint() -> void:
	shape_dragging = false
	if is_instance_valid(shape_preview_layer): shape_preview_layer.clear()


func _update_shape_preview(end_cell: Vector2i) -> void:
	if not is_instance_valid(shape_preview_layer): return
	shape_preview_layer.clear()
	for cell in _shape_cells(shape_start_cell, end_cell):
		shape_preview_layer.set_cell(cell, 0, selected_tile, _tile_alternative_id())


func _shape_cells(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if paint_mode == PaintMode.RECTANGLE:
		var left := mini(start.x, finish.x)
		var right := maxi(start.x, finish.x)
		var top := mini(start.y, finish.y)
		var bottom := maxi(start.y, finish.y)
		for y in range(top, bottom + 1):
			for x in range(left, right + 1):
				cells.append(Vector2i(x, y))
		return cells
	var point := start
	var delta := (finish - start).abs()
	var step := Vector2i(1 if start.x < finish.x else -1, 1 if start.y < finish.y else -1)
	var error := delta.x - delta.y
	while true:
		cells.append(point)
		if point == finish: break
		var doubled_error := error * 2
		if doubled_error > -delta.y:
			error -= delta.y
			point.x += step.x
		if doubled_error < delta.x:
			error += delta.x
			point.y += step.y
	return cells


func _begin_cursor_drag() -> void:
	_cancel_shape_paint()
	cursor_drag_start = _mouse_cell()
	cursor_drag_current = cursor_drag_start
	if Input.is_key_pressed(KEY_SHIFT):
		cursor_marquee_dragging = true
		cursor_move_dragging = false
		queue_redraw()
		return
	var hit_cells := tile_layer.get_cell_source_id(cursor_drag_start) >= 0
	var hit_entities := _entities_at_cell(cursor_drag_start)
	var hit_selected := cursor_drag_start in selected_cells
	for node in hit_entities:
		if node in selected_entities: hit_selected = true
	if hit_cells or not hit_entities.is_empty():
		if not hit_selected:
			if not Input.is_key_pressed(KEY_SHIFT): _clear_selection()
			if hit_cells and cursor_drag_start not in selected_cells:
				selected_cells.append(cursor_drag_start)
			for node in hit_entities:
				if node not in selected_entities: selected_entities.append(node)
		cursor_move_dragging = true
		cursor_marquee_dragging = false
	else:
		if not Input.is_key_pressed(KEY_SHIFT): _clear_selection()
		cursor_marquee_dragging = true
		cursor_move_dragging = false
	queue_redraw()


func _finish_cursor_drag() -> void:
	var clicked := cursor_drag_start == cursor_drag_current
	if cursor_move_dragging:
		_move_selection(cursor_drag_current - cursor_drag_start)
	elif cursor_marquee_dragging:
		_select_marquee(cursor_drag_start, cursor_drag_current)
	cursor_move_dragging = false
	cursor_marquee_dragging = false
	_refresh_patrol_controls()
	queue_redraw()
	if clicked and selected_entities.size() == 1 and selected_entities[0] is VaniaMarker and selected_entities[0].kind == 0:
		world_panel.edit_transition(selected_entities[0])


func _select_marquee(start: Vector2i, finish: Vector2i) -> void:
	var left := mini(start.x, finish.x)
	var right := maxi(start.x, finish.x)
	var top := mini(start.y, finish.y)
	var bottom := maxi(start.y, finish.y)
	for cell in tile_layer.get_used_cells():
		if cell.x >= left and cell.x <= right and cell.y >= top and cell.y <= bottom and cell not in selected_cells:
			selected_cells.append(cell)
	for node in _editable_entities():
		var cell := tile_layer.local_to_map(tile_layer.to_local(node.global_position))
		if cell.x >= left and cell.x <= right and cell.y >= top and cell.y <= bottom and node not in selected_entities:
			selected_entities.append(node)
	_set_status("Selected %d tiles and %d objects" % [selected_cells.size(), selected_entities.size()])


func _move_selection(delta: Vector2i) -> void:
	if delta == Vector2i.ZERO: return
	_record_edit()
	var tile_snapshots: Array[Dictionary] = []
	for cell in selected_cells:
		var source_id := tile_layer.get_cell_source_id(cell)
		if source_id < 0: continue
		tile_snapshots.append({
			"cell": cell,
			"source": source_id,
			"atlas": tile_layer.get_cell_atlas_coords(cell),
			"alternative": tile_layer.get_cell_alternative_tile(cell),
		})
	for snapshot in tile_snapshots:
		tile_layer.erase_cell(snapshot.cell)
	for snapshot in tile_snapshots:
		var destination: Vector2i = snapshot.cell + delta
		tile_layer.set_cell(destination, snapshot.source, snapshot.atlas, snapshot.alternative)
	var world_delta := tile_layer.to_global(tile_layer.map_to_local(delta)) - tile_layer.to_global(tile_layer.map_to_local(Vector2i.ZERO))
	for node in selected_entities:
		if is_instance_valid(node): node.global_position += world_delta
	for index in selected_cells.size():
		selected_cells[index] += delta
	_set_status("Moved selection by %s" % delta)


func _entities_at_cell(cell: Vector2i) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var position := tile_layer.to_global(tile_layer.map_to_local(cell))
	for node in _editable_entities():
		var bounds := Rect2(Vector2(-18, -60), Vector2(36, 76))
		if node is VaniaMarker and node.kind == 0:
			bounds = node.zone_rect()
		if "flying" in node.scene_file_path:
			bounds = Rect2(Vector2(-24, -24), Vector2(48, 48))
		if bounds.has_point(node.to_local(position)):
			found.append(node)
	return found


func _editable_entities() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if entities:
		for child in entities.get_children():
			if child is Node2D: result.append(child as Node2D)
	var player_start := level_root.get_node_or_null("PlayerStart") as Node2D
	if player_start: result.append(player_start)
	return result


func _clear_selection() -> void:
	cursor_move_dragging = false
	cursor_marquee_dragging = false
	selected_cells.clear()
	selected_entities.clear()
	_refresh_patrol_controls()


func _delete_selection() -> void:
	if selected_cells.is_empty() and selected_entities.is_empty(): return
	_record_edit()
	var tile_count := selected_cells.size()
	var entity_count := selected_entities.size()
	for cell in selected_cells:
		tile_layer.erase_cell(cell)
	for node in selected_entities:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_clear_selection()
	_set_status("Deleted %d tiles and %d objects" % [tile_count, entity_count])
	queue_redraw()


func _cell_draw_center(cell: Vector2i) -> Vector2:
	return to_local(tile_layer.to_global(tile_layer.map_to_local(cell)))


func _draw_cursor_selection() -> void:
	if current_tool != Tool.CURSOR: return
	var move_delta := cursor_drag_current - cursor_drag_start if cursor_move_dragging else Vector2i.ZERO
	for cell in selected_cells:
		var center := _cell_draw_center(cell + move_delta)
		draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), Color(0.15, 0.9, 1.0, 0.18), true)
		draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), Color(0.25, 0.95, 1.0), false, 2.0)
	var world_move := tile_layer.to_global(tile_layer.map_to_local(move_delta)) - tile_layer.to_global(tile_layer.map_to_local(Vector2i.ZERO))
	for node in selected_entities:
		if not is_instance_valid(node): continue
		var center := to_local(node.global_position + world_move)
		draw_rect(Rect2(center - Vector2(18, 26), Vector2(36, 52)), Color(1.0, 0.75, 0.2, 0.16), true)
		draw_rect(Rect2(center - Vector2(18, 26), Vector2(36, 52)), Color(1.0, 0.78, 0.25), false, 2.0)
	if cursor_marquee_dragging:
		var start_center := _cell_draw_center(cursor_drag_start)
		var end_center := _cell_draw_center(cursor_drag_current)
		var rect := Rect2(start_center, end_center - start_center).abs().grow(CELL_SIZE * 0.5)
		draw_rect(rect, Color(0.2, 0.75, 1.0, 0.12), true)
		draw_rect(rect, Color(0.3, 0.85, 1.0), false, 2.0)


func _update_rotation_button() -> void:
	if rotation_button:
		rotation_button.text = "Rotate Tile (R) - %d degrees" % (tile_rotation * 90)


func _build_tile_icons() -> void:
	var tiles := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]
	for index in mini(tile_buttons.size(), tiles.size()):
		var atlas := AtlasTexture.new()
		atlas.atlas = TILE_TEXTURE
		atlas.region = Rect2(Vector2(tiles[index] * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
		tile_buttons[index].icon = atlas
		tile_buttons[index].expand_icon = true


func _rebuild_placement_preview() -> void:
	if is_instance_valid(placement_preview):
		placement_preview.queue_free()
	placement_preview = Node2D.new()
	placement_preview.name = "PlacementPreview"
	placement_preview.z_index = 100
	placement_preview.modulate = Color(1, 1, 1, 0.55)
	add_child(placement_preview)
	if current_tool == Tool.ERASE:
		var erase_box := Polygon2D.new()
		erase_box.polygon = PackedVector2Array([Vector2(-14, -14), Vector2(14, -14), Vector2(14, 14), Vector2(-14, 14)])
		erase_box.color = Color(1.0, 0.15, 0.15, 0.45)
		placement_preview.add_child(erase_box)
		return
	if current_tool == Tool.TILE:
		var sprite := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = TILE_TEXTURE
		atlas.region = Rect2(Vector2(selected_tile * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
		sprite.texture = atlas
		sprite.rotation = deg_to_rad(tile_rotation * 90.0)
		placement_preview.add_child(sprite)
		return
	if current_tool == Tool.WORLD_MARKER and world_panel:
		var marker := VaniaMarker.new()
		marker.kind = world_panel.marker_kind
		marker.side = world_panel.exit_side.selected
		marker.transition_size = Vector2(world_panel.zone_width.value, world_panel.zone_height.value)
		marker.ability = VaniaWorldData.ABILITIES[world_panel.pickup_ability.selected]
		placement_preview.add_child(marker)
		return
	var scene := _scene_for_tool(current_tool)
	if scene:
		var ghost := scene.instantiate() as Node2D
		if ghost:
			_strip_preview_behavior(ghost)
			placement_preview.add_child(ghost)


func _scene_for_tool(tool: int) -> PackedScene:
	match tool:
		Tool.PLAYER_START: return PLAYER
		Tool.PATROL: return PATROL_ENEMY
		Tool.CHASER: return CHASE_ENEMY
		Tool.FLYING: return FLYING_ENEMY
		Tool.FLYING_PATROL: return FLYING_PATROL_ENEMY
		Tool.CHECKPOINT: return CHECKPOINT
		Tool.BURROW_SOIL: return BURROW_SOIL
	return null


func _strip_preview_behavior(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.get_script(): node.set_script(null)
	if node is Control: (node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node is CollisionObject2D: (node as CollisionObject2D).input_pickable = false
	if node is CollisionShape2D: (node as CollisionShape2D).disabled = true
	if node is CollisionPolygon2D: (node as CollisionPolygon2D).disabled = true
	for child in node.get_children():
		_strip_preview_behavior(child)


func _update_placement_preview() -> void:
	if not is_instance_valid(placement_preview) or not tile_layer: return
	preview_cell = tile_layer.local_to_map(tile_layer.to_local(get_global_mouse_position()))
	placement_preview.global_position = tile_layer.to_global(tile_layer.map_to_local(preview_cell))
	placement_preview.visible = not _mouse_over_interface() and not shape_dragging and patrol_point_key.is_empty()


func _play_level() -> void:
	var player_start := level_root.get_node_or_null("PlayerStart") as Node2D
	if not player_start:
		_set_status("Place a Player Start before playing")
		_select_tool(Tool.PLAYER_START)
		return
	if is_playing: return
	_cancel_shape_paint()
	_cancel_patrol_placement()
	level_root.set_meta("room_bounds", VaniaWorldData.measure_room(level_root))
	_own_level_nodes(level_root)
	_set_entities_editing(false)
	var packed := PackedScene.new()
	var pack_error := packed.pack(level_root)
	_set_entities_editing(true)
	if pack_error != OK:
		_set_status("Could not start test: %s" % error_string(pack_error))
		return
	play_world = packed.instantiate() as Node2D
	if not play_world: return
	level_root.process_mode = Node.PROCESS_MODE_DISABLED
	remove_child(level_root)
	add_child(play_world)
	is_playing = true
	queue_redraw()
	patrol_overlay.queue_redraw()
	editor_ui.visible = false
	if placement_preview: placement_preview.visible = false
	var test_start := play_world.get_node("PlayerStart") as Node2D
	test_start.visible = false
	play_player = PLAYER.instantiate() as Node2D
	if not play_player:
		_stop_playing()
		_set_status("Could not create player")
		return
	play_world.add_child(play_player)
	play_player.global_position = test_start.global_position
	var camera := Camera2D.new()
	camera.name = "PlayCamera"
	camera.position = Vector2(0, -64)
	camera.position_smoothing_enabled = true
	play_player.add_child(camera)
	var bounds := VaniaWorldData.measure_room(level_root)
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.make_current()
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = true


func _stop_playing() -> void:
	if not is_playing: return
	is_playing = false
	queue_redraw()
	if is_instance_valid(play_world):
		remove_child(play_world)
		play_world.queue_free()
	play_world = null
	play_player = null
	add_child(level_root)
	level_root.process_mode = Node.PROCESS_MODE_INHERIT
	_set_entities_editing(true)
	var player_start := level_root.get_node_or_null("PlayerStart") as Node2D
	if player_start: player_start.visible = true
	editor_ui.visible = true
	editor_camera.make_current()
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = false
	patrol_overlay.queue_redraw()
	_set_status("Test stopped")


func _own_level_nodes(node: Node) -> void:
	for child in node.get_children():
		child.owner = level_root
		if child.scene_file_path.is_empty(): _own_level_nodes(child)


func _set_entities_editing(editing: bool) -> void:
	if not entities: return
	for child in entities.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED if editing else Node.PROCESS_MODE_INHERIT
		if editing: _prepare_patrol_for_editing(child)


func _refresh_level_list(select_name: String = "") -> void:
	if not level_list: return
	level_list.clear()
	var directory := DirAccess.open(LEVEL_DIRECTORY)
	if not directory: return
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "tscn": continue
		level_list.add_item(file_name.get_basename())
		level_list.set_item_metadata(level_list.item_count - 1, file_name)
		if file_name.get_basename() == select_name: level_list.select(level_list.item_count - 1)


func _sanitize_name(value: String) -> String:
	var clean := value.strip_edges().to_lower().replace(" ", "_")
	var result := ""
	for character in clean:
		if character.to_ascii_buffer()[0] in range(48, 58) or character.to_ascii_buffer()[0] in range(97, 123) or character == "_" or character == "-":
			result += character
	return result


func _set_zoom(value: float) -> void:
	value = clampf(value, 0.35, 3.0)
	editor_camera.zoom = Vector2(value, value)


func _mouse_over_interface() -> bool:
	var hovered: Node = get_viewport().gui_get_hovered_control()
	while hovered:
		if hovered == editor_ui: return true
		hovered = hovered.get_parent()
	return false


func _set_status(message: String) -> void:
	if status_label: status_label.text = message

func _resize_panel() -> void:
	var viewport_size := get_viewport_rect().size
	var height := maxf(240, viewport_size.y - 28)
	drawer_clip.position = Vector2(viewport_size.x - TAB_WIDTH - DRAWER_WIDTH, 14)
	drawer_clip.size = Vector2(DRAWER_WIDTH, height)
	tab_rail.position = Vector2(viewport_size.x - TAB_WIDTH, 78)
	panel_scroll.custom_minimum_size.y = height
	panel_content.size = Vector2(DRAWER_WIDTH, height)
	if drawer_tween: drawer_tween.kill()
	panel_content.position.x = 0.0 if drawer_open else DRAWER_WIDTH
	panel_content.visible = drawer_open


func _add_section(parent: Control, heading: String) -> VBoxContainer:
	parent.add_child(HSeparator.new())
	var header := Label.new()
	header.text = heading
	header.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	parent.add_child(header)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	parent.add_child(body)
	return body


func _add_help(parent: Control, message: String) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	parent.add_child(label)


func _confirm_new_level() -> void:
	_confirm_replace("Start a new level? Save first if you want to keep your changes.", _new_level)


func _confirm_load_level() -> void:
	if level_list.item_count == 0:
		_set_status("No saved levels yet. Name your level and click Save.")
		return
	_confirm_replace("Open the selected level? Unsaved changes will be replaced.", _load_selected_level)


func _confirm_replace(message: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = "Replace current level?"
	dialog.confirmed.connect(action)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	editor_ui.add_child(dialog)
	dialog.popup_centered()


func _patrol_task(enemy: Node) -> AIPatrolBetweenPointsTask:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): return null
	return enemy.get_node_or_null("AI/AIRoot/PatrolBetweenPoints") as AIPatrolBetweenPointsTask


func _prepare_patrol_for_editing(enemy: Node) -> void:
	var task := _patrol_task(enemy)
	if not task: return
	# Runtime pins the points in world space. Editing keeps them attached so
	# moving an enemy also moves its authored route.
	for point in [task.point_a, task.point_b]:
		if not is_instance_valid(point): continue
		var world_position: Vector2 = point.global_position
		point.top_level = false
		point.global_position = world_position
	_store_patrol(enemy)


func _store_patrol(enemy: Node) -> void:
	var task := _patrol_task(enemy)
	if not task or not task.point_a or not task.point_b: return
	enemy.set_meta("editor_patrol", {
		"point_a": task.point_a.position,
		"point_b": task.point_b.position,
		"pause": task.pause_at_point,
		"speed": task.speed_multiplier,
		"start_b": task.start_at_point_b,
	})


func _build_patrol_controls(parent: Control) -> void:
	patrol_title = Label.new()
	patrol_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(patrol_title)
	patrol_controls = VBoxContainer.new()
	patrol_controls.add_theme_constant_override("separation", 7)
	parent.add_child(patrol_controls)
	_add_help(patrol_controls, "Set A and B in the level. Ground enemies walk left/right; flying patrols also move up/down.")
	for key in ["point_a", "point_b"]:
		var button := Button.new()
		button.text = "Set point " + ("A" if key == "point_a" else "B")
		button.toggle_mode = true
		button.pressed.connect(_begin_patrol_placement.bind(key))
		patrol_controls.add_child(button)
		patrol_point_buttons.append(button)
	_add_help(patrol_controls, "Pause at each end (seconds)")
	patrol_pause = SpinBox.new()
	patrol_pause.min_value = 0
	patrol_pause.max_value = 10
	patrol_pause.step = 0.05
	patrol_controls.add_child(patrol_pause)
	patrol_pause.value_changed.connect(_update_patrol_settings)
	_add_help(patrol_controls, "Speed (1 = normal)")
	patrol_speed = SpinBox.new()
	patrol_speed.min_value = 0.1
	patrol_speed.max_value = 4
	patrol_speed.step = 0.1
	patrol_controls.add_child(patrol_speed)
	patrol_speed.value_changed.connect(_update_patrol_settings)
	patrol_start = CheckButton.new()
	patrol_start.text = "Head toward B first"
	patrol_start.toggled.connect(_update_patrol_settings)
	patrol_controls.add_child(patrol_start)
	_refresh_patrol_controls()


func _refresh_patrol_controls() -> void:
	_cancel_patrol_placement()
	patrol_target = null
	if patrol_overlay: patrol_overlay.queue_redraw()
	if not patrol_title: return
	if selected_entities.size() == 1 and _patrol_task(selected_entities[0]):
		patrol_target = selected_entities[0]
	var task := _patrol_task(patrol_target)
	patrol_controls.visible = task != null
	if not task:
		patrol_title.text = "Select one patrol enemy to edit its route. Chase enemies do not use patrol points."
		return
	patrol_title.text = "Editing: " + str(patrol_target.name)
	patrol_pause.set_value_no_signal(task.pause_at_point)
	patrol_speed.set_value_no_signal(task.speed_multiplier)
	patrol_start.set_pressed_no_signal(task.start_at_point_b)
	_reveal_patrol_controls.call_deferred()


func _update_patrol_settings(_value: Variant) -> void:
	var task := _patrol_task(patrol_target)
	if not task: return
	_record_edit()
	task.pause_at_point = patrol_pause.value
	task.speed_multiplier = patrol_speed.value
	task.start_at_point_b = patrol_start.button_pressed
	_store_patrol(patrol_target)
	_set_status("Patrol settings updated. Save to keep your changes.")


func _begin_patrol_placement(key: String) -> void:
	if not _patrol_task(patrol_target): return
	_cancel_shape_paint()
	cursor_move_dragging = false
	cursor_marquee_dragging = false
	patrol_point_key = key
	for index in patrol_point_buttons.size():
		patrol_point_buttons[index].button_pressed = key == ("point_a" if index == 0 else "point_b")
	_set_status("Click in the level to set %s. Right click or Escape cancels." % key.replace("_", " "))


func _cancel_patrol_placement() -> void:
	patrol_point_key = ""
	for button in patrol_point_buttons:
		button.set_pressed_no_signal(false)


func _place_patrol_point(cell: Vector2i) -> void:
	var task := _patrol_task(patrol_target)
	if not task:
		_cancel_patrol_placement()
		return
	_record_edit()
	var point: Node2D = task.point_a if patrol_point_key == "point_a" else task.point_b
	var destination := tile_layer.to_global(tile_layer.map_to_local(cell))
	if not task.use_vertical_movement:
		destination.y = patrol_target.global_position.y
	point.global_position = destination
	_store_patrol(patrol_target)
	_cancel_patrol_placement()
	_set_status("Patrol point set. The enemy travels between A and B.")


func _draw_patrol_route() -> void:
	if is_playing: return
	var task := _patrol_task(patrol_target)
	if not task or not task.point_a or not task.point_b: return
	var a := to_local(task.point_a.global_position)
	var b := to_local(task.point_b.global_position)
	var color := Color(1.0, 0.8, 0.25)
	patrol_overlay.draw_line(a, b, color, 2.0)
	for index in 2:
		var point: Vector2 = a if index == 0 else b
		patrol_overlay.draw_circle(point, 9.0, color)
		patrol_overlay.draw_string(ThemeDB.fallback_font, point + Vector2(-5, -15), "A" if index == 0 else "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
	if not patrol_point_key.is_empty() and not _mouse_over_interface():
		var target := _cell_draw_center(_mouse_cell())
		if not task.use_vertical_movement: target.y = to_local(patrol_target.global_position).y
		patrol_overlay.draw_circle(target, 12.0, Color(0.3, 1.0, 0.7), false, 2.0)



func _reveal_patrol_controls() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_playing and selected_panel_tab == 1 and panel_content.visible and patrol_controls.is_visible_in_tree():
		panel_scroll.ensure_control_visible(patrol_controls)



func _play_adventure(data: VaniaWorldData, temporary: bool, resume: bool) -> void:
	if is_playing: return
	_cancel_shape_paint()
	_cancel_patrol_placement()
	level_root.process_mode = Node.PROCESS_MODE_DISABLED
	remove_child(level_root)
	var runner := VaniaWorldRunner.new()
	runner.world = data.duplicate(true) as VaniaWorldData
	runner.preview = temporary
	runner.resume_save = resume
	play_world = runner
	is_playing = true
	queue_redraw()
	editor_ui.hide()
	placement_preview.hide()
	patrol_overlay.queue_redraw()
	add_child(runner)
	play_player = runner.player
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = true
