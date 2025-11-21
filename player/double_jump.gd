extends Player_State

func _enter() -> void:
	# Double jump doesn't restrict air control - uses base air_control_base
	obj.wall_jump_restriction_timer = -1.0  # Ensure no restriction active
	obj.change_animation("jump")

func _update(delta: float):
	control_moving()
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)
