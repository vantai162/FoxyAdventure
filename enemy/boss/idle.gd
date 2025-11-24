extends EnemyState

func _enter():
	obj.change_animation("idle")
	timer = 2.0
	obj.enable_hurt_for(2.0)


func _update(delta):
	if update_timer(delta):
		change_state(fsm.states.skill1)
