extends Area2D
class_name HealthPickup2D

@export var healing: int = 4
@export var bob_height: float = 5.0
@export var bob_speed: float = 3.0

var _origin_y := 0.0
var _time := 0.0


func _ready() -> void:
	_origin_y = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	position.y = _origin_y + sin(_time * bob_speed) * bob_height
	rotation = sin(_time * 1.7) * 0.12


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"): return
	var health := body.find_child("HealthComponent", true, false) as HealthComponent
	if not health or health.heal(healing) <= 0: return
	monitoring = false
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	await tween.finished
	queue_free()
