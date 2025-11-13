extends Player_State

func _enter() -> void:
	obj.change_animation("jump")

func _update(_delta: float):
	if(obj.Effect["Stun"]<=0):
		if !fsm.previous_state==fsm.states.wallcling:
			control_moving()
		control_throw()
		control_attack()
		control_jump()
		control_dash()
	else:
		obj.velocity.x=0
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)
	if obj.is_on_wall_only():
		fsm.change_state(fsm.states.wallcling)
