
extends EnemyState


func _enter():

	obj.change_animation("hurt")

	timer = 0.2


func _update( delta: float):

	if update_timer(delta):

		if obj.health <= 0:
			if fsm.states.has("dead"):
				change_state(fsm.states.dead)
			else:
				obj.queue_free()
		else:
			change_state(fsm.states.explode)
