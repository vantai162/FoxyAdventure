class_name Player_State
extends FSMState

func control_moving() -> bool:
	var dir: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var is_moving: bool = abs(dir) > 0.1
	if(obj.current_speed==0):
		obj.current_speed = obj.movement_speed
	
	if is_moving:
		dir = sign(dir)
		obj.change_direction(dir)
		if obj.Effect["Slow"] > 0:
			obj.velocity.x = obj.current_speed * dir*0.5
		else:
			obj.velocity.x = obj.current_speed * dir
		if obj.is_on_floor():
			change_state(fsm.states.run)
		return true
	else:
		obj.current_speed=0
		obj.velocity.x = 0
	return false
	
func control_jump() -> bool:
	#If jump is pressed change to jump state and return true
	if (Input.is_action_just_pressed("jump")&&obj.jump_count<2)||(obj._checkbuffer()&&obj.is_on_floor()):
		if(obj.jump_count==1):
			obj.jump(obj.jump_speed)
		else:
			obj.jump(obj.jump_speed*0.8)
		obj.jump_count+=1
		change_state(fsm.states.jump)
		return true
	return false
func control_attack() -> bool:
	if Input.is_action_just_pressed("attack") && obj.can_attack():
		change_state(fsm.states.attack)
		return true
	return false

func control_throw() -> bool:
	if Input.is_action_just_pressed("throw_blade") && obj.can_throw_blade():
		change_state(fsm.states.throw)
		return true
	return false
	
func control_dash() ->bool:
	if(obj.CoolDown["Dash"]>0):
		return false
	if(Input.is_action_just_pressed("dash")):
		if obj.is_on_floor():
			change_state(fsm.states.dash)
			return true
		elif(!obj.dashed_on_air):
			change_state(fsm.states.dash)
			return true
		else:
			return false
	return false
	
func take_damage(damage) -> void:
	#Player take damage
	
	obj.take_damage(damage)
	
	#Player die if health is 0 and change to dead state
	if obj.health <= 0:
		change_state(fsm.states.dead)
	#Player hurt if health is not 0 and change to hurt state
	else:
		# You can implement hurt state here if needed
		pass
