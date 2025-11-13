extends EnemyState

var can_jump: bool = true
var last_player_velocity_y: float = 0.0

func _enter() -> void:
	obj.face_player()
	obj.change_animation("defend")
	obj.show_shield()
	
	# Only set wait_time if not already configured in editor
	if obj.attack_timer.wait_time == 0:
		obj.attack_timer.wait_time = obj.attack_interval
	obj.attack_timer.start()
	
	can_jump = true
	last_player_velocity_y = 0.0

func _update(_delta: float) -> void:
	obj.face_player()
	
	if obj.found_player and can_jump:
		var dist = abs(obj.found_player.global_position.x - obj.global_position.x)
		var current_vel_y = obj.found_player.velocity.y
		
		if dist < obj.jump_react_range and last_player_velocity_y >= 0 and current_vel_y < obj.jump_react_velocity_threshold:
			_perform_block_jump()
		
		last_player_velocity_y = current_vel_y

func _perform_block_jump():
	can_jump = false
	obj.jump(obj.jump_speed)
	get_tree().create_timer(obj.jump_cooldown).timeout.connect(func(): can_jump = true)

func _exit() -> void:
	obj.attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	# Only attack if player is still in sight/range. Otherwise stop and idle.
	if obj.found_player:
		var dist = abs(obj.found_player.global_position.x - obj.global_position.x)
		if dist <= obj.sight_range:
			change_state(fsm.states.attack)
		else:
			obj.attack_timer.stop()
			change_state(fsm.states.idle)
	else:
		obj.attack_timer.stop()
		change_state(fsm.states.idle)
