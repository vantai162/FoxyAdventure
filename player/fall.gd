extends Player_State

func _enter() -> void:
	#Change animation to fall
	obj.change_animation("fall")
	pass

func _update(_delta: float) -> void:
	var is_moving=false
	if(obj._checkcoyotea()):
		control_jump()
	#Control moving
	if(obj.Effect["Stun"]<=0):
		is_moving = control_moving()
	else:
		obj.velocity.x=0
	#If on floor change to idle if not moving and not jumping
	if obj.is_on_floor() and not is_moving:
		change_state(fsm.states.idle)
	pass
