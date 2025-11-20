extends Player_State

func _enter() -> void:
	obj.air_control = 1.0
	obj.change_animation("jump")

func _update(delta: float):
	control_moving()
	if obj.velocity.y > 0:
		change_state(fsm.states.fall)
