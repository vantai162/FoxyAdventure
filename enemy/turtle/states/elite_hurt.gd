extends EnemyState
## Elite Spiny Turtle Hurt State
## Counterattack: Spike burst if cooldown ready, otherwise HIDE (defensive instinct)
## Elite is still a turtle - hiding is intrinsic, not tied to attack cooldown

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
			# ATTACK-HIDE: If cooldown ready, counter with spike burst + hide
			if obj.can_burst() and fsm.states.has("offensivehide"):
				change_state(fsm.states.offensivehide)
			# DEFENSIVE-HIDE: If cooldown active, still hide (no spikes, pure defense)
			elif fsm.states.has("hide"):
				change_state(fsm.states.hide)
			else:
				# Fallback: return to default state if no hide available
				change_state(fsm.default_state)
