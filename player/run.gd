extends Player_State
var runwaittimer=0.1
var waited=0
func _enter() -> void:
	runwaittimer=0.1
	waited=0
	obj.change_animation("run")

func _update(_delta: float):
	obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + 1.5 * _delta)
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
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
	if obj.is_on_wall_only():
		fsm.change_state(fsm.states.wallcling)
	if obj.is_in_water:
		fsm.change_state(fsm.states.swim)
