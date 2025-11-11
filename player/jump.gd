extends Player_State

func _enter() -> void:
	#Change animation to jump
	obj.change_animation("jump")
	pass

func _update(_delta: float):
	if(obj.Effect["Stun"]<=0):
		control_moving()
		control_attack()
		control_jump()
		control_dash()
	else:
		obj.velocity.x=0
	#If velocity.y is greater than 0 change to fall
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)
	pass
