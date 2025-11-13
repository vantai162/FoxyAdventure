extends Player_State
var runwaittimer=0.1
var waited=0
func _enter() -> void:
	runwaittimer=0.1
	waited=0
	#Change animation to run
	obj.change_animation("run")
	pass

func _update(_delta: float):
	if(obj.Effect["Stun"]<=0): 
		if control_jump():
			return
		control_throw()
		control_attack()
		if not control_moving():
			waited+=_delta
			if(waited>runwaittimer):
				change_state(fsm.states.idle)
		else:
			if control_dash():
				return
			if(runwaittimer>waited&&obj.direction>0&&Input.is_action_just_pressed("right")):
				obj.current_speed=obj.runspeed
			elif (runwaittimer>waited&&obj.direction<0&&Input.is_action_just_pressed("left")):
				obj.current_speed=obj.runspeed
	else:
		change_state(fsm.states.idle)
		obj.velocity.x=0
	#If not on floor change to fall
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
	pass
