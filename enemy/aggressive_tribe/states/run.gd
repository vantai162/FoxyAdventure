extends EnemyState

func _enter() -> void:
	obj.change_animation("run")

func _update(_delta: float) -> void:
	if obj.is_winding_up:
		obj.velocity.x = 0
		obj.change_animation("idle")
		return
	
	if obj.is_attacking:
		obj.velocity.x = 0
		obj.change_animation("idle")
		return
	
	obj.change_animation("run")
	obj.velocity.x = obj.direction * obj.movement_speed
	
	if obj.is_touch_wall() or (obj.is_on_floor() and obj.is_can_fall()):
		obj.turn_around()
