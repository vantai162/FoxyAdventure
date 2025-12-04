extends EnemyState


func _enter() -> void:
	obj.change_animation("run")
	

func _update(delta):
	# If touching another enemy, stop and wait instead of stacking
	if obj.is_touching_enemy():
		obj.velocity.x = 0
		return
	
	obj.velocity.x = obj.direction * obj.movement_speed 
	if _should_turn_around():
		obj.turn_around()
		
	

func _should_turn_around() -> bool:
	if obj.is_touch_wall():
		# Only turn for walls/ground, not other enemies
		if not obj.is_touching_enemy():
			return true
	if obj.is_on_floor() and obj.is_can_fall():
		return true
	return false
