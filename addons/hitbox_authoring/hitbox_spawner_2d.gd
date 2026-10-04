@tool
@icon("res://addons/at-icons/node2d/film.svg")
extends Node2D
class_name HitboxSpawner2D

signal hit_landed(data: HitboxFrameData, hurtbox: HurtboxComponent2D, hit: HitData)

@export var animation_player: AnimationPlayer
@export var attack_source: Node
@export_flags_2d_physics var runtime_collision_layer: int = 16
@export_flags_2d_physics var runtime_collision_mask: int = 8
@export_storage var hitboxes: Array[HitboxFrameData] = []

var _instances: Dictionary = {}
var _previewed_animation: StringName
var _previewed_time := -1.0
var _show_editor_previews := false


func _ready() -> void:
	if not animation_player:
		animation_player = get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not attack_source:
		attack_source = get_parent()
	set_process(Engine.is_editor_hint())
	set_physics_process(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _has_authoring_handles():
		_clear_instances()
		return
	_store_preview_edits()
	_refresh_instances(true)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not animation_player:
		return
	if _has_authoring_handles():
		_refresh_handle_instances()
		return
	_previewed_animation = animation_player.current_animation
	if _previewed_animation.is_empty():
		_previewed_time = -1.0
		_clear_instances()
		return
	_previewed_time = animation_player.current_animation_position
	_refresh_instances(false)


func show_editor_preview(animation_name: StringName, time: float) -> void:
	_show_editor_previews = true
	_previewed_animation = animation_name
	_previewed_time = time
	_refresh_instances(true)


func hide_editor_preview() -> void:
	_show_editor_previews = false
	_clear_instances()


func add_hitbox(animation_name: StringName, time: float) -> HitboxFrameData:
	var data := HitboxFrameData.new()
	data.animation = animation_name
	data.start_time = maxf(time, 0.0)
	data.shape = RectangleShape2D.new()
	(data.shape as RectangleShape2D).size = Vector2(32.0, 24.0)
	data.hit = HitData.new()
	hitboxes.append(data)
	return data


func get_preview_for(data: HitboxFrameData) -> Area2D:
	return _instances.get(data) as Area2D


func _refresh_instances(editor_preview: bool) -> void:
	if editor_preview and not _show_editor_previews:
		_clear_instances()
		return
	var active: Dictionary = {}
	for data in hitboxes:
		if data and data.is_active(_previewed_animation, _previewed_time):
			active[data] = true
			if not _instances.has(data):
				_instances[data] = _create_instance(data, editor_preview)
	for data in _instances.keys():
		if not active.has(data):
			_remove_instance(data)


func _create_instance(data: HitboxFrameData, editor_preview: bool) -> Area2D:
	var area: Area2D
	if editor_preview:
		area = Area2D.new()
		area.name = "Hitbox Preview"
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = false
	else:
		var runtime_hitbox := HitboxComponent2D.new()
		runtime_hitbox.name = "Active Hitbox"
		runtime_hitbox.collision_layer = runtime_collision_layer
		runtime_hitbox.collision_mask = runtime_collision_mask
		area = runtime_hitbox
	add_child(area, false, Node.INTERNAL_MODE_BACK if editor_preview else Node.INTERNAL_MODE_DISABLED)
	area.position = data.position
	area.rotation = data.rotation
	area.scale = data.scale
	if not editor_preview: area.scale *= _upgrade_reach()
	var collision := CollisionShape2D.new()
	collision.name = "Shape"
	if editor_preview:
		collision.shape = data.shape if data.shape else RectangleShape2D.new()
	else:
		collision.shape = data.shape.duplicate(true) if data.shape else RectangleShape2D.new()
	area.add_child(collision)
	if not editor_preview:
		var runtime_hitbox := area as HitboxComponent2D
		runtime_hitbox.hit_landed.connect(_on_runtime_hit_landed.bind(data))
		runtime_hitbox.activate(_upgrade_hit(data.hit), attack_source)
	return area


func _on_runtime_hit_landed(hurtbox: HurtboxComponent2D, hit: HitData, data: HitboxFrameData) -> void:
	hit_landed.emit(data, hurtbox, hit)


func _store_preview_edits() -> void:
	for data in _instances:
		var area := _instances[data] as Area2D
		if not is_instance_valid(area):
			continue
		var changed: bool = data.position != area.position or not is_equal_approx(data.rotation, area.rotation) or data.scale != area.scale
		if changed:
			data.position = area.position
			data.rotation = area.rotation
			data.scale = area.scale
			data.emit_changed()
		var collision := area.get_node_or_null("Shape") as CollisionShape2D
		if collision and collision.shape and data.shape != collision.shape:
			data.shape = collision.shape
			data.emit_changed()


func _remove_instance(data: Variant) -> void:
	var instance := _instances.get(data) as Area2D
	_instances.erase(data)
	if is_instance_valid(instance):
		instance.queue_free()


func _clear_instances() -> void:
	for data in _instances.keys():
		_remove_instance(data)


func _has_authoring_handles() -> bool:
	for child in get_children():
		if child is HitboxAuthoringHandle2D:
			return true
	return false


func _refresh_handle_instances() -> void:
	var active_handles: Dictionary = {}
	for child in get_children():
		var handle := child as HitboxAuthoringHandle2D
		if not handle or not handle.active:
			continue
		active_handles[handle] = true
		if not _instances.has(handle):
			_instances[handle] = _create_handle_instance(handle)
		var area := _instances[handle] as Area2D
		area.transform = handle.transform
		area.scale *= _upgrade_reach()
	for key in _instances.keys():
		if key is HitboxAuthoringHandle2D and not active_handles.has(key):
			_remove_instance(key)


func _create_handle_instance(handle: HitboxAuthoringHandle2D) -> HitboxComponent2D:
	var area := HitboxComponent2D.new()
	area.name = "%s Active" % handle.name
	area.collision_layer = runtime_collision_layer
	area.collision_mask = runtime_collision_mask
	add_child(area)
	area.transform = handle.transform
	var collision := CollisionShape2D.new()
	collision.shape = handle.shape.duplicate(true) if handle.shape else RectangleShape2D.new()
	area.add_child(collision)
	area.hit_landed.connect(_on_handle_hit_landed.bind(handle))
	area.activate(_upgrade_hit(handle.hit), attack_source)
	return area


func _upgrade_hit(hit: HitData) -> HitData:
	var combat := attack_source.find_child("PlayerCombatController", true, false) if is_instance_valid(attack_source) else null
	return combat.upgraded_dagger_hit(hit) if combat and hit else hit


func _upgrade_reach() -> float:
	var combat := attack_source.find_child("PlayerCombatController", true, false) if is_instance_valid(attack_source) else null
	return combat.dagger_reach_multiplier() if combat else 1.0


func _on_handle_hit_landed(hurtbox: HurtboxComponent2D, hit: HitData, handle: HitboxAuthoringHandle2D) -> void:
	var data := HitboxFrameData.new()
	data.animation = animation_player.current_animation if animation_player else &""
	data.position = handle.position
	data.shape = handle.shape
	data.hit = handle.hit
	hit_landed.emit(data, hurtbox, hit)
