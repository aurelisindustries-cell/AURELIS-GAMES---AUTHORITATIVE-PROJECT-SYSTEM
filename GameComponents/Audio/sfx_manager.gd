extends Node
class_name SFXManager

@export_range(-40.0, 6.0, 0.5) var master_volume_db: float = -8.0
@export_range(1, 32, 1) var max_simultaneous_sounds: int = 16
@export_range(0.0, 0.3, 0.01) var pitch_variation: float = 0.02
@export_category("Player Movement")
@export var jump_sound: AudioStream
@export var dash_sound: AudioStream
@export var slide_sound: AudioStream
@export var land_sound: AudioStream
@export_category("Player Combat")
@export var dagger_sound: AudioStream
@export var caster_sound: AudioStream
@export var player_damage_sound: AudioStream
@export_category("Enemies")
@export var enemy_damage_sound: AudioStream
@export var enemy_attack_sound: AudioStream
@export var enemy_death_sound: AudioStream
@export_category("World and Boss")
@export var door_sound: AudioStream
@export var boss_start_sound: AudioStream
@export var boss_phase_sound: AudioStream
@export var boss_defeated_sound: AudioStream

var _players: Array[AudioStreamPlayer] = []
var _bound_nodes: Dictionary = {}


func _ready() -> void:
	for index in max_simultaneous_sounds:
		var player := AudioStreamPlayer.new()
		player.name = "SFXVoice%d" % index
		add_child(player)
		_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_scene")


func play(stream: AudioStream, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream: return
	var player := _get_voice()
	if not player: return
	player.stream = stream
	player.volume_db = master_volume_db + volume_offset_db
	player.pitch_scale = maxf(pitch_scale + randf_range(-pitch_variation, pitch_variation), 0.1)
	player.play()


func _get_voice() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing: return player
	return _players[0] if not _players.is_empty() else null


func _scan_scene() -> void:
	if not get_tree().current_scene: return
	_bind_node(get_tree().current_scene)
	for node in get_tree().current_scene.find_children("*", "Node", true, false):
		_bind_node(node)


func _on_node_added(node: Node) -> void:
	call_deferred("_bind_node", node)


func _bind_node(node: Node) -> void:
	if not is_instance_valid(node) or _bound_nodes.has(node): return
	_bound_nodes[node] = true
	node.tree_exited.connect(_on_bound_node_exited.bind(node), CONNECT_ONE_SHOT)
	if node is CharacterController and node.controlling and node.controlling.is_in_group(&"player"):
		var controller := node as CharacterController
		controller.movement_action.connect(_on_player_movement)
		controller.landed.connect(_on_player_landed)
	elif node is PlayerCombatController:
		(node as PlayerCombatController).dagger_used.connect(_on_dagger_used)
		(node as PlayerCombatController).caster_fired.connect(_on_caster_fired)
	elif node is HealthComponent:
		var health := node as HealthComponent
		health.damaged.connect(_on_health_damaged.bind(health))
		health.died.connect(_on_health_died.bind(health))
	elif node is EnemyCombatController:
		var combat := node as EnemyCombatController
		combat.attack_started.connect(_on_enemy_attack_started)
	elif node is LocalDoor:
		(node as LocalDoor).used.connect(_on_door_used)
	elif node is BossArea:
		var area := node as BossArea
		area.encounter_started.connect(_on_boss_started)
		area.encounter_completed.connect(_on_boss_completed)
	elif node is BossPhaseController:
		(node as BossPhaseController).phase_changed.connect(_on_boss_phase_changed)


func _on_bound_node_exited(node: Node) -> void:
	_bound_nodes.erase(node)


func _on_player_movement(action: StringName, _pitch_degree: StringName) -> void:
	match action:
		&"ground_jump", &"double_jump", &"wall_jump", &"propulsor_step": play(jump_sound, -5.0)
		&"ground_dash", &"air_dash": play(dash_sound, -4.0)
		&"slide": play(slide_sound, -5.0)


func _on_player_landed() -> void:
	play(land_sound, -9.0)


func _on_dagger_used(_attack_type: StringName) -> void:
	play(dagger_sound, -5.0)


func _on_caster_fired(_direction: Vector2, _damage: int) -> void:
	play(caster_sound, -5.0)


func _on_health_damaged(_hit: HitData, health: HealthComponent) -> void:
	var owner := _find_character_owner(health)
	play(player_damage_sound if owner and owner.is_in_group(&"player") else enemy_damage_sound, -5.0 if owner and owner.is_in_group(&"player") else -10.0, 1.1)


func _on_health_died(_hit: HitData, health: HealthComponent) -> void:
	var owner := _find_character_owner(health)
	if owner and owner.is_in_group(&"enemies"): play(enemy_death_sound, -5.0)


func _on_enemy_attack_started() -> void:
	play(enemy_attack_sound, -6.0)


func _on_door_used(_actor: Node2D, _destination: LocalDoor) -> void:
	play(door_sound, -7.0, 1.15)


func _on_boss_started() -> void:
	play(boss_start_sound, -3.0)


func _on_boss_phase_changed(phase: int) -> void:
	if phase == 2: play(boss_phase_sound, -3.0)


func _on_boss_completed() -> void:
	play(boss_defeated_sound, -3.0)


func _find_character_owner(node: Node) -> Node:
	var current := node.get_parent()
	while current:
		if current.is_in_group(&"player") or current.is_in_group(&"enemies"): return current
		current = current.get_parent()
	return null
