extends Player_State

func _enter() -> void:
	#Change animation to run
	obj.change_animation("run")
	pass

func _update(_delta: float):
	if(obj.Effect["Stun"]<=0): 
		if control_jump():
			return
		control_attack()
		if not control_moving():
			change_state(fsm.states.idle)
	else:
		change_state(fsm.states.idle)
		obj.velocity.x=0
	#If not on floor change to fall
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
	pass
