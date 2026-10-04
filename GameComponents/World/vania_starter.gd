extends RefCounted
class_name VaniaStarter

static func create() -> VaniaWorldData:
	var directory := "user://levels"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var suffix := 1
	while FileAccess.file_exists(directory.path_join("starter_%d_atrium.tscn" % suffix)) or FileAccess.file_exists(directory.path_join("starter_%d_overlook.tscn" % suffix)) or FileAccess.file_exists("user://worlds/starter_world_%d.tres" % suffix):
		suffix += 1
	var world := VaniaWorldData.new()
	world.world_id = "starter_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec())
	world.display_name = "Starter world " + str(suffix)
	for index in 2:
		var root := Node2D.new()
		root.name = "CreatedLevel"
		var tiles := TileMapLayer.new()
		tiles.name = "TileMapLayer"
		tiles.tile_set = preload("res://GameComponents/LevelEditor/level_tileset.tres")
		root.add_child(tiles)
		tiles.owner = root
		for x in 40:
			tiles.set_cell(Vector2i(x, 0), 0, Vector2i.ZERO)
			tiles.set_cell(Vector2i(x, 20), 0, Vector2i.ZERO)
		for y in 20:
			tiles.set_cell(Vector2i(0, y), 0, Vector2i.ZERO)
			tiles.set_cell(Vector2i(39, y), 0, Vector2i.ZERO)
		if index == 1:
			for x in range(16, 23): tiles.set_cell(Vector2i(x, 16), 0, Vector2i.ZERO)
		var entities := Node2D.new()
		entities.name = "Entities"
		root.add_child(entities)
		entities.owner = root
		var exit := VaniaMarker.new()
		exit.name = "Exit1"
		exit.marker_id = "Exit1"
		exit.side = 1 if index == 0 else 0
		exit.position = Vector2(1232 if index == 0 else 48, 624)
		for y in range(16, 20): tiles.erase_cell(Vector2i(39 if index == 0 else 0, y))
		entities.add_child(exit)
		exit.owner = root
		var pickup := VaniaMarker.new()
		pickup.name = "Upgrade"
		pickup.marker_id = "starter_upgrade"
		pickup.kind = 1 if index == 0 else 2
		pickup.ability = "dash"
		pickup.position = Vector2(480 if index == 0 else 800, 624)
		entities.add_child(pickup)
		pickup.owner = root
		var checkpoint := preload("res://GameComponents/Interaction/checkpoint_2d.tscn").instantiate() as Node2D
		checkpoint.name = "Checkpoint"
		checkpoint.position = Vector2(288, 624)
		entities.add_child(checkpoint)
		checkpoint.owner = root
		var start := Node2D.new()
		start.name = "PlayerStart"
		start.position = Vector2(96, 624)
		root.add_child(start)
		start.owner = root
		var packed := PackedScene.new()
		var error := packed.pack(root)
		var path := directory.path_join("starter_%d_%s.tscn" % [suffix, "atrium" if index == 0 else "overlook"])
		if error == OK: error = ResourceSaver.save(packed, path)
		root.free()
		if error != OK: return null
		if not world.add_room(path).is_empty(): return null
	world.connect_rooms(world.rooms[0].id, "Exit1", world.rooms[1].id, "Exit1", "dash")
	return world
