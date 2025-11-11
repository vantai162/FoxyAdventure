class_name Player_State
extends FSMState

func control_moving() -> bool:
	var dir: float = Input.get_action_strength("right") - Input.get_action_strength("left")
	var is_moving: bool = abs(dir) > 0.1
	if(obj.current_speed==0):
		obj.current_speed = obj.movement_speed
	if obj.Effect["Slow"] > 0:
		obj.current_speed *= 0.5 # 50% slow
	
	if is_moving:
		dir = sign(dir)
		obj.change_direction(dir)
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
	if Input.is_action_just_pressed("jump")||obj._checkbuffer():
		obj.jump()
		change_state(fsm.states.jump)
		return true
	return false
	
func control_double_jump()->bool:
	if Input.is_action_just_pressed("jump") and fsm.previous_state!=fsm.states.doublejump:
		obj.jump()
		change_state(fsm.states.doublejump)
		return true
	return false
	
func take_damage(damage) -> void:
	#Player take damage
	obj.take_damage(damage)
	
	#Player die if health is 0 and change to dead state
	if obj.health <= 0:
		change_state(fsm.states.death)
	#Player hurt if health is not 0 and change to hurt state
	else:
		# You can implement hurt state here if needed
		pass
