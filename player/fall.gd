extends Player_State

func _enter() -> void:
	obj.change_animation("fall")

func _update(_delta: float) -> void:
	if obj._checkcoyotea():
		control_jump()
	
	if obj.Effect["Stun"] <= 0:
		var is_moving = control_moving()
		control_throw()
		control_attack()
		control_jump()
		control_dash()
	else:
		obj.velocity.x = 0
	
	if obj.is_on_floor():
		obj.jump_count = 0
		obj.dashed_on_air = false
		if not control_moving():
			change_state(fsm.states.idle)
