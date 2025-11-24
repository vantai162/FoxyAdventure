extends EnemyState


func _enter() -> void:
	print("run")
	obj.change_animation("run")


func _update(_delta):
	super._update(_delta)
	
	# Ice physics for enemy movement
	if obj.is_on_floor() and obj._is_on_ice():
		# On ice: gradual acceleration/deceleration
		var target_velocity = obj.direction * obj.movement_speed
		obj.velocity.x = lerp(obj.velocity.x, target_velocity, obj.accelecrationValue)
	else:
		# Normal surface: instant velocity
		obj.velocity.x = obj.direction * obj.movement_speed
	
	if _should_turn_around():
		obj.turn_around()

	if obj.found_player:
		if obj.found_player.global_position.x > obj.global_position.x:
			obj.turn_right()
		else:
			obj.turn_left()
		change_state(fsm.states.attack)


func _should_turn_around() -> bool:
	if obj.is_touch_wall():
		return true
	
	return false
