extends Control
class_name VaniaWorldEditor

var editor: Node
var world := VaniaWorldData.new()
var world_name: LineEdit
var world_files: OptionButton
var saved_rooms: OptionButton
var room_picker: OptionButton
var from_room: OptionButton
var to_room: OptionButton
var from_exit: OptionButton
var to_exit: OptionButton
var gate_ability: OptionButton
var exit_side: OptionButton
var pickup_ability: OptionButton
var marker_kind := 0
var connections_list: ItemList
var map_view: VaniaWorldMap
var details: Label
var report: Label
var starting_list: ItemList
var clock := 0.0
var room_list: ItemList
var exits_list: ItemList
var selection_title: Label
var connection_hint: Label
var connect_button: Button
var workspace_status: Label
var inspector_tabs: TabContainer
var zone_width: SpinBox
var zone_height: SpinBox
var pending: Array[Dictionary] = []

const DIRECTORY := "user://worlds"


func _ready() -> void:
	world.world_id = str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.045, 0.065, 0.09)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	_button(header, "< Room editor", close_workspace)
	var title := Label.new()
	title.text = "WORLD BUILDER"
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	header.add_child(title)
	world_name = LineEdit.new()
	world_name.text = "my_world"
	world_name.placeholder_text = "Name your world"
	world_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(world_name)
	_button(header, "Save world", _save_world)
	_button(header, "Test world", func(): _play(true, false))
	var guide := Label.new()
	guide.text = "Add rooms  >  click two transition handles to connect them  >  test your world"
	guide.add_theme_color_override("font_color", Color(0.7, 0.8, 0.88))
	layout.add_child(guide)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	layout.add_child(columns)
	var library := _column(columns, 220)
	_heading(library, "YOUR ROOMS")
	room_list = ItemList.new()
	room_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_list.custom_minimum_size.y = 120
	library.add_child(room_list)
	room_list.item_selected.connect(func(index: int): _select_room(room_list.get_item_metadata(index)))
	room_list.item_activated.connect(func(_index: int): _edit_room())
	_heading(library, "ADD A SAVED ROOM")
	saved_rooms = OptionButton.new()
	saved_rooms.fit_to_longest_item = false
	library.add_child(saved_rooms)
	_button(library, "+ Add to world", _add_saved_room)
	_button(library, "+ Build a new room", func():
		editor._confirm_replace("Start a new room? Save current room edits first.", func():
			editor._new_level()
			close_workspace()
			editor._select_panel_tab(0)))
	_button(library, "Create starter world", func():
		editor._confirm_replace("Replace this layout with a playable two-room example? Existing room files are kept.", _create_starter))
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(center)
	var map_header := HBoxContainer.new()
	center.add_child(map_header)
	var map_title := Label.new()
	map_title.text = "WORLD MAP"
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_header.add_child(map_title)
	_button(map_header, "Fit map", func(): map_view.fit_map())
	_button(map_header, "Refresh rooms", _refresh_sources)
	map_view = VaniaWorldMap.new()
	map_view.world = world
	map_view.editable = true
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(map_view)
	map_view.room_selected.connect(_select_room)
	map_view.room_activated.connect(func(id: String):
		_select_room(id)
		_edit_room())
	map_view.exit_selected.connect(_pick_exit)
	editor._add_help(center, "Click a room to select it. Double-click to edit. Wheel: zoom. Middle-drag: pan. Blue squares are transitions; gold lines are ability gates.")
	var inspector := _column(columns, 310)
	inspector_tabs = TabContainer.new()
	inspector_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.add_child(inspector_tabs)
	var room_page := _inspector_page("Room")
	selection_title = Label.new()
	selection_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_page.add_child(selection_title)
	_button(room_page, "Edit this room", _edit_room)
	_button(room_page, "Make starting room", func():
		world.start_room = _selected(room_picker)
		world.arrange()
		_refresh_ui())
	_heading(room_page, "TRANSITIONS")
	editor._add_help(room_page, "Click a transition here or its blue handle on the map, then choose one in another room.")
	exits_list = ItemList.new()
	exits_list.custom_minimum_size.y = 160
	room_page.add_child(exits_list)
	exits_list.item_selected.connect(func(index: int): _pick_exit(_selected(room_picker), exits_list.get_item_metadata(index)))
	_button(room_page, "Remove room from layout", func():
		if _selected(room_picker).is_empty(): return
		editor._confirm_replace("Remove this room and its connections from the layout? The room file is kept.", _remove_room))
	var links := _inspector_page("Links")
	connection_hint = Label.new()
	connection_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	links.add_child(connection_hint)
	_heading(links, "ABILITY GATE")
	gate_ability = _option(links, ["Open passage"] + VaniaWorldData.ABILITIES)
	connect_button = _button(links, "Connect these transitions", _connect_rooms)
	_button(links, "Cancel selection", _clear_connection)
	_heading(links, "CONNECTIONS")
	connections_list = ItemList.new()
	connections_list.custom_minimum_size.y = 180
	links.add_child(connections_list)
	_button(links, "Remove selected connection", func():
		var selected := connections_list.get_selected_items()
		if not selected.is_empty():
			world.connections.remove_at(selected[0])
			world.arrange()
			_refresh_ui())
	var settings := _inspector_page("World")
	_heading(settings, "OPEN A WORLD")
	world_files = OptionButton.new()
	world_files.fit_to_longest_item = false
	settings.add_child(world_files)
	_button(settings, "Open selected world", _confirm_load)
	_button(settings, "New empty world", func(): editor._confirm_replace("Discard unsaved layout changes? Room files are kept.", _new_world))
	_heading(settings, "STARTING ABILITIES")
	editor._add_help(settings, "Select abilities already owned. Others are unlocked by pickups. Hold Ctrl to select several.")
	starting_list = ItemList.new()
	starting_list.select_mode = ItemList.SELECT_MULTI
	starting_list.custom_minimum_size.y = 180
	for ability in VaniaWorldData.ABILITIES: starting_list.add_item(ability.replace("_", " ").capitalize())
	settings.add_child(starting_list)
	starting_list.multi_selected.connect(func(_index: int, _selected: bool):
		world.starting_abilities.clear()
		for index in starting_list.get_selected_items():
			world.starting_abilities.append(VaniaWorldData.ABILITIES[index]))
	_button(settings, "Continue saved adventure", func(): _play(false, true))
	_button(settings, "Restart saved adventure", func(): editor._confirm_replace("Reset this world's player progress?", func(): _play(false, false)))
	var checks := _inspector_page("Check")
	_button(checks, "Check world", _validate)
	report = Label.new()
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checks.add_child(report)
	editor._add_help(checks, "Checks catch missing transitions, overlapping rooms and impossible upgrade routes. Test jumps and arrival spaces yourself.")
	workspace_status = Label.new()
	workspace_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace_status.add_theme_color_override("font_color", Color(0.4, 0.95, 0.75))
	layout.add_child(workspace_status)
	# Internal selections shared with the connection model; the designer uses
	# map handles instead of navigating four matching dropdowns.
	var hidden := VBoxContainer.new()
	add_child(hidden)
	hidden.hide()
	room_picker = OptionButton.new()
	from_room = OptionButton.new()
	to_room = OptionButton.new()
	from_exit = OptionButton.new()
	to_exit = OptionButton.new()
	for option in [room_picker, from_room, to_room, from_exit, to_exit]: hidden.add_child(option)
	refresh_files()
	_refresh_ui()
	hide()


func build_room_tools(parent: Control) -> void:
	_button(parent, "Open World Builder", open_workspace)
	editor._add_help(parent, "Build the room here. Connect it to other rooms in the full-screen World Builder.")
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(details)
	_button(parent, "Show whole room", _frame_room)
	_heading(parent, "TOUCH TRANSITION")
	exit_side = _option(parent, VaniaWorldData.SIDES)
	exit_side.item_selected.connect(func(index: int):
		zone_width.value = 48 if index < 2 else 128
		zone_height.value = 128 if index < 2 else 48)
	editor._add_help(parent, "Place across a room opening. Touching this area changes rooms automatically. The arrow points OUT of this room.")
	zone_width = _spin(parent, "Area width (pixels)", 48)
	zone_height = _spin(parent, "Area height (pixels)", 128)
	_button(parent, "Place transition area", func():
		marker_kind = 0
		editor._select_tool(editor.Tool.WORLD_MARKER)
		_status("Click at a room opening to place the touch area. Keep the inward arrival space clear."))
	_button(parent, "Apply to selected transition", func():
		if editor.selected_entities.size() != 1 or not editor.selected_entities[0] is VaniaMarker or editor.selected_entities[0].kind != 0:
			_status("Use Select / Move to select one transition area first.")
			return
		var marker: VaniaMarker = editor.selected_entities[0]
		editor._record_edit()
		marker.side = exit_side.selected
		marker.transition_size = Vector2(zone_width.value, zone_height.value)
		marker.queue_redraw()
		_status("Transition area updated. Save the room to keep it."))
	_heading(parent, "PICKUPS")
	pickup_ability = _option(parent, VaniaWorldData.ABILITIES)
	_button(parent, "Place ability pickup", func():
		marker_kind = 1
		editor._select_tool(editor.Tool.WORLD_MARKER))
	_button(parent, "Place health upgrade", func():
		marker_kind = 2
		editor._select_tool(editor.Tool.WORLD_MARKER))
	editor._add_help(parent, "Use Select / Move to move areas and pickups. Save the room before returning to World Builder.")


func _spin(parent: Control, text: String, value: float) -> SpinBox:
	editor._add_help(parent, text)
	var spin := SpinBox.new()
	spin.min_value = 16
	spin.max_value = 1024
	spin.step = 16
	spin.value = value
	parent.add_child(spin)
	return spin


func open_workspace() -> void:
	editor._cancel_shape_paint()
	editor._cancel_patrol_placement()
	editor.dragging_camera = false
	editor.cursor_move_dragging = false
	editor.cursor_marquee_dragging = false
	refresh_files()
	world.refresh_rooms()
	_refresh_ui()
	show()
	editor.placement_preview.hide()
	workspace_status.text = "Select a room to edit it, or click two transition handles to connect rooms."


func close_workspace() -> void:
	hide()


func _column(parent: Control, width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)
	return column


func _inspector_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_tabs.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return body


func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.95))
	parent.add_child(label)


func _process(delta: float) -> void:
	clock += delta
	if clock < 0.5: return
	clock = 0
	if details and not editor.is_playing and is_instance_valid(editor.level_root):
		var bounds := VaniaWorldData.measure_room(editor.level_root)
		details.text = "Room size: %d x %d screens" % [bounds.size.x / VaniaWorldData.SCREEN.x, bounds.size.y / VaniaWorldData.SCREEN.y]


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _option(parent: Control, values: Array) -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	for value in values: option.add_item(str(value).replace("_", " ").capitalize())
	parent.add_child(option)
	return option


func _selected(option: OptionButton) -> String:
	if option.selected < 0 or option.item_count == 0: return ""
	return str(option.get_item_metadata(option.selected))


func refresh_files() -> void:
	if not saved_rooms: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	_fill_files(saved_rooms, "user://levels", "tscn")
	_fill_files(world_files, DIRECTORY, "tres")


func _fill_files(option: OptionButton, directory: String, extension: String) -> void:
	var previous := _selected(option)
	option.clear()
	var dir := DirAccess.open(directory)
	if not dir: return
	var files := dir.get_files()
	files.sort()
	for file in files:
		if file.get_extension() != extension: continue
		option.add_item(file.get_basename())
		option.set_item_metadata(option.item_count - 1, directory.path_join(file))
		if directory.path_join(file) == previous: option.select(option.item_count - 1)


func _add_saved_room() -> void:
	var path := _selected(saved_rooms)
	if path.is_empty():
		_status("Save a room in the Level tab first.")
		return
	var error := world.add_room(path)
	_status(error if not error.is_empty() else "Room added. Place exits and connect it to the world.")
	_refresh_ui()


func _refresh_sources() -> void:
	var errors := world.refresh_rooms()
	_status("Room sizes and exits refreshed." if errors.is_empty() else "\n".join(errors))
	refresh_files()
	_refresh_ui()


func _refresh_ui() -> void:
	pending = pending.filter(func(endpoint: Dictionary): return not world.exit_data(endpoint.room, endpoint.exit).is_empty())
	for option in [room_picker, from_room, to_room]:
		var previous := _selected(option)
		option.clear()
		for entry in world.rooms:
			option.add_item(entry.name + (" [START]" if entry.id == world.start_room else ""))
			option.set_item_metadata(option.item_count - 1, entry.id)
			if entry.id == previous: option.select(option.item_count - 1)
	_refresh_exits(from_room, from_exit)
	_refresh_exits(to_room, to_exit)
	connections_list.clear()
	for link in world.connections:
		connections_list.add_item("%s / %s <-> %s / %s%s" % [link.a, link.exit_a, link.b, link.exit_b, "" if link.ability.is_empty() else " [" + link.ability + "]"])
	map_view.world = world
	map_view.selected = _selected(room_picker)
	map_view.queue_redraw()
	room_list.clear()
	for entry in world.rooms:
		room_list.add_item(entry.name.replace("_", " ").capitalize() + ("  *" if entry.id == world.start_room else ""))
		room_list.set_item_metadata(room_list.item_count - 1, entry.id)
	_select_room(_selected(room_picker))
	_update_connection_hint()
	starting_list.deselect_all()
	for index in VaniaWorldData.ABILITIES.size():
		if VaniaWorldData.ABILITIES[index] in world.starting_abilities: starting_list.select(index, false)


func _refresh_exits(rooms: OptionButton, exits: OptionButton) -> void:
	exits.clear()
	for entry in world.room(_selected(rooms)).get("exits", []):
		exits.add_item(entry.id + " (" + VaniaWorldData.SIDES[entry.side] + ")")
		exits.set_item_metadata(exits.item_count - 1, entry.id)


func _select_room(id: String) -> void:
	for index in room_picker.item_count:
		if room_picker.get_item_metadata(index) == id: room_picker.select(index)
	map_view.selected = id
	map_view.queue_redraw()
	for index in room_list.item_count:
		if room_list.get_item_metadata(index) == id: room_list.select(index)
	var entry := world.room(id)
	selection_title.text = "Select a room on the map." if entry.is_empty() else "%s\n%d x %d screens%s" % [entry.name.replace("_", " ").capitalize(), world.footprint(entry).x, world.footprint(entry).y, "\nStarting room" if id == world.start_room else ""]
	exits_list.clear()
	for exit in entry.get("exits", []):
		exits_list.add_item("%s  /  %s" % [VaniaWorldData.SIDES[exit.side], exit.id])
		exits_list.set_item_metadata(exits_list.item_count - 1, exit.id)


func _remove_room() -> void:
	var id := _selected(room_picker)
	var entry := world.room(id)
	if entry.is_empty(): return
	world.rooms.erase(entry)
	world.connections = world.connections.filter(func(link: Dictionary): return link.a != id and link.b != id)
	if world.start_room == id: world.start_room = world.rooms[0].id if not world.rooms.is_empty() else ""
	world.arrange()
	_refresh_ui()


func _connect_rooms() -> void:
	var ability: String = "" if gate_ability.selected == 0 else VaniaWorldData.ABILITIES[gate_ability.selected - 1]
	var error := world.connect_rooms(_selected(from_room), _selected(from_exit), _selected(to_room), _selected(to_exit), ability)
	_status(error if not error.is_empty() else "Rooms connected in both directions and positioned on the map.")
	if error.is_empty(): _clear_connection()
	_refresh_ui()


func _validate() -> void:
	var issues := world.validate()
	report.text = "World checks passed." if issues.is_empty() else "\n".join(issues)
	inspector_tabs.current_tab = 3
	_status("World checks passed." if issues.is_empty() else "Check the issues on the right.")


func _save_world() -> bool:
	var name: String = editor._sanitize_name(world_name.text)
	if name.is_empty():
		_status("Give your world a name.")
		return false
	world.display_name = world_name.text
	var error := ResourceSaver.save(world, DIRECTORY.path_join(name + ".tres"))
	_status("World saved." if error == OK else error_string(error))
	refresh_files()
	return error == OK


func _confirm_load() -> void:
	if _selected(world_files).is_empty(): return
	editor._confirm_replace("Replace unsaved world layout changes with the selected world?", _load_world)


func _load_world() -> void:
	var loaded := ResourceLoader.load(_selected(world_files), "", ResourceLoader.CACHE_MODE_REPLACE) as VaniaWorldData
	if not loaded:
		_status("Could not load that world.")
		return
	world = loaded
	_clear_connection()
	map_view.fit_map()
	world_name.text = world.display_name
	_refresh_ui()


func _new_world() -> void:
	world = VaniaWorldData.new()
	_clear_connection()
	map_view.fit_map()
	world.world_id = str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec())
	world_name.text = "my_world"
	report.text = ""
	_refresh_ui()


func _play(temporary: bool, resume: bool) -> void:
	var errors := world.refresh_rooms()
	errors.append_array(world.validate())
	report.text = "\n".join(errors)
	if not errors.is_empty():
		inspector_tabs.current_tab = 3
		_status("Check the issues on the right before playing.")
		return
	if not temporary and not _save_world(): return
	editor._play_adventure(world, temporary, resume)


func place_marker(cell: Vector2i) -> void:
	editor._record_edit()
	var marker := VaniaMarker.new()
	marker.kind = marker_kind
	marker.side = exit_side.selected
	marker.transition_size = Vector2(zone_width.value, zone_height.value)
	marker.ability = VaniaWorldData.ABILITIES[pickup_ability.selected]
	var prefix: String = ["Transition", "Ability", "Health"][marker_kind]
	var count := int(editor.level_root.get_meta("next_exit_id", 1)) if marker_kind == 0 else 1
	while editor.entities.has_node(prefix + str(count)): count += 1
	if marker_kind == 0: editor.level_root.set_meta("next_exit_id", count + 1)
	marker.name = prefix + str(count)
	# Stable across save/load and moves; unique even after a removed pickup.
	marker.marker_id = prefix + "_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec()) if marker_kind != 0 else str(marker.name)
	marker.position = editor.tile_layer.map_to_local(cell)
	editor.entities.add_child(marker)
	marker.owner = editor.level_root
	if marker.kind == 0:
		editor._select_tool(editor.Tool.CURSOR)
		editor.selected_entities.assign([marker])
		edit_transition.call_deferred(marker)
	_status("Placed %s. Save the room, then open World Builder to connect it." % prefix)


func edit_transition(marker: VaniaMarker) -> void:
	if not is_instance_valid(marker) or marker.kind != 0: return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Transition area"
	dialog.ok_button_text = "Apply"
	dialog.min_size = Vector2i(520, 610)
	add_child(dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(490, 530)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	scroll.add_child(form)
	editor._add_help(form, "Door ID (other transitions can arrive here)")
	var own_id := LineEdit.new()
	own_id.text = marker.marker_id
	own_id.editable = false
	form.add_child(own_id)
	editor._add_help(form, "Destination room")
	var rooms := OptionButton.new()
	form.add_child(rooms)
	rooms.add_item("Use World Builder connection")
	rooms.set_item_metadata(0, "")
	for entry in world.rooms:
		rooms.add_item(entry.name)
		rooms.set_item_metadata(rooms.item_count - 1, entry.id)
		if entry.id == marker.destination_room: rooms.select(rooms.item_count - 1)
	if not marker.destination_room.is_empty() and rooms.selected == 0:
		rooms.add_item(marker.destination_room + " (missing room)")
		rooms.set_item_metadata(rooms.item_count - 1, marker.destination_room)
		rooms.select(rooms.item_count - 1)
	editor._add_help(form, "Destination door ID")
	var doors := OptionButton.new()
	form.add_child(doors)
	var fill_doors := func(_index: int):
		doors.clear()
		var room_id := str(rooms.get_selected_metadata())
		var entry := world.room(room_id)
		if entry.is_empty(): return
		var fresh := world.read_room(entry.path)
		for exit in fresh.get("exits", []):
			doors.add_item(exit.id + " (" + VaniaWorldData.SIDES[exit.side] + ")")
			doors.set_item_metadata(doors.item_count - 1, exit.id)
			if exit.id == marker.destination_door: doors.select(doors.item_count - 1)
	rooms.item_selected.connect(fill_doors)
	fill_doors.call(rooms.selected)
	editor._add_help(form, "Exit direction / arrival side")
	var side := _option(form, VaniaWorldData.SIDES)
	side.select(marker.side)
	var width := _spin(form, "Touch area width", marker.zone_size().x)
	var height := _spin(form, "Touch area height", marker.zone_size().y)
	editor._add_help(form, "Required ability")
	var gate := _option(form, ["None"] + VaniaWorldData.ABILITIES)
	gate.select(VaniaWorldData.ABILITIES.find(marker.required_ability) + 1)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Add saved rooms to World Builder first. Save destination rooms after placing their doors. This route is one-way; set the other door's destination for a return route. Apply, then save this room."
	form.add_child(hint)
	dialog.get_ok_button().pressed.connect(func():
		if not is_instance_valid(marker): dialog.queue_free(); return
		var destination := str(rooms.get_selected_metadata())
		if not destination.is_empty() and doors.selected < 0:
			hint.text = "The destination needs a saved transition area. Place and save one first."
			return
		editor._record_edit()
		marker.destination_room = destination
		marker.destination_door = str(doors.get_selected_metadata()) if not destination.is_empty() else ""
		marker.required_ability = VaniaWorldData.ABILITIES[gate.selected - 1] if gate.selected > 0 else ""
		marker.side = side.selected
		marker.transition_size = Vector2(width.value, height.value)
		marker.queue_redraw()
		_status("Transition updated. Save this room to use its destination in world playtests.")
		dialog.queue_free())
	dialog.dialog_hide_on_ok = false
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _frame_room() -> void:
	var bounds := VaniaWorldData.measure_room(editor.level_root)
	editor.editor_camera.position = bounds.get_center()
	var viewport: Vector2 = editor.get_viewport_rect().size - Vector2(470, 50)
	editor._set_zoom(minf(viewport.x / bounds.size.x, viewport.y / bounds.size.y))



func _create_starter() -> void:
	var created := VaniaStarter.create()
	if not created:
		_status("Could not create starter rooms.")
		return
	world = created
	_clear_connection()
	map_view.fit_map()
	world_name.text = world.display_name
	_save_world()
	editor._refresh_level_list()
	_refresh_ui()
	report.text = "Starter ready: collect Dash in the atrium, then walk through its right opening. M opens the map."



func _status(text: String) -> void:
	editor._set_status(text)
	if workspace_status: workspace_status.text = text


func _edit_room() -> void:
	var entry := world.room(_selected(room_picker))
	if entry.is_empty(): return
	editor._confirm_replace("Open this room? Save current room edits first.", func():
		editor._load_level_path(entry.path)
		close_workspace()
		_frame_room())


func _pick_exit(room_id: String, exit_id: String) -> void:
	var exit := world.exit_data(room_id, exit_id)
	if exit.is_empty(): return
	if not world.connection_for(room_id, exit_id).is_empty():
		_status("This transition is already connected. Remove its link in Links to reconnect it.")
		inspector_tabs.current_tab = 1
		return
	if pending.size() >= 2: _clear_connection()
	if pending.size() == 1:
		var first: Dictionary = pending[0]
		if first.room == room_id and first.exit == exit_id:
			_clear_connection()
			return
		var source := world.exit_data(first.room, first.exit)
		if first.room == room_id or (int(source.side) ^ 1) != int(exit.side):
			_status("Choose an opposite-facing transition in a different room.")
			return
	pending.append({"room": room_id, "exit": exit_id})
	_select_room(room_id)
	inspector_tabs.current_tab = 1
	_update_connection_hint()


func _update_connection_hint() -> void:
	connect_button.disabled = pending.size() != 2
	map_view.pending_exits = pending.duplicate()
	map_view.queue_redraw()
	connection_hint.text = "Click a blue transition handle on the map to begin a connection."
	if pending.size() >= 1:
		connection_hint.text = "FROM: %s / %s\nChoose the matching transition in another room." % [pending[0].room, pending[0].exit]
	if pending.size() == 2:
		connection_hint.text = "%s / %s\n  connects to\n%s / %s" % [pending[0].room, pending[0].exit, pending[1].room, pending[1].exit]
		for index in 2:
			var rooms: OptionButton = from_room if index == 0 else to_room
			var exits: OptionButton = from_exit if index == 0 else to_exit
			for room_index in rooms.item_count:
				if rooms.get_item_metadata(room_index) == pending[index].room: rooms.select(room_index)
			_refresh_exits(rooms, exits)
			for exit_index in exits.item_count:
				if exits.get_item_metadata(exit_index) == pending[index].exit: exits.select(exit_index)


func _clear_connection() -> void:
	pending.clear()
	if connect_button: _update_connection_hint()
