extends EnemyState

var throw_count: int = 0

func _enter() -> void:
	obj.change_animation("attack")
	throw_count = 0
	obj.velocity.x = 0
	_throw_next_coconut()

func _update(_delta: float) -> void:
	obj.velocity.x = 0
	
	# Face player while attacking
	if obj.found_player:
		if obj.found_player.global_position.x > obj.global_position.x:
			obj.change_direction(1)
		else:
			obj.change_direction(-1)

func _exit() -> void:
	obj.throw_timer.stop()

func _on_throw_timer_timeout() -> void:
	if fsm.current_state == self:
		_throw_next_coconut()

func _throw_next_coconut() -> void:
	throw_count += 1
	
	var coconut_scene = obj.special_coconut_scene if throw_count == 3 else obj.normal_coconut_scene
	if not coconut_scene:
		return
	
	# Use exports instead of hardcoded values
	var launch_velocity_y = -obj.throw_arc
	var launch_velocity_x: float
	
	if obj.found_player:
		var dx = obj.found_player.global_position.x - obj.global_position.x
		var dist = abs(dx)
		var factor = clamp(dist / obj.distance_scale_factor, obj.min_throw_multiplier, obj.max_throw_multiplier)
		launch_velocity_x = obj.throw_force * factor * obj.direction
	else:
		launch_velocity_x = obj.throw_force * obj.direction
	
	obj.throw_coconut(coconut_scene, obj.throw_origin.global_position, Vector2(launch_velocity_x, launch_velocity_y))
	
	if throw_count >= 3:
		# Attack complete, return to run
		if obj.found_player:
			obj.attack_timer.start()
		change_state(fsm.states.run)
	else:
		obj.throw_timer.start()
