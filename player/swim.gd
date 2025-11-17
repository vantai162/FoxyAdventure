extends Player_State

func _enter():
	obj.change_animation("run")
	obj.gravity = 300       

func _update(delta: float):
	control_swimming()
	obj.current_oxygen -= obj.oxygen_decrease_rate * delta
	if obj.current_oxygen <= 0:
			obj.current_oxygen = 0
			fsm.current_state.take_damage(1)
	if not obj.is_in_water:
		fsm.change_state(fsm.states.fall)
	
