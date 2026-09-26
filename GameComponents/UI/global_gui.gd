extends CanvasLayer
class_name GlobalGUIController

@onready var player_bar: ProgressBar = %PlayerHealthBar
@onready var player_text: Label = %PlayerHealthText
@onready var boss_panel: Control = %BossPanel
@onready var boss_bar: ProgressBar = %BossHealthBar
@onready var boss_name_label: Label = %BossName

var _player_health: HealthComponent
var _boss_health: HealthComponent


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	boss_panel.visible = false
	call_deferred("_find_player")


func _on_node_added(node: Node) -> void:
	if node.is_in_group(&"player"): call_deferred("_bind_player", node)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group(&"player")
	if not players.is_empty(): _bind_player(players[0])


func _bind_player(player: Node) -> void:
	var health := player.find_child("HealthComponent", true, false) as HealthComponent
	if not health or health == _player_health: return
	_player_health = health
	if not health.health_changed.is_connected(_update_player_health):
		health.health_changed.connect(_update_player_health)
	_update_player_health(health.current_health, health.max_health)


func show_boss(boss: Node, display_name: String = "BOSS") -> void:
	var health := boss.find_child("HealthComponent", true, false) as HealthComponent
	if not health: return
	_boss_health = health
	if not health.health_changed.is_connected(_update_boss_health):
		health.health_changed.connect(_update_boss_health)
	boss_name_label.text = display_name
	boss_panel.visible = true
	_update_boss_health(health.current_health, health.max_health)


func hide_boss() -> void:
	boss_panel.visible = false
	_boss_health = null


func _update_player_health(current: int, maximum: int) -> void:
	player_bar.max_value = maximum
	player_bar.value = current
	player_text.text = "%d / %d" % [current, maximum]


func _update_boss_health(current: int, maximum: int) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
