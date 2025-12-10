extends StaticBody2D

@export var move_down_distance: float = 64
@export var move_time: float = 2.0

func close():
	var tween = create_tween()
	tween.tween_property(
		self,
		"global_position:y",
		global_position.y + move_down_distance,
		move_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
