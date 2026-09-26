extends Marker2D
class_name DirectionalPivot





func update_input(dir: Vector2) -> void:
	if dir: rotation = dir.angle() + deg_to_rad(90)
