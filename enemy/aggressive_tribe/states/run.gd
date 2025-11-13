extends EnemyState

func _enter() -> void:
	obj.change_animation("run")

func _update(_delta: float) -> void:
	obj.change_animation("run")
	obj.velocity.x = obj.direction * obj.movement_speed
	
	if obj.is_touch_wall() or (obj.is_on_floor() and obj.is_can_fall()):
		obj.turn_around()
