extends EnemyState
## Elite Spawner Mushroom Hurt State
## Base mushroom uses: change_state(fsm.states.explode)
## Elite spawner must use: change_state(fsm.states.run)

func _enter():
	obj.change_animation("hurt")
	timer = 0.2

func _update(delta: float):
	if update_timer(delta):
		if obj.health <= 0:
			if fsm.states.has("dead"):
				change_state(fsm.states.dead)
			else:
				obj.queue_free()
		else:
			# Base mushroom: change_state(fsm.states.explode)
			# Elite spawner: return to run or spawner_pursue
			if fsm.states.has("run"):
				change_state(fsm.states.run)
