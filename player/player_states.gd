class_name Player_State
extends FSMState

func control_moving() -> bool:
	if(GameManager.paused):
		return false
	var dir: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var is_moving: bool = abs(dir) > 0.1
	if obj.is_on_floor() and Input.is_action_pressed("down") and obj._is_on_one_way_platform():
		obj.drop_down_platform()
	var final_speed = obj.movement_speed
	if obj.Effect["Slow"] > 0:
		final_speed *= obj.slow_effect_multiplier
	# Initialize current_speed if it's been reset (0 means player stopped)
	if obj.current_speed == 0:
		obj.current_speed = final_speed
	
	# MOVING input detected
	if is_moving:
		dir = sign(dir)
		obj.change_direction(dir)
		var target_velocity_x = obj.current_speed * dir
		if obj.wind_velocity != Vector2.ZERO:
			target_velocity_x += obj.wind_velocity.x
		
		# Ground movement (ice vs normal)
		if obj.is_on_floor():
			if obj._is_on_ice():
				# Ice: slower acceleration (slippery feel)
				obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.accelecrationValue)
			else:
				# Normal ground: responsive friction
				obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.ground_friction)
			change_state(fsm.states.run)
			return true
		else:
			# Air movement: player has input, steering against momentum
			obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.get_current_air_acceleration())
	
	# NOT MOVING - deceleration paths
	elif not is_moving:
		if obj.is_on_floor() and obj._is_on_ice():
			# Ice sliding: slow deceleration with optional wind
			var stop_target = 0.0
			if obj.wind_velocity != Vector2.ZERO:
				stop_target = obj.wind_velocity.x
			obj.velocity.x = lerp(obj.velocity.x, stop_target, obj.slideValue)
			if abs(obj.velocity.x) < obj.fullStopValue and obj.wind_velocity == Vector2.ZERO:
				obj.velocity.x = 0
				obj.current_speed = 0  # Reset speed when fully stopped
		elif obj.wind_velocity != Vector2.ZERO:
			# Wind influence (any surface)
			obj.velocity.x = lerp(obj.velocity.x, obj.wind_velocity.x, obj.wind_influence_factor)
		elif obj.is_on_floor():
			# Normal ground stop
			obj.velocity.x = lerp(obj.velocity.x, 0.0, obj.ground_friction)
			if abs(obj.velocity.x) < obj.min_stop_speed:
				obj.velocity.x = 0
			obj.current_speed = 0
		else:
			# Air drag: no input, natural momentum coast
			obj.velocity.x = lerp(obj.velocity.x, 0.0, obj.air_deceleration)
	
	return false
func control_jump() -> bool:
	if(GameManager.paused):
		return false
	if (Input.is_action_just_pressed("jump") and obj.jump_count < 2) or (obj._checkbuffer() and obj.is_on_floor()):
		if state_sound:
			obj.play_sfx(state_sound)
		if obj.jump_count == 1:
			obj.jump(obj.jump_speed * obj.double_jump_power_multiplier)
		else:
			obj.jump(obj.jump_speed)
		obj.jump_count += 1
		change_state(fsm.states.jump)
		return true
	return false

func control_attack() -> bool:
	if(GameManager.paused):
		return false
	if Input.is_action_just_pressed("attack") and obj.can_attack():
		change_state(fsm.states.attack)
		return true
	return false

func control_throw() -> bool:
	if(GameManager.paused):
		return false
	if Input.is_action_just_pressed("throw_blade") and obj.can_throw_blade():
		change_state(fsm.states.throw)
		return true
	return false

func control_dash() -> bool:
	if(GameManager.paused):
		return false
	if obj.CoolDown["Dash"] > 0:
		return false
	if Input.is_action_just_pressed("dash"):
		if obj.is_on_floor():
			change_state(fsm.states.dash)
			return true
		elif not obj.dashed_on_air:
			change_state(fsm.states.dash)
			return true
		else:
			return false
	return false


func control_swimming() -> bool:
	if GameManager.paused:
		return false

	# Thoát khỏi nước
	if not obj.is_in_water:
		change_state(fsm.states.idle)
		return true

	var input_vec = Vector2.ZERO
	input_vec.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_vec.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	# Không bơi = đứng/treo trong nước
	if input_vec == Vector2.ZERO:
		obj.velocity = obj.velocity.lerp(Vector2.ZERO, obj.swim_deceleration)
		return false

	input_vec = input_vec.normalized()

	obj.change_direction(sign(input_vec.x) if input_vec.x != 0 else obj.direction)

	obj.velocity = obj.velocity.lerp(
		 input_vec * obj.swim_speed,
		obj.swim_acceleration
	)
	return true


func take_damage(damage: int) -> void:
	obj.take_damage(damage)
	
	if obj.health <= 0:
		obj.emit_signal("died")
		change_state(fsm.states.dead)
	else:
		change_state(fsm.states.hurt)
