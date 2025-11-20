extends Player_State

func _enter() -> void:
	obj.change_animation("jump")
	obj.jump_count = 0
	obj.dashed_on_air = false

func _update(_delta: float):
	if Input.is_action_just_pressed("jump"):
		obj.velocity.x = -obj.direction * obj.wall_jump_force
		obj.velocity.y = -obj.jump_speed
		obj.change_direction(-obj.direction)
		obj.jump_count = 1
		change_state(fsm.states.jump)
		return
	
	control_moving()
	
	if not obj.is_on_wall():
		if not obj.is_on_floor():
			change_state(fsm.states.fall)
		else:
			change_state(fsm.states.idle)
	elif obj.velocity.y > 0:
		obj.velocity.y = obj.gravity * obj.wall_slide_friction * _delta
