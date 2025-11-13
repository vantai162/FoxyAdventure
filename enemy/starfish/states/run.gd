extends EnemyState


func _enter() -> void:
	print("run")
	obj.change_animation("run")


func _update(_delta):
	super._update(_delta)
	#if is_moving and not obj._is_on_ice():
	#	dir = sign(dir)
	#	obj.change_direction(dir)
	#	if obj.Effect["Slow"] > 0:
	#		obj.velocity.x = obj.current_speed * dir*0.5
	#	else:
	#		obj.velocity.x = obj.current_speed * dir
	#	if obj.is_on_floor():
	#		change_state(fsm.states.run)
	#	return true
	#elif is_moving and obj._is_on_ice():
	#	dir = sign(dir)
	#	obj.change_direction(dir)
	#	obj.velocity.x = lerp(obj.velocity.x,dir * obj.movement_speed,obj.accelecrationValue)
	#	if obj.is_on_floor():
	#		change_state(fsm.states.run)
	#	return true
	#elif not is_moving and obj._is_on_ice():
	#	obj.velocity.x = lerp(obj.velocity.x,0.0,obj.slideValue)
	#	if obj.velocity.x < obj.fullStopValue and obj.velocity.x > - obj.fullStopValue:
	#		obj.velocity.x = 0
	#else:
	#	obj.current_speed=0
	#	obj.velocity.x = 0
	if not obj._is_on_ice():
		obj.velocity.x = obj.direction * obj.movement_speed
	elif obj._is_on_ice():
		obj.velocity.x = lerp(obj.velocity.x,obj.direction * obj.movement_speed,obj.accelecrationValue)
	elif obj.velocity.x == 0 and obj._is_on_ice():
		obj.velocity.x = lerp(obj.velocity.x,0.0,obj.slideValue)
		if obj.velocity.x < obj.fullStopValue and obj.velocity.x > - obj.fullStopValue:
			obj.velocity.x = 0
		
	
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
