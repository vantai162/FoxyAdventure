extends Player_State

var waited: float = 0.0

func _enter() -> void:
	waited = 0.0
	obj.change_animation("run")

func _update(_delta: float):
	obj.current_oxygen = min(obj.max_oxygen, obj.current_oxygen + obj.oxygen_increase_rate * _delta)
	if obj.Effect["Stun"] <= 0:
		if control_jump():
			return
		control_throw()
		control_attack()
		if not control_moving():
			waited += _delta
			if waited > obj.run_idle_wait_time:
				change_state(fsm.states.idle)
		else:
			if control_dash():
				return
			if obj.run_idle_wait_time > waited and obj.direction > 0 and Input.is_action_just_pressed("right"):
				obj.current_speed = obj.runspeed
			elif obj.run_idle_wait_time > waited and obj.direction < 0 and Input.is_action_just_pressed("left"):
				obj.current_speed = obj.runspeed
	else:
		# Stunned - transition to idle but let control_moving() handle velocity
		change_state(fsm.states.idle)
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
	if obj.is_on_wall_only():
		change_state(fsm.states.wallcling)
	if obj.is_in_water:
		change_state(fsm.states.swim)
