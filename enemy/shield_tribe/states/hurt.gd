extends EnemyState

func _enter() -> void:
	obj.change_animation("hurt")
	timer = 0.3

func _update(delta: float) -> void:
	if update_timer(delta):
		if obj.health <= 0:
			if fsm.states.has("dead"):
				change_state(fsm.states.dead)
			else:
				obj.queue_free()
		else:
			change_state(fsm.states.idle)
