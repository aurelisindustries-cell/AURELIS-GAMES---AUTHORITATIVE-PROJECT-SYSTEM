extends Control
class_name VaniaWorldMap

signal room_selected(id: String)
signal room_activated(id: String)
signal exit_selected(room_id: String, exit_id: String)

var world: VaniaWorldData
var discovered: Array = []
var reveal_all := true
var editable := false
var selected := ""
var hit_rects: Dictionary = {}
var exit_hits: Array[Dictionary] = []
var pending_exits: Array[Dictionary] = []
var map_zoom := 1.0
var pan := Vector2.ZERO
var panning := false


func _ready() -> void:
	custom_minimum_size = Vector2(280, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


func fit_map() -> void:
	map_zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()


func _port_position(entry: Dictionary, exit: Dictionary, rect: Rect2) -> Vector2:
	var fraction: Vector2 = (Vector2(exit.position) - entry.bounds.position) / entry.bounds.size
	fraction = fraction.clamp(Vector2(0.08, 0.12), Vector2(0.92, 0.88))
	match int(exit.side):
		0: return Vector2(rect.position.x, rect.position.y + fraction.y * rect.size.y)
		1: return Vector2(rect.end.x, rect.position.y + fraction.y * rect.size.y)
		2: return Vector2(rect.position.x + fraction.x * rect.size.x, rect.position.y)
		_: return Vector2(rect.position.x + fraction.x * rect.size.x, rect.end.y)


func _draw() -> void:
	hit_rects.clear()
	exit_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.05, 0.075))
	if editable:
		for x in range(0, int(size.x), 24):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.12, 0.17, 0.23, 0.45))
		for y in range(0, int(size.y), 24):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.12, 0.17, 0.23, 0.45))
	if not world or world.rooms.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(28, 80), "Your world starts with a room.", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.6, 0.9, 1))
		draw_string(ThemeDB.fallback_font, Vector2(28, 112), "Add a saved room on the left,", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(ThemeDB.fallback_font, Vector2(28, 138), "or try Create starter world.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		return
	var bounds := Rect2(Vector2(world.rooms[0].position), Vector2(world.footprint(world.rooms[0])))
	for entry in world.rooms:
		bounds = bounds.merge(Rect2(Vector2(entry.position), Vector2(world.footprint(entry))))
	var scale_factor := minf((size.x - 80) / maxf(bounds.size.x, 1), (size.y - 90) / maxf(bounds.size.y, 1))
	if editable: scale_factor = minf(scale_factor, 220)
	scale_factor *= map_zoom
	var offset := (size - bounds.size * scale_factor) * 0.5 - bounds.position * scale_factor + pan
	for entry in world.rooms:
		if not reveal_all and entry.id not in discovered: continue
		var rect := Rect2(Vector2(entry.position) * scale_factor + offset, Vector2(world.footprint(entry)) * scale_factor).grow(-10 if editable else -3)
		hit_rects[entry.id] = rect
		draw_rect(rect, Color(0.09, 0.29, 0.36) if entry.id == selected else Color(0.1, 0.16, 0.23))
		draw_rect(rect, Color(0.4, 0.95, 1.0) if entry.id == selected else Color(0.3, 0.42, 0.55), false, 2)
		var title: String = entry.name.replace("_", " ").capitalize()
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 24), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 15)
		if rect.size.y > 65:
			var subtitle := "%d x %d screens" % [world.footprint(entry).x, world.footprint(entry).y]
			if entry.id == world.start_room: subtitle += "  /  START"
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 47), subtitle, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 12, Color(0.6, 0.75, 0.82))
		for exit in entry.exits:
			exit_hits.append({"room": entry.id, "exit": exit.id, "side": exit.side, "position": _port_position(entry, exit, rect)})
	for link in world.routing_links():
		if not hit_rects.has(link.a) or not hit_rects.has(link.b): continue
		var a: Vector2 = _port_position(world.room(link.a), world.exit_data(link.a, link.exit_a), hit_rects[link.a]) if not world.exit_data(link.a, link.exit_a).is_empty() else hit_rects[link.a].get_center()
		var b: Vector2 = _port_position(world.room(link.b), world.exit_data(link.b, link.exit_b), hit_rects[link.b]) if not world.exit_data(link.b, link.exit_b).is_empty() else hit_rects[link.b].get_center()
		draw_line(a, b, Color(1, 0.7, 0.25) if not link.ability.is_empty() else Color(0.4, 0.9, 0.8), 3)
	if not editable: return
	for port in exit_hits:
		var color := Color(0.25, 0.8, 1)
		var link := world.connection_for(port.room, port.exit)
		if not link.is_empty(): color = Color(1, 0.7, 0.25) if not link.ability.is_empty() else Color(0.4, 0.9, 0.8)
		for pending in pending_exits:
			if pending.room == port.room and pending.exit == port.exit: color = Color(1, 0.8, 0.25)
		draw_rect(Rect2(port.position - Vector2(7, 7), Vector2(14, 14)), color)
		draw_rect(Rect2(port.position - Vector2(7, 7), Vector2(14, 14)), Color(0.8, 1, 1), false, 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE): panning = false
		if panning:
			pan += event.relative
			queue_redraw()
			accept_event()
		tooltip_text = ""
		for port in exit_hits:
			if event.position.distance_to(port.position) <= 14:
				tooltip_text = "%s / %s (%s) — click to connect" % [port.room, port.exit, VaniaWorldData.SIDES[port.side]]
				break
	if not event is InputEventMouseButton: return
	if editable and event.button_index == MOUSE_BUTTON_MIDDLE:
		panning = event.pressed
		accept_event()
		return
	if not event.pressed: return
	if editable and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		map_zoom = clampf(map_zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.25, 4.0)
		queue_redraw()
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if editable:
		for port in exit_hits:
			if event.position.distance_to(port.position) <= 14:
				exit_selected.emit(port.room, port.exit)
				accept_event()
				return
	for id in hit_rects:
		if hit_rects[id].has_point(event.position):
			room_selected.emit(id)
			if event.double_click and editable: room_activated.emit(id)
			accept_event()
			return
