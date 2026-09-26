extends CharacterBody2D
class_name CharacterEntity

signal cutscene_move_done

@onready var collision: CollisionShape2D = find_child("Collision", true, false) as CollisionShape2D

var navigator: CharacterNavigator2D


func _ready() -> void:
	add_to_group(&"characters")
	navigator = get_component(CharacterNavigator2D) as CharacterNavigator2D
	var controller := get_component(CharacterController) as CharacterController
	if navigator and controller:
		navigator.setup(self, controller)
		navigator.navigation_finished.connect(_on_cutscene_navigation_finished)
		navigator.navigation_failed.connect(_on_cutscene_navigation_failed)
		navigator.navigation_cancelled.connect(_on_cutscene_navigation_finished)


func get_component(component_script: Script) -> Node:
	for child in find_children("*", "Node", true, false):
		if child.get_script() == component_script:
			return child
	return null


func has_component(component_script: Script) -> bool:
	return get_component(component_script) != null


func cuts_move(target: Vector2, speed_multiplier: float = 1.0, final_facing: String = "") -> void:
	if not navigator:
		push_warning("%s cannot use cutscene movement without a CharacterNavigator2D component." % name)
		cutscene_move_done.emit()
		return
	navigator.navigate_to(target, speed_multiplier, final_facing)


func get_navigation_radius() -> float:
	if not collision or not collision.shape:
		return 6.0
	if collision.shape is CircleShape2D:
		return (collision.shape as CircleShape2D).radius
	if collision.shape is RectangleShape2D:
		var rectangle := collision.shape as RectangleShape2D
		return minf(rectangle.size.x, rectangle.size.y) * 0.5
	if collision.shape is CapsuleShape2D:
		return (collision.shape as CapsuleShape2D).radius
	return 6.0


func set_navigation_obstacle_enabled(enabled: bool) -> void:
	var obstacle := find_child("NavigationObstacle2D", true, false) as NavigationObstacle2D
	if obstacle:
		obstacle.avoidance_enabled = enabled


func _on_cutscene_navigation_finished() -> void:
	cutscene_move_done.emit()


func _on_cutscene_navigation_failed(reason: String) -> void:
	push_warning("Cutscene movement failed for %s: %s" % [name, reason])
	cutscene_move_done.emit()
