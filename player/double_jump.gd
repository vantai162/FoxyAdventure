extends Player_State

func _enter() -> void:
	obj.change_animation("jump")
	pass

func _update(delta:float):
	control_moving()
	#if obj.is_on_wall_only():
		#fsm.change_state(fsm.states.wallcling,fsm.states.jump)
	#If velocity.y is greater than 0 change to fall
	if (obj.velocity.y>0):
		fsm.change_state(fsm.states.fall)
	pass
