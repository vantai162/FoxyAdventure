extends Player_State

func _enter() -> void:
	obj.change_animation("jump")
	obj.jump_count=0
	obj.dashed_on_air=false
	pass

func _update(_delta: float):
	if Input.is_action_just_pressed("jump"):
		print("initforce")
		obj.velocity.x=-obj.direction*100
		obj.velocity.y=-obj.jump_speed
		obj.change_direction(-obj.direction)
		fsm.change_state(fsm.states.jump)
		return
	control_moving()
	if not obj.is_on_wall():
		if not obj.is_on_floor():
			change_state(fsm.states.fall)
		else:
			change_state(fsm.states.idle)
	elif obj.velocity.y > 0:
		obj.velocity.y = obj.gravity * 0.3 * _delta
	pass
