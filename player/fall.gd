extends Player_State

func _enter() -> void:
	obj.change_animation("fall")

func _update(_delta: float) -> void:
	var is_moving=false
	var jumped=false
	if(obj._checkcoyotea()):
		control_jump()
	#Control moving
	if(obj.Effect["Stun"]<=0):
		is_moving = control_moving()
		control_throw()
		control_attack()
		control_jump()
		control_dash()
	# Note: When stunned, control_moving() is not called, so velocity persists
	# This allows stunned player to slide on ice naturally
	#If on floor change to idle if not moving and not jumping
	if obj.is_on_floor() and not is_moving:
		change_state(fsm.states.idle)
	if obj.is_on_floor():
		obj.jump_count=0
		obj.dashed_on_air=false
	# Wall cling: only if not on ice wall AND player is actively pressing toward wall
	# This implements "active" wall cling - no input = just fall past the wall
	if obj.is_on_wall_only() and not obj._is_wall_ice():
		if not obj.wall_cling_requires_input or obj.is_pressing_toward_wall():
			fsm.change_state(fsm.states.wallcling)
	if obj.is_in_water and obj.is_head_underwater():
		fsm.change_state(fsm.states.swim)
