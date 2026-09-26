extends Camera2D
class_name CutsceneCameraController2D

signal transition_finished
signal shake_done

var player_camera: CutsceneVirtualCamera2D
var current_camera: CutsceneVirtualCamera2D
var _transition_tween: Tween
var _transitioning := false

var _trauma := 0.0
var _trauma_power := 3.0
var _shake_decay := 0.8
var _max_shake_offset := Vector2(100.0, 75.0)
var _max_shake_roll := 0.1
var _shake_noise := FastNoiseLite.new()
var _noise_sample := 0.0
var _shake_rotation := 0.0


func _ready() -> void:
	top_level = true
	position_smoothing_enabled = false
	Cuts.base_camera = self
	Cuts.camera_controller = self
	_shake_noise.seed = randi()
	_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	call_deferred("_setup_camera_system")


func _process(delta: float) -> void:
	_update_shake(delta)
	if _transitioning or not is_instance_valid(current_camera):
		return

	var desired_position := current_camera.get_target_position()
	if current_camera.follow_damping:
		var weight := Vector2(
			1.0 - exp(-current_camera.follow_damping_speed.x * delta),
			1.0 - exp(-current_camera.follow_damping_speed.y * delta)
		)
		global_position = Vector2(
			lerpf(global_position.x, desired_position.x, weight.x),
			lerpf(global_position.y, desired_position.y, weight.y)
		)
	else:
		global_position = desired_position
	zoom = current_camera.camera_zoom
	rotation = current_camera.get_target_rotation() + _shake_rotation


func _setup_camera_system() -> void:
	if not is_instance_valid(Cuts.cutscene_cameras):
		var camera_container := CutsceneCameras.new()
		camera_container.name = "CutsceneCameras"
		get_tree().current_scene.add_child(camera_container)
		Cuts.cutscene_cameras = camera_container
	_find_player_camera()


func _find_player_camera() -> void:
	for node in get_tree().get_nodes_in_group("cutscene_virtual_cameras"):
		if node is CutsceneVirtualCamera2D and node.is_player_camera:
			set_player_camera(node)
			return

	var cameras := get_tree().current_scene.find_children("*", "CutsceneVirtualCamera2D", true, false)
	for node in cameras:
		if node.is_player_camera:
			set_player_camera(node)
			return


func set_player_camera(camera: CutsceneVirtualCamera2D) -> void:
	player_camera = camera
	Cuts.player_camera = camera
	if not is_instance_valid(current_camera):
		current_camera = camera
		Cuts.current_camera = camera
		_snap_to(camera)


func transition_to(camera: CutsceneVirtualCamera2D, settings: CutsceneCameraTransition = null) -> void:
	if not is_instance_valid(camera):
		push_error("Cutscene System: cannot transition to an invalid camera.")
		transition_finished.emit()
		return

	if is_instance_valid(_transition_tween):
		_transition_tween.kill()

	current_camera = camera
	Cuts.current_camera = camera
	_apply_camera_limits(camera)
	var duration := settings.duration if settings else 0.0
	if duration <= 0.0:
		_snap_to(camera)
		transition_finished.emit()
		return

	_transitioning = true
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.set_trans(settings.transition).set_ease(settings.ease)
	_transition_tween.tween_property(self, "global_position", camera.get_target_position(), duration)
	_transition_tween.tween_property(self, "zoom", camera.camera_zoom, duration)
	_transition_tween.tween_property(self, "rotation", camera.get_target_rotation(), duration)
	await _transition_tween.finished
	_transitioning = false
	transition_finished.emit()


func reset_to_player(settings: CutsceneCameraTransition = null) -> void:
	transition_to(player_camera, settings)
	if settings and settings.duration > 0.0:
		await transition_finished


func _snap_to(camera: CutsceneVirtualCamera2D) -> void:
	_apply_camera_limits(camera)
	global_position = camera.get_target_position()
	zoom = camera.camera_zoom
	rotation = camera.get_target_rotation()


func _apply_camera_limits(camera: CutsceneVirtualCamera2D) -> void:
	if camera.use_limits:
		limit_left = camera.limit_left
		limit_top = camera.limit_top
		limit_right = camera.limit_right
		limit_bottom = camera.limit_bottom
	else:
		limit_left = -10000000
		limit_top = -10000000
		limit_right = 10000000
		limit_bottom = 10000000


func add_trauma(amount: float, decay: float, max_offset: Vector2, max_roll: float, use_custom_noise := false, custom_noise: FastNoiseLite = null) -> void:
	_trauma = minf(_trauma + amount, 1.0)
	_shake_decay = decay
	_max_shake_offset = max_offset
	_max_shake_roll = max_roll
	if use_custom_noise and custom_noise:
		_shake_noise = custom_noise
	else:
		_shake_noise = FastNoiseLite.new()
		_shake_noise.seed = randi()
		_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_shake_noise.frequency = 0.4


func _update_shake(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO or not is_zero_approx(_shake_rotation):
			offset = Vector2.ZERO
			_shake_rotation = 0.0
			shake_done.emit()
		return

	_trauma = maxf(_trauma - _shake_decay * delta, 0.0)
	_noise_sample += delta * 60.0
	var amount := pow(_trauma, _trauma_power)
	_shake_rotation = _max_shake_roll * amount * _shake_noise.get_noise_2d(1.0, _noise_sample)
	offset = Vector2(
		_max_shake_offset.x * amount * _shake_noise.get_noise_2d(2.0, _noise_sample),
		_max_shake_offset.y * amount * _shake_noise.get_noise_2d(3.0, _noise_sample)
	)
