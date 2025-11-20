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
		final_speed *= 0.5
	if obj.current_speed == 0:
		obj.current_speed = final_speed
	if is_moving:
		dir = sign(dir)
		obj.change_direction(dir)
		var target_velocity_x = obj.current_speed * dir
		if obj.wind_velocity != Vector2.ZERO:
			target_velocity_x += obj.wind_velocity.x
		if not obj._is_on_ice():
			if obj.is_on_floor():
				obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.ground_friction)
			else:
				obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.air_control)
		else:
			obj.velocity.x = lerp(obj.velocity.x, target_velocity_x, obj.accelecrationValue)
		if obj.is_on_floor():
			change_state(fsm.states.run)
			return true
	elif not is_moving and obj._is_on_ice():
		var stop_target = 0.0
		if obj.wind_velocity != Vector2.ZERO:
			stop_target = obj.wind_velocity.x
		obj.velocity.x = lerp(obj.velocity.x, stop_target, obj.slideValue)
		if abs(obj.velocity.x) < obj.fullStopValue and obj.wind_velocity == Vector2.ZERO:
			obj.velocity.x = 0
	elif obj.wind_velocity != Vector2.ZERO:
		obj.velocity.x = lerp(obj.velocity.x, obj.wind_velocity.x, 0.1)
	elif obj.is_on_floor():
		obj.velocity.x = lerp(obj.velocity.x, 0.0, obj.ground_friction)
		if abs(obj.velocity.x) < obj.min_stop_speed:
			obj.velocity.x = 0
		obj.current_speed = 0
	else:
		obj.velocity.x = lerp(obj.velocity.x, 0.0, obj.air_control * obj.air_drag_multiplier)
	return false
func control_jump() -> bool:
	if(GameManager.paused):
		return false
	if (Input.is_action_just_pressed("jump") and obj.jump_count < 2) or (obj._checkbuffer() and obj.is_on_floor()):
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
		change_state(fsm.states.dead)
	else:
		pass
