extends EnemyState
## Elite Spawner Mushroom Hurt State
## Brief pause, then return to pursuit (or die)

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
			# Return to pursuit
			if fsm.states.has("spawnerpursue"):
				change_state(fsm.states.spawnerpursue)
			elif fsm.states.has("run"):
				change_state(fsm.states.run)
