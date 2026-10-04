extends Resource
class_name VaniaWorldData

const SCREEN := Vector2i(1280, 736)
const ABILITIES := ["dash", "double_jump", "wall_jump", "slide", "air_dash", "wall_slide", "ledge_flow", "propulsor_step"]
const SIDES := ["Left", "Right", "Up", "Down"]
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

@export var world_id := ""
@export var display_name := "My world"
@export var start_room := ""
@export var starting_abilities: Array[String] = []
# Bounds and exits are cached from saved scenes. IDs stay stable on refresh.
@export var rooms: Array[Dictionary] = []
@export var connections: Array[Dictionary] = []


static func measure_room(root: Node2D) -> Rect2:
	var tiles := root.get_node_or_null("TileMapLayer") as TileMapLayer
	var bounds := Rect2()
	var has_content := false
	if tiles and not tiles.get_used_cells().is_empty():
		var used := tiles.get_used_rect()
		bounds = Rect2(Vector2(used.position * 32), Vector2(used.size * 32))
		has_content = true
	for node in root.find_children("*", "Node2D", true, false):
		if node.get_parent() != root.get_node_or_null("Entities") and node.name != "PlayerStart": continue
		var point: Vector2 = root.to_local(node.global_position) if root.is_inside_tree() else node.position
		var object_bounds := Rect2(point - Vector2(32, 64), Vector2(64, 96))
		if node.is_in_group("burrow_soil"): object_bounds = Rect2(point + Vector2(-128, 0), Vector2(256, 96))
		if node is VaniaMarker and node.kind == 0:
			object_bounds = Rect2(point + node.zone_rect().position, node.zone_rect().size)
			object_bounds = object_bounds.merge(Rect2(point + node.arrival_offset() - Vector2(32, 64), Vector2(64, 96)))
		bounds = bounds.merge(object_bounds) if has_content else object_bounds
		has_content = true
		if node.has_meta("editor_patrol"):
			var patrol: Dictionary = node.get_meta("editor_patrol")
			for key in ["point_a", "point_b"]:
				if patrol.has(key):
					bounds = bounds.merge(Rect2(point + Vector2(patrol[key]) - Vector2(16, 64), Vector2(32, 80)))
	if not has_content: return Rect2(Vector2.ZERO, Vector2(SCREEN))
	var origin := (bounds.position / 32.0).floor() * 32.0
	var extent := bounds.end - origin
	var size_in_screens := Vector2(ceilf(extent.x / SCREEN.x), ceilf(extent.y / SCREEN.y)).max(Vector2.ONE)
	return Rect2(origin, size_in_screens * Vector2(SCREEN))


func room(id: String) -> Dictionary:
	for entry in rooms:
		if entry.id == id: return entry
	return {}


func read_room(path: String) -> Dictionary:
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if not scene: return {}
	var root := scene.instantiate() as Node2D
	if not root: return {}
	if not root.get_node_or_null("TileMapLayer") is TileMapLayer or not root.get_node_or_null("Entities"):
		root.free()
		return {}
	var entry := {"id": path.get_file().get_basename(), "path": path, "name": path.get_file().get_basename(),
		"bounds": measure_room(root), "position": Vector2i.ZERO, "exits": [], "has_start": root.has_node("PlayerStart"), "abilities": []}
	for node in root.get_node("Entities").get_children():
		if node.get_script() == preload("res://GameComponents/World/vania_marker.gd"):
			if node.kind == 0:
				entry.exits.append({"id": node.marker_id, "side": node.side, "position": node.position, "destination_room": node.destination_room, "destination_door": node.destination_door, "required_ability": node.required_ability})
			elif node.kind == 1:
				entry.abilities.append(node.ability)
	root.free()
	return entry


func add_room(path: String) -> String:
	var entry := read_room(path)
	if entry.is_empty(): return "Save a valid room before adding it."
	if not room(entry.id).is_empty(): return "That room is already in this world."
	rooms.append(entry)
	if start_room.is_empty(): start_room = entry.id
	arrange()
	return ""


func refresh_rooms() -> PackedStringArray:
	var errors := PackedStringArray()
	for index in rooms.size():
		var updated := read_room(rooms[index].path)
		if updated.is_empty():
			errors.append("Cannot read room: " + rooms[index].name)
		else:
			updated.position = rooms[index].position
			rooms[index] = updated
	arrange()
	return errors


func exit_data(room_id: String, exit_id: String) -> Dictionary:
	for entry in room(room_id).get("exits", []):
		if entry.id == exit_id: return entry
	return {}


func connection_for(room_id: String, exit_id: String) -> Dictionary:
	for link in routing_links():
		if link.a == room_id and link.exit_a == exit_id or (not link.get("directed", false) and link.b == room_id and link.exit_b == exit_id):
			return link
	return {}


func routing_links() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in rooms:
		for exit in entry.exits:
			if not str(exit.get("destination_room", "")).is_empty():
				result.append({"a": entry.id, "exit_a": exit.id, "b": exit.destination_room, "exit_b": exit.get("destination_door", ""), "ability": exit.get("required_ability", ""), "directed": true})
	for link in connections:
		if not str(exit_data(link.a, link.exit_a).get("destination_room", "")).is_empty() or not str(exit_data(link.b, link.exit_b).get("destination_room", "")).is_empty(): continue
		result.append(link)
	return result


func connect_rooms(a: String, exit_a: String, b: String, exit_b: String, ability: String = "") -> String:
	if a == b: return "Choose two different rooms."
	var source := exit_data(a, exit_a)
	var destination := exit_data(b, exit_b)
	if source.is_empty() or destination.is_empty(): return "Place and save an exit in each room first."
	if (int(source.side) ^ 1) != int(destination.side): return "Pair opposite exits: left/right or up/down."
	if not connection_for(a, exit_a).is_empty() or not connection_for(b, exit_b).is_empty():
		return "That exit is already connected. Remove its old connection first."
	connections.append({"a": a, "exit_a": exit_a, "b": b, "exit_b": exit_b, "ability": ability})
	arrange()
	return ""


func footprint(entry: Dictionary) -> Vector2i:
	return Vector2i(entry.bounds.size / Vector2(SCREEN))


func adjacent_position(source: Dictionary, destination: Dictionary, side: int, source_exit: Dictionary = {}, target_exit: Dictionary = {}) -> Vector2i:
	var origin: Vector2i = source.position
	var source_size := footprint(source)
	var destination_size := footprint(destination)
	var alignment := Vector2i.ZERO
	if not source_exit.is_empty() and not target_exit.is_empty():
		var source_cell := Vector2i(((Vector2(source_exit.position) - source.bounds.position) / Vector2(SCREEN)).floor())
		var target_cell := Vector2i(((Vector2(target_exit.position) - destination.bounds.position) / Vector2(SCREEN)).floor())
		alignment = source_cell - target_cell
	if side < 2: origin.y += alignment.y
	else: origin.x += alignment.x
	match side:
		0: return origin + Vector2i(-destination_size.x, 0)
		1: return origin + Vector2i(source_size.x, 0)
		2: return origin + Vector2i(0, -destination_size.y)
		_: return origin + Vector2i(0, source_size.y)


func arrange() -> void:
	var placed := {}
	var next_x := 0
	var ordered := rooms.duplicate()
	var start := room(start_room)
	if not start.is_empty():
		ordered.erase(start)
		ordered.push_front(start)
	for seed in ordered:
		if placed.has(seed.id): continue
		seed.position = Vector2i(next_x, 0)
		placed[seed.id] = true
		var queue: Array[String] = [seed.id]
		while not queue.is_empty():
			var current := room(queue.pop_front())
			next_x = maxi(next_x, int(current.position.x) + footprint(current).x + 2)
			for link in routing_links():
				var forward: bool = link.a == current.id
				if not forward and link.b != current.id: continue
				var target := room(link.b if forward else link.a)
				var exit := exit_data(current.id, link.exit_a if forward else link.exit_b)
				if target.is_empty() or exit.is_empty() or placed.has(target.id): continue
				var target_exit := exit_data(target.id, link.exit_b if forward else link.exit_a)
				target.position = adjacent_position(current, target, exit.side, exit, target_exit)
				placed[target.id] = true
				queue.append(target.id)


func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if rooms.is_empty(): issues.append("Add at least one saved room.")
	if room(start_room).is_empty(): issues.append("Choose a starting room.")
	elif not room(start_room).has_start: issues.append("Place a Player Start in the starting room, save it, then refresh.")
	for entry in rooms:
		if not FileAccess.file_exists(entry.path): issues.append("Missing room file: " + entry.name)
		for exit in entry.exits:
			if connection_for(entry.id, exit.id).is_empty(): issues.append("Unconnected exit: %s / %s" % [entry.name, exit.id])
	for link in routing_links():
		if exit_data(link.a, link.exit_a).is_empty() or exit_data(link.b, link.exit_b).is_empty():
			issues.append("A connection refers to a deleted room or exit.")
		else:
			if link.get("directed", false): continue
			var source := exit_data(link.a, link.exit_a)
			var target := exit_data(link.b, link.exit_b)
			if (int(source.side) ^ 1) != int(target.side):
				issues.append("Exit directions changed: reconnect " + link.a + " and " + link.b)
			elif adjacent_position(room(link.a), room(link.b), source.side, source, target) != room(link.b).position:
				issues.append("Loop does not line up: " + link.a + " to " + link.b + ". Adjust exit positions or room sizes.")
	for a in rooms.size():
		for b in range(a + 1, rooms.size()):
			if Rect2i(rooms[a].position, footprint(rooms[a])).intersects(Rect2i(rooms[b].position, footprint(rooms[b]))):
				issues.append("Map overlap: %s and %s. Change the exit directions or connections." % [rooms[a].name, rooms[b].name])
	# Reachability includes upgrades discovered in accessible rooms, catching
	# an ability accidentally placed behind its own gate.
	var reached := {start_room: true}
	var unlocked := starting_abilities.duplicate()
	var changed := true
	while changed:
		changed = false
		for entry in rooms:
			if reached.has(entry.id):
				for ability in entry.abilities:
					if ability not in unlocked:
						unlocked.append(ability)
						changed = true
		for link in routing_links():
			if not link.ability.is_empty() and link.ability not in unlocked: continue
			if reached.has(link.a) and not reached.has(link.b):
				reached[link.b] = true
				changed = true
			if not link.get("directed", false) and reached.has(link.b) and not reached.has(link.a):
				reached[link.a] = true
				changed = true
	for entry in rooms:
		if not reached.has(entry.id): issues.append("Unreachable with available abilities: " + entry.name)
	return issues
