extends EnemyState

var throw_count: int = 0

func _enter() -> void:
	obj.change_animation("attack")
	throw_count = 0
	obj.velocity.x = 0
	_throw_next_coconut()

func _update(_delta: float) -> void:
	obj.velocity.x = 0
	
	# Continue facing stored direction (committed attack)
	# Don't change direction mid-burst

func _exit() -> void:
	obj.throw_timer.stop()
	# Clear commitment flag when attack ends
	obj.is_committed_to_attack = false

func _on_throw_timer_timeout() -> void:
	if fsm.current_state == self:
		_throw_next_coconut()

func _throw_next_coconut() -> void:
	throw_count += 1
	
	# Coconut pattern: normal, SLOW, normal (unpredictable middle threat)
	var coconut_scene = obj.special_coconut_scene if throw_count == 2 else obj.normal_coconut_scene
	if not coconut_scene:
		return
	
	# Calculate ballistic trajectory with physics
	var launch_velocity = _calculate_ballistic_throw()
	obj.throw_coconut(coconut_scene, obj.throw_origin.global_position, launch_velocity)
	AudioManager.play_sound("warlord_bomb_launch",18.0)
	# Burst completion logic
	if throw_count >= 3:
		# Attack complete, return to run
		if obj.found_player:
			obj.attack_timer.start()
		change_state(fsm.states.run)
	else:
		obj.throw_timer.start()

func _calculate_ballistic_throw() -> Vector2:
	## Proper ballistic physics: quadratic formula for launch angle
	## Includes player velocity prediction and height compensation
	
	# Use found_player if available, else use last known position (commitment)
	var target_pos: Vector2
	var target_velocity: Vector2 = Vector2.ZERO
	
	if obj.found_player:
		target_pos = obj.found_player.global_position
		target_velocity = obj.found_player.velocity
	else:
		# Player escaped - use last known position (attack commitment)
		target_pos = obj.last_known_player_pos
		# No velocity prediction for escaped target
	
	# Apply velocity leading if player still detected (50% prediction)
	var flight_time = 0.5  # Rough estimate for leading calculation
	if obj.found_player:
		target_pos.x += target_velocity.x * flight_time * 0.5
	
	var dx = target_pos.x - obj.throw_origin.global_position.x
	var dy = target_pos.y - obj.throw_origin.global_position.y
	var horizontal_distance = abs(dx)
	
	# Physics constants
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	var v0 = obj.throw_force
	
	# Ballistic quadratic formula: solve for launch angle
	# Discriminant: v0^4 - g(g*dx^2 + 2*dy*v0^2)
	var discriminant = v0*v0*v0*v0 - gravity * (gravity * horizontal_distance * horizontal_distance + 2.0 * dy * v0 * v0)
	
	if discriminant < 0:
		# No valid angle (target unreachable) - use high arc fallback
		return Vector2(v0 * sign(dx) * 0.7, -v0 * 0.8)
	
	# Two solutions: low arc (faster) and high arc (slower)
	# We want low arc for aggression: angle = atan((v0^2 - sqrt(discriminant)) / (g * dx))
	var angle = atan((v0 * v0 - sqrt(discriminant)) / (gravity * horizontal_distance))
	
	# Convert angle to velocity components
	var vx = v0 * cos(angle) * sign(dx)
	var vy = -v0 * sin(angle)  # Negative because up is negative Y
	
	return Vector2(vx, vy)
