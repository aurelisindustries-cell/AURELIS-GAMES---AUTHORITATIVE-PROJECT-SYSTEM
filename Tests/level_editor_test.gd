extends Node

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var editor := load("res://GameComponents/LevelEditor/level_editor.tscn").instantiate() as SimpleLevelEditor
	get_tree().root.add_child(editor)
	await get_tree().process_frame
	editor.set_process(false)
	check(editor.panel_pages.size() == 4, "Four editor tabs")
	editor._select_panel_tab(1)
	check(editor.panel_pages[1].visible, "Objects tab opens")
	editor._select_panel_tab(1)
	await get_tree().create_timer(0.3).timeout
	check(not editor.panel_content.visible, "Tab retracts")
	editor._select_panel_tab(1)
	for scene in [editor.PATROL_ENEMY, editor.FLYING_PATROL_ENEMY]:
		editor._place_entity(scene, Vector2i(20 + editor.entities.get_child_count() * 10, 10))
		await get_tree().process_frame
		var enemy := editor.entities.get_child(-1) as Node2D
		var task := editor._patrol_task(enemy)
		check(task != null, "Patrol task available")
		check(not task.point_a.top_level, "Editor points follow enemy")
		editor._begin_patrol_placement("point_a")
		editor._place_patrol_point(Vector2i(18, 8))
		editor._begin_patrol_placement("point_b")
		editor._place_patrol_point(Vector2i(24, 12))
		if not task.use_vertical_movement:
			check(is_equal_approx(task.point_a.global_position.y, enemy.global_position.y), "Ground points stay level")
		else:
			check(not is_equal_approx(task.point_a.global_position.y, task.point_b.global_position.y), "Flying points have vertical range")
		editor.patrol_pause.value = 1.25
		editor.patrol_speed.value = 1.5
		editor.patrol_start.button_pressed = true
		editor._update_patrol_settings(0)
		var old_point := task.point_a.global_position
		editor._move_selection(Vector2i(2, 1))
		check(task.point_a.global_position.is_equal_approx(old_point + Vector2(64, 32)), "Moving enemy moves route")
	editor._place_player_start(Vector2i(16, 10))
	var test_name := "editor_regression_%d" % Time.get_ticks_usec()
	editor.name_edit.text = test_name
	editor._save_level()
	var path := "user://levels/%s.tscn" % test_name
	check(FileAccess.file_exists(path), "Level saved")
	var expected: Array[Dictionary] = []
	for enemy in editor.entities.get_children():
		expected.append({"position": enemy.position, "settings": enemy.get_meta("editor_patrol").duplicate()})
	await get_tree().process_frame
	editor._load_selected_level()
	await get_tree().process_frame
	check(editor.entities.get_child_count() == 2, "Both enemies loaded")
	for index in 2:
		var enemy := editor.entities.get_child(index) as Node2D
		var task := editor._patrol_task(enemy)
		check(enemy.position.is_equal_approx(expected[index].position), "Enemy position survives load")
		check(task.point_a.position.is_equal_approx(expected[index].settings.point_a), "A survives load")
		check(task.point_b.position.is_equal_approx(expected[index].settings.point_b), "B survives load")
		check(is_equal_approx(task.pause_at_point, 1.25), "Pause survives load")
		check(is_equal_approx(task.speed_multiplier, 1.5), "Speed survives load")
		check(task.start_at_point_b, "Starting direction survives load")
	editor._play_level()
	await get_tree().process_frame
	check(editor.is_playing, "Playtest starts")
	check(not editor.level_root.is_inside_tree(), "Authoring world isolated from play")
	var runtime_enemy := editor.play_world.get_node("Entities").get_child(0) as Node2D
	var runtime_task := editor._patrol_task(runtime_enemy)
	check(runtime_task.point_a.top_level, "Runtime route anchored")
	var anchor := runtime_task.point_a.global_position
	runtime_enemy.position += Vector2(100, 0)
	check(runtime_task.point_a.global_position.is_equal_approx(anchor), "Runtime point stays fixed as enemy moves")
	runtime_enemy.queue_free()
	await get_tree().process_frame
	editor._stop_playing()
	await get_tree().process_frame
	check(editor.entities.get_child_count() == 2, "Playtest deletion does not change authored enemies")
	check(editor.entities.get_child(0).position.is_equal_approx(expected[0].position), "Playtest movement does not change authored position")
	editor.tile_layer.set_cell(Vector2i(20, 10), 0, Vector2i.ZERO, TileSetAtlasSource.TRANSFORM_FLIP_H)
	editor.selected_cells.assign([Vector2i(20, 10)])
	editor.selected_entities.assign([editor.entities.get_child(0)])
	editor._copy_selection()
	editor._paste_selection(Vector2i(40, 20))
	check(editor.entities.get_child_count() == 3, "Paste duplicates the selected enemy")
	check(editor.tile_layer.get_cell_alternative_tile(Vector2i(40, 20)) == TileSetAtlasSource.TRANSFORM_FLIP_H, "Paste preserves tile transform")
	var pasted_task := editor._patrol_task(editor.entities.get_child(2))
	check(is_equal_approx(pasted_task.pause_at_point, 1.25), "Paste preserves patrol settings")
	check(pasted_task.point_a.position.is_equal_approx(expected[0].settings.point_a), "Paste preserves relative patrol route")
	editor._undo_edit()
	check(editor.entities.get_child_count() == 2 and editor.tile_layer.get_cell_source_id(Vector2i(40, 20)) == -1, "Undo removes mixed paste")
	editor._redo_edit()
	check(editor.entities.get_child_count() == 3 and editor.tile_layer.get_cell_source_id(Vector2i(40, 20)) == 0, "Redo restores mixed paste")
	for x in range(50, 61): editor.tile_layer.set_cell(Vector2i(x, 30), 0, Vector2i.ZERO)
	editor.gesture_active = true
	editor.gesture_recorded = false
	editor._erase_stroke_to(Vector2i(50, 30))
	editor._erase_stroke_to(Vector2i(60, 30))
	editor._end_edit_gesture()
	check(editor.tile_layer.get_cell_source_id(Vector2i(55, 30)) == -1, "Fast erase drag fills gaps between mouse events")
	editor._undo_edit()
	check(editor.tile_layer.get_cell_source_id(Vector2i(50, 30)) == 0 and editor.tile_layer.get_cell_source_id(Vector2i(60, 30)) == 0, "One undo restores the entire erase stroke")
	editor._place_entity(editor.CHECKPOINT, Vector2i(70, 30))
	check(editor.redo_steps.is_empty(), "A new edit clears redo history")
	if "--capture-editor" in OS.get_cmdline_user_args():
		if editor.selected_panel_tab != 1:
			editor._select_panel_tab(1)
		else:
			editor.panel_content.show()
		editor.selected_entities.assign([editor.entities.get_child(0)])
		editor._refresh_patrol_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/synthesis-editor.png")
	DirAccess.remove_absolute(path)
	editor.queue_free()
	await get_tree().process_frame
	print("Level editor regression: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
