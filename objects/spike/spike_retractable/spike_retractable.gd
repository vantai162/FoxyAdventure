extends Node2D

@export var up_pos: Vector2
@export var down_pos: Vector2
@export var up_time: float
@export var down_time:float
@export var hold_time:float

func _ready() -> void:
	active()

func active():
	var tween = create_tween()
	tween.tween_property(self,"position",up_pos,up_time)
	tween.tween_interval(hold_time)
	tween.tween_property(self,"position",down_pos,down_time)
	tween.tween_interval(hold_time)
	tween.finished.connect(active)
