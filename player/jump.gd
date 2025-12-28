extends Player_State

func _enter() -> void:
	print("JUMP")
	obj.change_animation("jump")
	print(obj.current_animation)
	super._enter()
	AudioManager.play_sound("player_jump",20.0)
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
	# Wall cling: only if not on ice wall AND player is actively pressing toward wall
	# This implements "active" wall cling - no input = just fall past the wall
	if obj.is_on_wall_only() and not obj._is_wall_ice():
		if not obj.wall_cling_requires_input or obj.is_pressing_toward_wall():
			change_state(fsm.states.wallcling)
