extends Player_State
func _enter():
	obj.change_animation("hurt")
	obj.velocity.x = 400 * obj.direction
	obj.velocity.y =0
	timer = 0.3


func _update( delta: float):
	obj.velocity.x = 400 * obj.direction
	obj.velocity.y =0
	if update_timer(delta):
		obj.set_cool_down("Dash")
		change_state(fsm.previous_state)
