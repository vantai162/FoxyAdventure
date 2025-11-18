extends Node2D
@export var target_position: Vector2
@export var move_time: float
@export var rotate_time: float        
@export var rotate_angle: float          
var is_spike_active := false
var tween: Tween = null

func activate() -> void:
	if is_spike_active:
		return  
	is_spike_active = true
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "rotation_degrees", rotate_angle, rotate_time)
	tween.tween_interval(0.5)
	tween.tween_property(self, "position", target_position, move_time)

func _on_active_area_2d_body_entered(body: Node2D) -> void:
	activate()
