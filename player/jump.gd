extends Player_State

func _enter() -> void:
	obj.change_animation("jump")
	
	# If coming from wall cling, activate wall jump air restriction
	if fsm.previous_state == fsm.states.wallcling:
		obj.wall_jump_restriction_timer = 0.0
	else:
		obj.wall_jump_restriction_timer = -1.0  # Normal jump: no restriction

func _exit() -> void:
	# Timer naturally expires or gets reset by next jump
	pass

func _update(delta: float):
	# Update wall jump restriction timer if active
	if obj.wall_jump_restriction_timer >= 0:
		obj.wall_jump_restriction_timer += delta
	
	if obj.Effect["Stun"] <= 0:
		# Wall jump control delay: restrict control_moving during initial frames
		var can_control = obj.wall_jump_restriction_timer < 0 or \
						  obj.wall_jump_restriction_timer >= obj.wall_jump_control_delay
		
		if can_control:
			control_moving()
		
		control_throw()
		control_attack()
		control_jump()
		control_dash()
	# Note: When stunned, control_moving() is not called, so velocity persists
	# This allows stunned player to maintain jump arc naturally
	
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)
	if obj.is_on_wall_only():
		change_state(fsm.states.wallcling)
