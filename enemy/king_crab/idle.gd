extends EnemyState

## King Crab Idle - Simple timer-based attack selection (like Warlord Turtle)

func _enter() -> void:
	obj.change_animation("idle")
	obj.velocity = Vector2.ZERO
	timer = obj.idle_duration

func _update(delta: float) -> void:
	# Use built-in timer from FSMState
	if update_timer(delta):
		_choose_next_action()

func _choose_next_action() -> void:
	# Phase 1: Dive or throw coconuts
	# Phase 2: Add claw attack and roll bounce
	
	if obj.current_phase == 1:
		# Randomly pick dive or coconut throw
		if randf() < 0.5:
			change_state(fsm.states.diveattack)
		else:
			var tree = obj.find_nearest_tree()
			if tree:
				change_state(fsm.states.walktotree)
			else:
				change_state(fsm.states.diveattack)
	else:
		# Phase 2: All attacks available
		var actions = [fsm.states.diveattack]
		
		# Add coconut throw if trees exist
		if obj.find_nearest_tree():
			actions.append(fsm.states.walktotree)
		
		# Phase 2 exclusive attacks
		actions.append(fsm.states.clawattack)
		actions.append(fsm.states.rollbounce)
		
		var chosen = actions[randi() % actions.size()]
		change_state(chosen)
