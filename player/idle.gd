extends Player_State

func _enter() -> void:
	obj.change_animation("idle")

func _update(delta: float) -> void:
	if(obj.Effect["Stun"]<=0):
		control_moving()
		control_jump()
	if not obj.is_on_floor():
		change_state(fsm.states.fall)
