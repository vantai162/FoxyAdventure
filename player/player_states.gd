class_name Player_State
extends FSMState

func control_moving() -> bool:
	if(GameManager.paused):
		return false
	var dir: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var is_moving: bool = abs(dir) > 0.1
	
	if obj.current_speed == 0:
		obj.current_speed = obj.movement_speed
	if obj.Effect["Slow"] > 0:
		obj.current_speed *= 0.5
	
	if is_moving and not obj._is_on_ice():
		dir = sign(dir)
		obj.change_direction(dir)
		obj.velocity.x = obj.current_speed * dir
		if obj.is_on_floor():
			change_state(fsm.states.run)
		return true
	elif is_moving and obj._is_on_ice():
		dir = sign(dir)
		obj.change_direction(dir)
		obj.velocity.x = lerp(obj.velocity.x, dir * obj.current_speed, obj.accelecrationValue)
		if obj.is_on_floor():
			change_state(fsm.states.run)
		return true
	elif not is_moving and obj._is_on_ice():
		obj.velocity.x = lerp(obj.velocity.x, 0.0, obj.slideValue)
		if obj.velocity.x < obj.fullStopValue and obj.velocity.x > -obj.fullStopValue:
			obj.velocity.x = 0
	else:
		obj.current_speed = 0
		obj.velocity.x = 0
	return false

func control_jump() -> bool:
	if(GameManager.paused):
		return false
	if (Input.is_action_just_pressed("jump") and obj.jump_count < 2) or (obj._checkbuffer() and obj.is_on_floor()):
		if obj.jump_count == 1:
			obj.jump(obj.jump_speed*0.8)
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

func take_damage(damage: int) -> void:
	obj.take_damage(damage)
	
	if obj.health <= 0:
		change_state(fsm.states.dead)
	else:
		pass
