extends Resource
class_name CutsceneCameraTransition

@export_range(0.0, 30.0, 0.05, "or_greater") var duration: float = 1.0
@export var transition: Tween.TransitionType = Tween.TRANS_QUAD
@export var ease: Tween.EaseType = Tween.EASE_IN_OUT

