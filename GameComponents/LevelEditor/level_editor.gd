extends Node2D
class_name SimpleLevelEditor

enum Tool { TILE, PLAYER_START, PATROL, CHASER, FLYING, CHECKPOINT, ERASE, CURSOR }
enum PaintMode { PENCIL, LINE, RECTANGLE }

const TILE_SET := preload("res://GameComponents/LevelEditor/level_tileset.tres")
const PATROL_ENEMY := preload("res://GameComponents/Enemies/patrol_enemy.tscn")
const CHASE_ENEMY := preload("res://GameComponents/Enemies/chase_enemy.tscn")
const FLYING_ENEMY := preload("res://GameComponents/Enemies/flying_enemy.tscn")
const CHECKPOINT := preload("res://GameComponents/Interaction/checkpoint_2d.tscn")
const PLAYER := preload("res://GameComponents/Player/player.tscn")
const TILE_TEXTURE := preload("res://Assets/Sprites/Tilesets/TestTileset.png")
const LEVEL_DIRECTORY := "user://levels"
const CELL_SIZE := 32

var current_tool := Tool.TILE
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


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LEVEL_DIRECTORY))
	_build_world()
	_build_interface()
	_refresh_level_list()
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = false


func _exit_tree() -> void:
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_playing:
			_stop_playing()
			get_viewport().set_input_as_handled()
			return
		get_tree().change_scene_to_file("res://GameComponents/Scenes/test_world.tscn")
		return
	if is_playing: return
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
		if dragging_camera:
			editor_camera.position -= motion.relative / editor_camera.zoom
			last_mouse_position = motion.position
		elif current_tool == Tool.CURSOR and (cursor_marquee_dragging or cursor_move_dragging):
			cursor_drag_current = _mouse_cell()
			queue_redraw()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and current_tool == Tool.TILE and not _mouse_over_interface():
			if paint_mode == PaintMode.PENCIL:
				_apply_tool(false)
			elif shape_dragging:
				_update_shape_preview(_mouse_cell())


func _process(delta: float) -> void:
	if is_playing: return
	var pan := Input.get_vector(&"Left", &"Right", &"Up", &"Down")
	if pan != Vector2.ZERO and not name_edit.has_focus():
		editor_camera.position += pan * 620.0 * delta / editor_camera.zoom.x
	_update_placement_preview()
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


func _build_world() -> void:
	editor_camera = Camera2D.new()
	editor_camera.name = "EditorCamera"
	editor_camera.position = Vector2(640, 360)
	add_child(editor_camera)
	_new_level()


func _new_level() -> void:
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
	var shell := HBoxContainer.new()
	shell.position = Vector2(14, 14)
	shell.add_theme_constant_override("separation", 4)
	editor_ui.add_child(shell)
	var tab_rail := VBoxContainer.new()
	tab_rail.add_theme_constant_override("separation", 4)
	shell.add_child(tab_rail)
	_add_panel_tab(tab_rail, "TILES", 0)
	_add_panel_tab(tab_rail, "OBJECTS", 1)
	_add_panel_tab(tab_rail, "LEVEL", 2)
	panel_content = PanelContainer.new()
	panel_content.custom_minimum_size = Vector2(310, 0)
	shell.add_child(panel_content)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel_content.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "LEVEL EDITOR"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	layout.add_child(title)
	var instructions := Label.new()
	instructions.text = "LMB: paint    RMB: erase    R: rotate\nMMB/WASD: pan    Wheel: zoom    Esc: exit"
	instructions.add_theme_color_override("font_color", Color(0.7, 0.76, 0.82))
	layout.add_child(instructions)
	layout.add_child(HSeparator.new())
	var tile_page := VBoxContainer.new()
	tile_page.add_theme_constant_override("separation", 8)
	layout.add_child(tile_page)
	panel_pages.append(tile_page)
	_add_section_label(tile_page, "EDIT")
	_add_tool_button(tile_page, "Cursor / Select", Tool.CURSOR)
	var cursor_help := Label.new()
	cursor_help.text = "Drag empty space to box select\nShift+drag: add    Delete: remove"
	cursor_help.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	tile_page.add_child(cursor_help)
	_add_section_label(tile_page, "TILE PALETTE")
	_add_tool_button(tile_page, "Paint Tiles", Tool.TILE)
	var tile_label := Label.new()
	tile_label.text = "Choose a tile"
	tile_page.add_child(tile_label)
	var tile_row := GridContainer.new()
	tile_row.columns = 5
	tile_page.add_child(tile_row)
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
	tile_page.add_child(rotation_button)
	_update_rotation_button()
	_add_section_label(tile_page, "PAINT SHAPE")
	var paint_row := HBoxContainer.new()
	paint_row.add_theme_constant_override("separation", 5)
	tile_page.add_child(paint_row)
	_add_paint_button(paint_row, "Pencil", PaintMode.PENCIL)
	_add_paint_button(paint_row, "Line", PaintMode.LINE)
	_add_paint_button(paint_row, "Rectangle", PaintMode.RECTANGLE)
	_add_tool_button(tile_page, "Eraser", Tool.ERASE)
	var object_page := VBoxContainer.new()
	object_page.add_theme_constant_override("separation", 7)
	layout.add_child(object_page)
	panel_pages.append(object_page)
	_add_section_label(object_page, "PLAYER")
	_add_tool_button(object_page, "Player Start", Tool.PLAYER_START)
	_add_section_label(object_page, "ENEMIES")
	_add_tool_button(object_page, "Patrol Enemy", Tool.PATROL)
	_add_tool_button(object_page, "Chase Enemy", Tool.CHASER)
	_add_tool_button(object_page, "Flying Enemy", Tool.FLYING)
	_add_section_label(object_page, "WORLD")
	_add_tool_button(object_page, "Checkpoint", Tool.CHECKPOINT)
	var level_page := VBoxContainer.new()
	level_page.add_theme_constant_override("separation", 8)
	layout.add_child(level_page)
	panel_pages.append(level_page)
	_add_section_label(level_page, "LEVEL FILE")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Level name"
	name_edit.text = "new_level"
	level_page.add_child(name_edit)
	var save_row := HBoxContainer.new()
	level_page.add_child(save_row)
	var new_button := Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_new_level)
	save_row.add_child(new_button)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_level)
	save_row.add_child(save_button)
	var play_button := Button.new()
	play_button.text = "Play Level"
	play_button.pressed.connect(_play_level)
	save_row.add_child(play_button)
	level_list = OptionButton.new()
	level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_page.add_child(level_list)
	var load_button := Button.new()
	load_button.text = "Load Selected"
	load_button.pressed.connect(_load_selected_level)
	level_page.add_child(load_button)
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
	button.text = label
	button.custom_minimum_size = Vector2(88, 46)
	button.toggle_mode = true
	button.tooltip_text = "Open %s panel" % label.to_lower()
	button.pressed.connect(_select_panel_tab.bind(index))
	parent.add_child(button)
	panel_tabs.append(button)


func _add_section_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.35, 0.78, 0.9))
	parent.add_child(label)


func _add_paint_button(parent: Control, label: String, mode: int) -> void:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_select_paint_mode.bind(mode))
	parent.add_child(button)
	paint_buttons.append(button)


func _select_panel_tab(index: int) -> void:
	if selected_panel_tab == index and panel_content.visible:
		panel_content.visible = false
		panel_tabs[index].button_pressed = false
		return
	selected_panel_tab = index
	panel_content.visible = true
	for tab_index in panel_tabs.size():
		panel_tabs[tab_index].button_pressed = tab_index == index
	for page_index in panel_pages.size():
		panel_pages[page_index].visible = page_index == index


func _select_paint_mode(mode: int) -> void:
	paint_mode = mode
	for index in paint_buttons.size():
		paint_buttons[index].button_pressed = index == mode
	_select_tool(Tool.TILE)
	var names := ["Pencil", "Line", "Rectangle"]
	_set_status("%s paint tool selected" % names[mode])


func _select_tool(tool: int) -> void:
	if current_tool != tool: _cancel_shape_paint()
	current_tool = tool
	for button in tool_buttons:
		button.button_pressed = int(button.get_meta("tool")) == tool
	_rebuild_placement_preview()


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
		tile_layer.erase_cell(cell)
		_erase_entity_at(cell)
		return
	if current_tool == Tool.TILE:
		if cell == last_painted_cell: return
		last_painted_cell = cell
		tile_layer.set_cell(cell, 0, selected_tile, _tile_alternative_id())
		return
	if current_tool == Tool.PLAYER_START:
		_place_player_start(cell)
		return
	var scene: PackedScene
	match current_tool:
		Tool.PATROL: scene = PATROL_ENEMY
		Tool.CHASER: scene = CHASE_ENEMY
		Tool.FLYING: scene = FLYING_ENEMY
		Tool.CHECKPOINT: scene = CHECKPOINT
	if scene: _place_entity(scene, cell)


func _place_entity(scene: PackedScene, cell: Vector2i) -> void:
	var position := tile_layer.to_global(tile_layer.map_to_local(cell))
	for child in entities.get_children():
		if (child as Node2D).global_position.distance_to(position) < 8.0: return
	var instance := scene.instantiate() as Node2D
	if not instance: return
	entities.add_child(instance)
	instance.global_position = position
	instance.owner = level_root
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	_set_status("Placed %s" % instance.name)


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
	if closest: closest.queue_free()
	var player_start := level_root.get_node_or_null("PlayerStart") as Node2D
	if player_start and player_start.global_position.distance_to(position) < 24.0:
		player_start.queue_free()


func _save_level() -> void:
	var clean_name := _sanitize_name(name_edit.text)
	if clean_name.is_empty():
		_set_status("Enter a level name")
		return
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
	else:
		_set_status("Save failed: %s" % error_string(result))


func _load_selected_level() -> void:
	if level_list.item_count == 0:
		_set_status("No saved levels")
		return
	var file_name := level_list.get_item_metadata(level_list.selected) as String
	var path := "%s/%s" % [LEVEL_DIRECTORY, file_name]
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if not packed:
		_set_status("Could not load %s" % file_name)
		return
	var loaded := packed.instantiate() as Node2D
	if not loaded:
		_set_status("Invalid level scene")
		return
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
	if cursor_move_dragging:
		_move_selection(cursor_drag_current - cursor_drag_start)
	elif cursor_marquee_dragging:
		_select_marquee(cursor_drag_start, cursor_drag_current)
	cursor_move_dragging = false
	cursor_marquee_dragging = false
	queue_redraw()


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
	for node in _editable_entities():
		if tile_layer.local_to_map(tile_layer.to_local(node.global_position)) == cell:
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
	selected_cells.clear()
	selected_entities.clear()


func _delete_selection() -> void:
	var tile_count := selected_cells.size()
	var entity_count := selected_entities.size()
	for cell in selected_cells:
		tile_layer.erase_cell(cell)
	for node in selected_entities:
		if is_instance_valid(node): node.queue_free()
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
		Tool.CHECKPOINT: return CHECKPOINT
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
	placement_preview.visible = not _mouse_over_interface() and not shape_dragging


func _play_level() -> void:
	var player_start := level_root.get_node_or_null("PlayerStart") as Node2D
	if not player_start:
		_set_status("Place a Player Start before playing")
		_select_tool(Tool.PLAYER_START)
		return
	if is_playing: return
	is_playing = true
	editor_ui.visible = false
	if placement_preview: placement_preview.visible = false
	player_start.visible = false
	_set_entities_editing(false)
	play_player = PLAYER.instantiate() as Node2D
	if not play_player:
		_stop_playing()
		_set_status("Could not create player")
		return
	level_root.add_child(play_player)
	play_player.global_position = player_start.global_position
	var camera := Camera2D.new()
	camera.name = "PlayCamera"
	camera.position = Vector2(0, -64)
	camera.position_smoothing_enabled = true
	play_player.add_child(camera)
	camera.make_current()
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = true


func _stop_playing() -> void:
	if not is_playing: return
	is_playing = false
	if is_instance_valid(play_player):
		play_player.queue_free()
	play_player = null
	_set_entities_editing(true)
	var player_start := level_root.get_node_or_null("PlayerStart") as Node2D
	if player_start: player_start.visible = true
	editor_ui.visible = true
	editor_camera.make_current()
	var gui := get_node_or_null("/root/GlobalGUI")
	if gui: gui.visible = false
	_set_status("Test stopped")


func _own_level_nodes(node: Node) -> void:
	for child in node.get_children():
		child.owner = level_root
		if child.scene_file_path.is_empty(): _own_level_nodes(child)


func _set_entities_editing(editing: bool) -> void:
	if not entities: return
	for child in entities.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED if editing else Node.PROCESS_MODE_INHERIT


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
