extends EnemyState
## Elite Spiny Turtle Hurt State
## Base turtle uses: change_state(fsm.states.hide)
## Elite spiny turtle must use: change_state(fsm.states.defensivehide)

func _enter() -> void:
	timer = 0.3

func _update(delta: float) -> void:
	if update_timer(delta):
		if obj.health <= 0:
			if fsm.states.has("dead"):
				change_state(fsm.states.dead)
			else:
				obj.queue_free()
		else:
			# Base turtle: change_state(fsm.states.hide)
			# Elite spiny turtle: change_state(fsm.states.defensivehide)
			if fsm.states.has("defensivehide"):
				change_state(fsm.states.defensivehide)
			elif fsm.states.has("hide"):
				change_state(fsm.states.hide)  # Fallback
