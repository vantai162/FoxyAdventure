extends EnemyState

## Boss Hurt State (Warlord Turtle)
## NOTE: With stun_immune = true, bosses should NOT enter this state via normal hits
## This state is kept for:
## - Special scripted moments
## - Fallback if stun_immune is disabled
## - The "vulnerable at 1 HP" mechanic transition

func _enter():
	obj.change_animation("hurt")
	timer = 0.2
	
	# Vulnerable state at 1 HP (finisher mechanic)
	if obj.health <= 1:
		change_state(fsm.states.vulnerable)
		return

func _update(delta: float):
	if update_timer(delta):
		if obj.health <= 0:
			change_state(fsm.states.dead)
		else:
			change_state(fsm.default_state)
